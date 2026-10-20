import 'dart:convert';
import 'dart:io';
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
      _file(accountId, remoteId, path).exists();

  /// The cached bytes, or null. A hit counts as use.
  Future<Uint8List?> read(String accountId, int remoteId, String path) async {
    final file = _file(accountId, remoteId, path);
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
  ) async {
    if (bytes.length > maxFileBytes) return false;
    final file = _file(accountId, remoteId, path);
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
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
  ) async {
    final hit = await read(accountId, remoteId, path);
    if (hit != null) return hit;
    final bytes = Uint8List.fromList(await fetch());
    await write(accountId, remoteId, path, bytes);
    return bytes;
  }

  Future<void> forget(String accountId, int remoteId, String path) async {
    final file = _file(accountId, remoteId, path);
    if (await file.exists()) await file.delete();
  }

  Future<void> clearAccount(String accountId) async {
    final dir = Directory('${root.path}/$accountId');
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  Future<int> sizeBytes() async {
    var total = 0;
    if (!await root.exists()) return 0;
    await for (final e in root.list(recursive: true)) {
      if (e is File && !e.path.endsWith('.tmp')) total += await e.length();
    }
    return total;
  }

  Future<void> _trim() async {
    final files = <(File, int, DateTime)>[];
    var total = 0;
    await for (final e in root.list(recursive: true)) {
      if (e is! File || e.path.endsWith('.tmp')) continue;
      final stat = await e.stat();
      files.add((e, stat.size, stat.modified));
      total += stat.size;
    }
    if (total <= maxTotalBytes) return;
    files.sort((a, b) => a.$3.compareTo(b.$3));
    for (final (file, size, _) in files) {
      if (total <= maxTotalBytes) break;
      await file.delete();
      total -= size;
    }
  }
}
