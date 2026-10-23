import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/markdown/markdown_document.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import '../editor/edit_history.dart';
import 'checklist_model.dart';

/// Checklist mode of a note (spec 5.5). It edits the editor's own text
/// controller through the shared undo history, so every action is one undo
/// step and the note on the server stays a plain Markdown task list. It is
/// opened on request and never remembered as the way a note opens.
class ChecklistScreen extends StatefulWidget {
  const ChecklistScreen({
    required this.text,
    required this.history,
    required this.title,
    required this.readonly,
    required this.onChanged,
    required this.onEditAt,
    super.key,
  });

  final TextEditingController text;
  final EditHistory history;
  final String title;
  final bool readonly;

  /// Called after every edit so the editor saves the note.
  final VoidCallback onChanged;

  /// Leaves checklist mode and puts the Markdown caret at the offset.
  final ValueChanged<int> onEditAt;

  @override
  State<ChecklistScreen> createState() => _ChecklistScreenState();
}

/// One line of the open section: a task or a piece of prose for context.
class _Row {
  const _Row.task(this.item, this.index) : block = null;
  const _Row.context(this.block) : item = null, index = -1;
  final ChecklistItem? item;
  final int index;
  final MdBlock? block;
  int get line => item?.firstLine ?? block!.firstLine;
}

class _ChecklistScreenState extends State<ChecklistScreen> {
  final _add = TextEditingController();
  final _addFocus = FocusNode();

