import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/attachments/attachment_insertion.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'edit_history.dart';

/// What the Attach menu asks for. The attachment package handles it.
enum AttachKind { photo, camera, file, voice }

/// Called when an Attach menu row is chosen; the editor does not move any
/// file itself. Null disables the rows.
/// Returns a pending insertion to acknowledge after saving the draft.
typedef AttachHandler = FutureOr<AttachmentInsertion?> Function(AttachKind kind);

/// Commands of the Format and Insert menus and of the Task button.
enum EditorCommand {
  heading1,
  heading2,
  heading3,
  bold,
  italic,
  strike,
  quote,
  bullets,
  numbered,
  code,
  indent,
  outdent,
  task,
  link,
  mention,
  emoji,
  smartPicker,
  template,
}

/// The 48 dp formatting dock above the keyboard (spec 5.2):
/// Undo, Redo | Format, Task, Attach, Insert.
class FormattingDock extends StatelessWidget {
  const FormattingDock({
    required this.history,
    required this.onCommand,
    required this.onAttach,
    super.key,
  });

  final EditHistory history;
  final ValueChanged<EditorCommand> onCommand;
  final FutureOr<void> Function(AttachKind kind)? onAttach;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    return Material(
      color: colors.raised,
      child: SizedBox(
        height: OwnShape.target,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ListenableBuilder(
            listenable: history,
            builder: (context, _) => Row(
              children: [
                IconButton(
                  tooltip: l.undo,
                  icon: const Icon(Icons.undo),
                  onPressed: history.canUndo ? history.undo : null,
                ),
                IconButton(
                  tooltip: l.redo,
                  icon: const Icon(Icons.redo),
                  onPressed: history.canRedo ? history.redo : null,
                ),
                SizedBox(
                  height: 24,
                  child: VerticalDivider(width: 16, color: colors.outline),
                ),
                _Menu<EditorCommand>(
                  tooltip: l.dockFormat,
                  icon: Icons.text_format,
                  onSelected: onCommand,
                  entries: [
                    _item(EditorCommand.heading1, Icons.looks_one_outlined, '${l.fmtHeading} 1'),
                    _item(EditorCommand.heading2, Icons.looks_two_outlined, '${l.fmtHeading} 2'),
                    _item(EditorCommand.heading3, Icons.looks_3_outlined, '${l.fmtHeading} 3'),
                    _item(EditorCommand.bold, Icons.format_bold, l.fmtBold),
                    _item(EditorCommand.italic, Icons.format_italic, l.fmtItalic),
                    _item(EditorCommand.strike, Icons.format_strikethrough, l.fmtStrike),
                    _item(EditorCommand.quote, Icons.format_quote, l.fmtQuote),
                    _item(EditorCommand.bullets, Icons.format_list_bulleted, l.fmtList),
                    _item(EditorCommand.numbered, Icons.format_list_numbered, l.fmtNumbered),
                    _item(EditorCommand.code, Icons.code, l.fmtCode),
                    _item(EditorCommand.indent, Icons.format_indent_increase, l.fmtIndent),
                    _item(EditorCommand.outdent, Icons.format_indent_decrease, l.fmtOutdent),
                  ],
                ),
                IconButton(
                  tooltip: l.dockTask,
                  icon: const Icon(Icons.check_box_outlined),
                  onPressed: () => onCommand(EditorCommand.task),
                ),
                _Menu<AttachKind>(
                  tooltip: l.dockAttach,
                  icon: Icons.attach_file,
                  onSelected: (k) => onAttach?.call(k),
                  entries: [
                    _item(AttachKind.photo, Icons.photo_outlined, l.attachPhoto, enabled: onAttach != null),
                    _item(AttachKind.camera, Icons.photo_camera_outlined, l.attachCamera, enabled: onAttach != null),
                    _item(AttachKind.file, Icons.insert_drive_file_outlined, l.attachFile, enabled: onAttach != null),
                    _item(AttachKind.voice, Icons.mic_none, l.attachVoice, enabled: onAttach != null),
                  ],
                ),
                _Menu<EditorCommand>(
                  tooltip: l.dockInsert,
                  icon: Icons.add_circle_outline,
                  onSelected: onCommand,
                  entries: [
                    _item(EditorCommand.link, Icons.link, l.fmtLink),
                    _item(EditorCommand.mention, Icons.alternate_email, l.insertMention),
                    _item(EditorCommand.emoji, Icons.emoji_emotions_outlined, l.insertEmoji),
                    _item(EditorCommand.smartPicker, Icons.travel_explore_outlined, l.smartPicker),
                    _item(EditorCommand.template, Icons.description_outlined, l.templates),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

PopupMenuEntry<T> _item<T>(T value, IconData icon, String label, {bool enabled = true}) =>
    PopupMenuItem<T>(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Flexible(child: Text(label)),
        ],
      ),
    );

class _Menu<T> extends StatelessWidget {
  const _Menu({
    required this.tooltip,
    required this.icon,
    required this.entries,
    required this.onSelected,
  });
  final String tooltip;
  final IconData icon;
  final List<PopupMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: tooltip,
    icon: Icon(icon),
    position: PopupMenuPosition.over,
    onSelected: onSelected,
    itemBuilder: (_) => entries,
  );
}
