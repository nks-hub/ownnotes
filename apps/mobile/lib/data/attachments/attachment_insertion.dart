import 'attachment_service.dart';

/// Uploaded files held for insertion at the caret until the draft is saved.
final class AttachmentInsertion {
  AttachmentInsertion({
    required this.markdown,
    required this.service,
    required List<String> ids,
  }) : _ids = List.unmodifiable(ids);

  final String markdown;
  final AttachmentService service;
  final List<String> _ids;

  /// Call only after the editor's SQLite write has committed.
  Future<void> acknowledge() async {
    for (final id in _ids) {
      await service.complete(id);
    }
    release();
  }

  /// Leaves receipts on disk for recovery when the editor closes without saving.
  void release() {
    for (final id in _ids) {
      service.releaseEditorHold(id);
    }
  }
}
