import 'dart:convert';
import 'dart:io';

/// A file that came with a share (picture, document), already inside the
/// capture's own folder.
final class CaptureFile {
  const CaptureFile({
    required this.name,
    required this.mime,
    required this.path,
  });
  final String name;
  final String mime;
  final String path;
}

/// Content received from another app and kept until the owner decided where
/// it goes.
final class Capture {
  const Capture({
    required this.id,
    required this.title,
    required this.text,
    required this.files,
    required this.createdAt,
    this.accountHint,
  });

  final String id;
  final String title;
  final String text;
  final List<CaptureFile> files;
  final DateTime createdAt;

  /// Local account id named by the sender, if any. Never used without
  /// checking it against the signed-in accounts.
  final String? accountHint;

  bool get isEmpty => text.trim().isEmpty && files.isEmpty;
}

/// One delivery as the platform hands it over, files still in the platform's
/// own inbox folder.
final class NativeCapture {
  const NativeCapture({
    required this.id,
    required this.title,
    required this.text,
    required this.createdAt,
    required this.files,
    this.accountHint,
  });

  factory NativeCapture.fromMap(Map<Object?, Object?> map) => NativeCapture(
    id: map['id']! as String,
    title: (map['title'] as String?) ?? '',
    text: (map['text'] as String?) ?? '',
    createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
    accountHint: map['accountHint'] as String?,
    files: [
      for (final f in (map['files'] as List<Object?>? ?? const []))
        if (f is Map)
          CaptureFile(
            name: f['name']! as String,
            mime: (f['mime'] as String?) ?? 'application/octet-stream',
            path: f['path']! as String,
          ),
    ],
  );

  final String id;
  final String title;
  final String text;
  final int createdAt;
  final String? accountHint;
  final List<CaptureFile> files;
}

/// Pending captures in app storage: `pending/<id>/capture.json` with the
/// files beside it. A capture appears only when its folder is renamed into
/// place, after everything was copied, so a crash leaves it either whole or
/// absent. Finished ids are remembered in `done/` so a repeated delivery
/// does not bring a capture back.
final class CaptureStore {
  CaptureStore(this.root);

  final Directory root;
  static const _maxDone = 500;

  Directory _pending(String id) => Directory('${root.path}/pending/$id');
  File _done(String id) => File('${root.path}/done/$id');

  /// Copies [capture] in. Returns false when it was stored or finished
  /// before, so the caller can acknowledge a repeated delivery safely.
  Future<bool> ingest(NativeCapture capture) async {
    final id = capture.id;
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
      throw const FormatException('invalid_capture_id');
    }
    if (await _done(id).exists() || await _pending(id).exists()) return false;
    final work = Directory('${root.path}/tmp/$id');
    if (await work.exists()) await work.delete(recursive: true);
    await Directory('${work.path}/files').create(recursive: true);
    final files = <Map<String, String>>[];
    for (var i = 0; i < capture.files.length; i++) {
      final f = capture.files[i];
      final target = '${work.path}/files/$i';
      // Copy, never move: until the platform inbox is acknowledged it must
      // stay complete, or a crash here would redeliver a capture without
      // its files.
      await File(f.path).copy(target);
      files.add({'name': f.name, 'mime': f.mime, 'file': '$i'});
    }
    await File('${work.path}/capture.json').writeAsString(
      jsonEncode({
        'id': id,
        'title': capture.title,
        'text': capture.text,
        'createdAt': capture.createdAt,
        'accountHint': capture.accountHint,
        'files': files,
      }),
      flush: true,
    );
    await Directory('${root.path}/pending').create(recursive: true);
    await work.rename(_pending(id).path);
    return true;
  }

  /// Waiting captures, oldest first.
  Future<List<Capture>> pending() async {
    final dir = Directory('${root.path}/pending');
    if (!await dir.exists()) return const [];
    final out = <Capture>[];
    await for (final entry in dir.list()) {
      if (entry is! Directory) continue;
      final capture = await _read(entry);
      if (capture != null) out.add(capture);
    }
    return out..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  Future<Capture?> _read(Directory dir) async {
    try {
      final json =
          jsonDecode(await File('${dir.path}/capture.json').readAsString())
              as Map<String, Object?>;
      return Capture(
        id: json['id']! as String,
        title: json['title']! as String,
        text: json['text']! as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          json['createdAt']! as int,
        ),
        accountHint: json['accountHint'] as String?,
        files: [
          for (final f in json['files']! as List<Object?>)
            if (f is Map)
              CaptureFile(
                name: f['name']! as String,
                mime: f['mime']! as String,
                path: '${dir.path}/files/${f['file']}',
              ),
        ],
      );
    } on Object {
      return null;
    }
  }

  /// The capture became a note (or was discarded): remember the id and drop
  /// the stored copy.
  Future<void> complete(String id) async {
    await Directory('${root.path}/done').create(recursive: true);
    await _done(id).writeAsString('', flush: true);
    final dir = _pending(id);
    if (await dir.exists()) await dir.delete(recursive: true);
    await _pruneDone();
  }

  Future<void> _pruneDone() async {
    final files = <(File, DateTime)>[];
    await for (final e in Directory('${root.path}/done').list()) {
      if (e is File) files.add((e, (await e.stat()).modified));
    }
    if (files.length <= _maxDone) return;
    files.sort((a, b) => a.$2.compareTo(b.$2));
    for (final (file, _) in files.take(files.length - _maxDone)) {
      await file.delete();
    }
  }
}
