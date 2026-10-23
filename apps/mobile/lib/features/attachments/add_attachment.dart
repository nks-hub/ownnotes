import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';

import '../../data/attachments/attachment_service.dart';
import '../../data/attachments/attachment_insertion.dart';
import '../../data/attachments/providers.dart';
import '../../data/attachments/staging.dart';
import '../../l10n/app_localizations.dart';
import 'attach_sources.dart';
import 'voice_screen.dart';

export 'attach_sources.dart' show AttachKind;

/// The one entry point of the editor's Attach menu.
///
/// Picks or records the file, copies it into durable staging, uploads it and
/// returns an insertion to acknowledge after the draft commits. Its Markdown
/// is inserted at the caret as one undo step. Returns null when nothing was added, or
/// when the file could not go to the server yet: it then stays staged with
/// its draft, shows up in the attachments sheet, and its link is added to
/// the note once the upload has happened.
Future<AttachmentInsertion?> addAttachment(
  BuildContext context,
  WidgetRef ref,
  LocalNote note,
  AttachKind kind,
) async {
  final l = AppLocalizations.of(context)!;
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final service = await ref.read(attachmentServiceProvider.future);

  final List<PickedFile> picked;
  var recording = false;
  try {
    final sources = ref.read(attachmentSourcesProvider);
    switch (kind) {
      case AttachKind.photo:
        picked = await sources.photos();
      case AttachKind.camera:
        final photo = await sources.camera();
        picked = [?photo];
      case AttachKind.file:
        picked = await sources.files();
      case AttachKind.voice:
        recording = true;
        if (!context.mounted) return null;
        final path = await navigator.push<String>(
          MaterialPageRoute(builder: (_) => const VoiceRecordingScreen()),
        );
        final stamp = DateTime.now()
            .toIso8601String()
            .substring(0, 16)
            .replaceAll(RegExp(r'[-:]'), '')
            .replaceAll('T', '-');
        picked = [
          if (path != null)
            PickedFile(path: path, name: 'voice-$stamp.m4a', mime: 'audio/mp4'),
        ];
    }
  } on Object {
    messenger.showSnackBar(SnackBar(content: Text(l.attachReadFailed)));
    return null;
  }

  final staged = <StagedAttachment>[];
  final delivered = <String>{};
  try {
    for (final file in picked) {
      try {
        staged.add(
          await service.stage(
            accountId: note.accountId,
            noteId: note.id,
            source: File(file.path),
            name: file.name,
            mime: file.mime,
            holdForEditor: true,
          ),
        );
        // The recording is safe in staging now; the voice folder copy goes.
        if (recording) await File(file.path).delete();
      } on AttachmentTooLarge {
        messenger.showSnackBar(SnackBar(content: Text(l.attachTooLarge)));
      } on Object {
        messenger.showSnackBar(SnackBar(content: Text(l.attachReadFailed)));
      }
    }

    final links = <String>[];
    final uploaded = <String>[];
    for (final item in staged) {
      if (!context.mounted) break;
      UploadOutcome outcome = await _withProgress<UploadOutcome>(
        context,
        l.attachWorking,
        service.upload(item.id),
      );
      while (outcome is UploadFailed) {
        if (!context.mounted) break;
        final reason = attachErrorText(l, outcome.code);
        final again = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l.attachUploadFailedTitle),
            content: Text('${item.name}\n$reason'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l.attachKeepForLater),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l.retry),
              ),
            ],
          ),
        );
        if (again != true || !context.mounted) break;
        outcome = await _withProgress<UploadOutcome>(
          context,
          l.attachWorking,
          service.retry(item.id),
        );
      }
      switch (outcome) {
        case Uploaded(:final markdown):
          links.add(markdown);
          uploaded.add(item.id);
        case WaitingForNote():
          messenger.showSnackBar(SnackBar(content: Text(l.attachSavedWaiting)));
        case UploadFailed():
          messenger.showSnackBar(SnackBar(content: Text(l.attachSavedQueued)));
      }
    }
    if (links.isEmpty) return null;
    delivered.addAll(uploaded);
    return AttachmentInsertion(
      markdown: links.join('\n'),
      service: service,
      ids: uploaded,
    );
  } finally {
    for (final item in staged) {
      if (!delivered.contains(item.id)) service.releaseEditorHold(item.id);
    }
  }
}

/// Short text for a failure code of [StagedAttachment.error].
String attachErrorText(AppLocalizations l, String? code) => switch (code) {
  'auth' => l.attachErrAuth,
  'too_large' => l.attachErrTooLarge,
  'denied' => l.attachErrDenied,
  'note_gone' => l.attachErrNoteGone,
  'server' => l.attachErrServer,
  _ => l.attachErrOffline,
};

Future<T> _withProgress<T>(
  BuildContext context,
  String label,
  Future<T> work,
) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    return await work;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
