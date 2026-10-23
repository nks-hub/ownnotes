import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Downloaded attachments kept for previews and offline use.
///
/// Entries are keyed by account, server note id and relative path. Failures
/// are never stored, so a retry always asks the server again. When the total
/// size passes [maxTotalBytes] the least recently used files go first.
final class AttachmentCache {
  AttachmentCache(
    this.root, {
    this.maxFileBytes = 25 * 1024 * 1024,
    this.maxTotalBytes = 200 * 1024 * 1024,
  });

  final Directory root;
  final int maxFileBytes;
  final int maxTotalBytes;
  final _loads = <(String, int, String), _PendingLoad>{};
  final _random = Random.secure();
  Future<void>? _diskTail;

  Future<T> _onDisk<T>(Future<T> Function() work) async {
    final previous = _diskTail;
    final done = Completer<void>();
    _diskTail = done.future;
    try {
      if (previous != null) await previous;
      return await work();
    } finally {
      if (identical(_diskTail, done.future)) _diskTail = null;
      done.complete();
    }
  }

  void _invalidate((String, int, String) key) {
    final pending = _loads.remove(key);
    if (pending != null) pending.mayStore = false;
  }

  File _file(String accountId, int remoteId, String path) {
    // FNV-1a over the path: a short file name that is the same on every run.
    var hash = 0xcbf29ce484222325;
    for (final b in utf8.encode(path)) {
      hash = (hash ^ b) * 0x100000001b3;
    }
    final name =
        (hash >>> 32).toRadixString(16).padLeft(8, '0') +
        (hash & 0xffffffff).toRadixString(16).padLeft(8, '0');
    return File('${root.path}/$accountId/$remoteId/$name');
  }

  Future<bool> contains(String accountId, int remoteId, String path) =>
      _onDisk(() => _file(accountId, remoteId, path).exists());

  /// The cached bytes, or null. A hit counts as use.
  Future<Uint8List?> read(String accountId, int remoteId, String path) =>
      _onDisk(() => _read(_file(accountId, remoteId, path)));

  Future<Uint8List?> _read(File file) async {
    try {
      final bytes = await file.readAsBytes();
      await file.setLastModified(DateTime.now());
      return bytes;
    } on FileSystemException {
      return null;
    }
  }

  /// Stores [bytes] unless the file is over [maxFileBytes]; returns whether
  /// it was kept.
  Future<bool> write(
    String accountId,
    int remoteId,
    String path,
    List<int> bytes,
  ) {
    if (bytes.length > maxFileBytes) return Future.value(false);
    _invalidate((accountId, remoteId, path));
    return _onDisk(() => _write(_file(accountId, remoteId, path), bytes));
  }

  Future<bool> _write(File file, List<int> bytes) async {
    if (bytes.length > maxFileBytes) return false;
    await file.parent.create(recursive: true);
    // Other cache instances may share this directory, including another isolate.
    final suffix = List.generate(
      16,
      (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final tmp = File('${file.path}.$suffix.tmp');
    try {
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } finally {
      if (await tmp.exists()) await tmp.delete();
    }
    await _trim();
    return true;
  }

  /// Cached bytes, or [fetch] and keep. A failed fetch throws and leaves
  /// nothing behind.
  Future<Uint8List> load(
    String accountId,
    int remoteId,
    String path,
    Future<List<int>> Function() fetch,
  ) {
    final key = (accountId, remoteId, path);
    final existing = _loads[key];
    if (existing != null) return existing.future;
    final pending = _PendingLoad();
    _loads[key] = pending;
    pending.future = _load(accountId, remoteId, path, fetch, pending)
        .whenComplete(() {
          if (identical(_loads[key], pending)) _loads.remove(key);
        });
    return pending.future;
  }

  Future<Uint8List> _load(
    String accountId,
    int remoteId,
    String path,
    Future<List<int>> Function() fetch,
    _PendingLoad pending,
  ) async {
    final hit = await read(accountId, remoteId, path);
    if (hit != null) return hit.asUnmodifiableView();
    final bytes = Uint8List.fromList(await fetch());
    try {
      await _onDisk(() async {
        if (pending.mayStore) {
          await _write(_file(accountId, remoteId, path), bytes);
        }
      });
    } on FileSystemException {
      // A full or unavailable cache must not hide a successful download.
    }
    return bytes.asUnmodifiableView();
  }

  Future<void> forget(String accountId, int remoteId, String path) {
    _invalidate((accountId, remoteId, path));
    return _onDisk(() async {
      final file = _file(accountId, remoteId, path);
      if (await file.exists()) await file.delete();
    });
  }

  Future<void> clearAccount(String accountId) {
    for (final key in _loads.keys.toList()) {
      if (key.$1 == accountId) _invalidate(key);
    }
    return _onDisk(() async {
      final dir = Directory('${root.path}/$accountId');
      if (await dir.exists()) await dir.delete(recursive: true);
    });
  }

  Future<int> sizeBytes() => _onDisk(() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final e in root.list(recursive: true)) {
      if (e is File && !e.path.endsWith('.tmp')) total += await e.length();
    }
    return total;
  });

  Future<void> _trim() async {
    final files = <(File, int, DateTime)>[];
    var total = 0;
    await for (final e in root.list(recursive: true)) {
      if (e is! File || e.path.endsWith('.tmp')) continue;
      final stat = await e.stat();
      if (stat.type != FileSystemEntityType.file) continue;
      files.add((e, stat.size, stat.modified));
      total += stat.size;
    }
    if (total <= maxTotalBytes) return;
    files.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (file, size, _) in files) {
      if (total <= maxTotalBytes) break;
      try {
        await file.delete();
      } on FileSystemException {
        if (await file.exists()) rethrow;
      }
      total -= size;
    }
  }
}

final class _PendingLoad {
  bool mayStore = true;
  late final Future<Uint8List> future;
}
