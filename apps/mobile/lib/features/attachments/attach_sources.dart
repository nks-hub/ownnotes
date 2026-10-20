import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// What the editor's Attach menu offers.
enum AttachKind { photo, camera, file, voice }

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
    return x == null
        ? null
        : PickedFile(path: x.path, name: x.name, mime: x.mimeType);
  }

  @override
  Future<List<PickedFile>> files() async => [
    for (final f in await FilePicker.pickFiles())
      if (f.path != null) PickedFile(path: f.path!, name: f.name),
  ];
}

final attachmentSourcesProvider = Provider<AttachmentSources>(
  (ref) => const PlatformAttachmentSources(),
);
