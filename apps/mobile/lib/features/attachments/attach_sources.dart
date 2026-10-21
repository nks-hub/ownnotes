import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

export '../editor/format_dock.dart' show AttachKind;

/// A file the system picker handed over; [path] is readable by the app.
final class PickedFile {
  const PickedFile({required this.path, required this.name, this.mime});
  final String path;
  final String name;
  final String? mime;
}

/// The system pickers behind one interface, so tests can supply files.
abstract interface class AttachmentSources {
  Future<List<PickedFile>> photos();
  Future<PickedFile?> camera();
  Future<List<PickedFile>> files();
}

final class PlatformAttachmentSources implements AttachmentSources {
  const PlatformAttachmentSources();

  @override
  Future<List<PickedFile>> photos() async => [
    for (final x in await ImagePicker().pickMultiImage())
      PickedFile(path: x.path, name: x.name, mime: x.mimeType),
  ];

  @override
  Future<PickedFile?> camera() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera);
    if (x == null) return null;
    // The picker names the file with a random id; the note shows this name.
    final dot = x.name.lastIndexOf('.');
    final ext = dot < 0 ? '.jpg' : x.name.substring(dot);
    return PickedFile(
      path: x.path,
      name: 'photo-${_stamp()}$ext',
      mime: x.mimeType,
    );
  }

  @override
  Future<List<PickedFile>> files() async => [
    for (final f in await FilePicker.pickFiles())
      if (f.path != null) PickedFile(path: f.path!, name: f.name),
  ];
}

String _stamp() {
  final n = DateTime.now();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${two(n.month)}${two(n.day)}-${two(n.hour)}${two(n.minute)}${two(n.second)}';
}

final attachmentSourcesProvider = Provider<AttachmentSources>(
  (ref) => const PlatformAttachmentSources(),
);