  @override
  void dispose() {
    _add.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  /// Applies [next] as one undo step and lets the editor save it.
  void _apply(String next) {
    if (widget.readonly || next == widget.text.text) return;
    final length = next.length;
    final caret = widget.text.selection.isValid
        ? widget.text.selection.extentOffset.clamp(0, length)
        : length;
    widget.history.apply(
      TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: caret),
      ),
    );
    widget.onChanged();
  }

  void _toggle(Checklist cl, ChecklistItem item) {
    final next = cl.toggled(item);
    if (next == null) {
      // The source no longer holds this task: open the note instead of
      // changing a similar-looking item.
      widget.onEditAt(item.task.line.start);
      return;
    }
    HapticFeedback.lightImpact();
    _apply(next);
  }

  void _submitAdd() {
    final next = Checklist.parse(widget.text.text).added(_add.text);
    if (next == null) return;
    _apply(next);
    _add.clear();
    _addFocus.requestFocus();
  }

  Future<void> _clear(Checklist cl) async {
    final l = AppLocalizations.of(context)!;
    final count = cl.clearableCount;
    if (count == 0) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.playlist_remove),
        content: Text(l.clearCompletedConfirm(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.clearCompleted),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _apply(Checklist.parse(widget.text.text).cleared());
    if (!mounted) return;
    showOwnSnackBar(
      context,
      l.clearedCompleted(count),
      actionLabel: l.recUndo,
      onAction: () {
        widget.history.undo();
        widget.onChanged();
      },
    );
  }

  void _reorder(Checklist cl, List<_Row> rows, int from, int to) {
    final a = rows[from], b = rows[to];
    if (a.item == null || b.item == null) return;
    final next = cl.movedTo(a.index, b.index);
    if (next == null) return;
    HapticFeedback.lightImpact();
    _apply(next);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: widget.text,
          builder: (context, _) {
            final cl = Checklist.parse(widget.text.text);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.isEmpty ? l.untitled : widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.tasksDone(cl.completed, cl.total),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: l.checklistMarkdown,
            icon: const Icon(Icons.edit_note),
            onPressed: () => widget.onEditAt(
              widget.text.selection.isValid
                  ? widget.text.selection.extentOffset
                  : widget.text.text.length,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.text,
          builder: (context, _) => _content(context, l),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l) {
    final cl = Checklist.parse(widget.text.text);
    final inLists = <int>{
      for (final i in cl.items)
        for (var n = i.firstLine; n <= i.lastLine; n++) n,
    };
    final rows = <_Row>[
      for (var i = 0; i < cl.items.length; i++)
        if (!cl.items[i].checked) _Row.task(cl.items[i], i),
      for (final b in cl.doc.blocks)
        if (!inLists.contains(b.firstLine) &&
            const {
              MdBlockKind.heading,
              MdBlockKind.paragraph,
              MdBlockKind.quote,
            }.contains(b.kind))
          _Row.context(b),
    ]..sort((a, b) => a.line.compareTo(b.line));
    final done = [
      for (var i = 0; i < cl.items.length; i++)
        if (cl.items[i].checked) _Row.task(cl.items[i], i),
    ];
    final openCount = rows.where((r) => r.item != null).length;
    final colors = context.own;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              if (cl.total == 0)
                Padding(
                  padding: const EdgeInsets.all(OwnSpace.xl),
                  child: Text(
                    l.checklistEmpty,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: rows.length,
                onReorderItem: (from, to) => _reorder(cl, rows, from, to),
                itemBuilder: (context, i) {
                  final row = rows[i];
                  if (row.item == null) {
                    return KeyedSubtree(
                      key: ValueKey('ctx${row.block!.range.start}'),
                      child: _contextRow(context, cl, row.block!),
                    );
                  }
                  final position = rows
                      .take(i + 1)
                      .where((r) => r.item != null)
                      .length;
                  return KeyedSubtree(
                    key: ValueKey('task${row.item!.task.markOffset}'),
                    child: _taskRow(
                      context,
                      cl,
                      row,
                      position: position,
                      total: openCount,
                      dragIndex: i,
                    ),
                  );
                },
              ),
              if (done.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.checklistCompletedGroup(done.length),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                ),
                for (var i = 0; i < done.length; i++)
                  _taskRow(
                    context,
                    cl,
                    done[i],
                    position: i + 1,
                    total: done.length,
                  ),
                if (!widget.readonly && cl.clearableCount > 0)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: OwnButton.secondary(
                      label: l.clearCompleted,
                      icon: Icons.playlist_remove,
                      fullWidth: true,
                      onPressed: () => _clear(cl),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (!widget.readonly) _quickAdd(context, l),
      ],
    );
  }

  Widget _quickAdd(BuildContext context, AppLocalizations l) {
    return Material(
      color: context.own.raised,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _add,
                focusNode: _addFocus,
                textInputAction: TextInputAction.done,
                // Enter keeps the keyboard so several items go in quickly.
                onSubmitted: (_) => _submitAdd(),
                decoration: InputDecoration(
                  hintText: l.checklistAdd,
                  prefixIcon: const Icon(Icons.add_task),
                ),
              ),
            ),
            IconButton(
              tooltip: l.checklistAdd,
              icon: const Icon(Icons.add),
              onPressed: _submitAdd,
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextRow(BuildContext context, Checklist cl, MdBlock block) {
    final colors = context.own;
    final text = block.range
        .of(cl.text)
        .replaceAll(RegExp(r'^[#>\s]+', multiLine: true), '')
        .trim();
    final heading = block.kind == MdBlockKind.heading;
    return InkWell(
      onTap: () => widget.onEditAt(block.range.start),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: OwnShape.target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: heading ? 2 : 3,
              overflow: TextOverflow.ellipsis,
              style: heading
                  ? Theme.of(context).textTheme.titleSmall
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskRow(
    BuildContext context,
    Checklist cl,
    _Row row, {
    required int position,
    required int total,
    int? dragIndex,
  }) {
    final l = AppLocalizations.of(context)!;
    final colors = context.own;
    final item = row.item!;
    final canUp = cl.previousSibling(row.index) >= 0;
    final canDown = cl.nextSibling(row.index) >= 0;
    final label = item.label.isEmpty ? l.untitled : item.label;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            checked: item.checked,
            enabled: !widget.readonly,
            label: label,
            hint: l.checklistPosition(position, total),
            excludeSemantics: true,
            onTap: widget.readonly ? null : () => _toggle(cl, item),
            child: InkWell(
              onTap: widget.readonly ? null : () => _toggle(cl, item),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: EdgeInsets.only(left: 8.0 + 24.0 * item.depth),
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.checked,
                        onChanged: widget.readonly
                            ? null
                            : (_) => _toggle(cl, item),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: item.checked
                                      ? colors.textSecondary
                                      : null,
                                  decoration: item.checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!widget.readonly)
          PopupMenuButton<String>(
            tooltip: l.checklistItemMenu,
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'up':
                  final next = cl.movedUp(row.index);
                  if (next != null) _apply(next);
                case 'down':
                  final next = cl.movedDown(row.index);
                  if (next != null) _apply(next);
                case 'edit':
                  widget.onEditAt(item.task.line.start);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'up',
                enabled: canUp,
                child: _MenuRow(Icons.arrow_upward, l.moveUp),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: canDown,
                child: _MenuRow(Icons.arrow_downward, l.moveDown),
              ),
              PopupMenuItem(
                value: 'edit',
                child: _MenuRow(Icons.edit_note, l.checklistMarkdown),
              ),
            ],
          ),
        if (dragIndex != null && !widget.readonly)
          ReorderableDragStartListener(
            index: dragIndex,
            child: SizedBox.square(
              dimension: OwnShape.target,
              child: Icon(Icons.drag_indicator, color: colors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 16),
      Flexible(child: Text(label)),
    ],
  );
}
