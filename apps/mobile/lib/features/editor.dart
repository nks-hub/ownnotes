import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:notes_store/notes_store.dart';
import '../core/markdown/live_controller.dart';
import '../core/markdown/live_styling.dart';
import '../core/markdown/markdown_document.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'checklist/checklist_screen.dart';
import 'editor/document_header.dart';
import 'editor/edit_history.dart';
import 'editor/editing_commands.dart';
import 'editor/format_dock.dart';
import 'editor/preview.dart';
import 'editor/reference_picker.dart';
import 'editor/share_sheet.dart';
import 'editor/suggestion_controller.dart';
import 'editor/suggestion_model.dart';
import 'editor/suggestion_popup.dart';
import 'editor/suggestion_source.dart';
import 'recovery.dart';
import 'templates/templates.dart';
import 'templates/templates_screen.dart';

export '../core/markdown/live_controller.dart' show MarkdownTextController;
export 'editor/format_dock.dart' show AttachKind, AttachHandler;

/// Offsets of the mark between the brackets of each task item (`- [ ]`,
/// `1. [x]`) in the order the preview shows its checkboxes. The document
/// model decides which items are tasks; an empty list means the model and the
/// preview parser disagree, and then nothing is ticked.
List<int> taskMarks(String text) => [
  for (final t in MarkdownDocument.parse(text).renderedTasks()) t.markOffset,
];

/// Offset in [source] of the text a preview tap landed on: [word] is the
/// tapped word and [around] the plain text following it. [occurrence] counts
/// equal texts before the tapped one in the preview.
int sourceOffsetFor(
  String source,
  String word,
  String around, {
  int occurrence = 0,
}) => MarkdownDocument.parse(
  source,
).offsetOfText(word, around, occurrence: occurrence);

/// Styles raw Markdown line by line; the markers stay in the text. The spans
/// always concatenate to exactly [text].
List<TextSpan> markdownSpans(
  String text,
  TextStyle base, {
  required Color dim,
  required Color accent,
  Color? codeBackground,
  bool monospace = false,
}) => buildLiveMarkdownSpans(
  text,
  base,
  LiveMarkdownStyle(
    marker: dim,
    link: accent,
    codeBackground: codeBackground ?? dim.withValues(alpha: 0.15),
    monospaceBody: monospace,
  ),
);

enum _Details { title, category }

enum _Overflow {
  details,
  favorite,
  find,
  checklist,
  attachments,
  history,
  export,
  delete,
}

/// The writing screen of one note: raw Markdown with live styling, formatting
/// dock, typing suggestions, explicit preview and checklist mode.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({
    required this.note,
    this.onAttach,
    this.startInChecklist = false,
    super.key,
  });
  final LocalNote note;

  /// Chosen in the dock's Attach menu. Null leaves the rows disabled.
  final AttachHandler? onAttach;

  /// Opens checklist mode at once (a checklist widget or "New checklist").
  /// Notes never open in it on their own.
  final bool startInChecklist;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final MarkdownTextController _text;
  late final EditHistory _history;
  late final TextEditingController _category;
  late final SuggestionController _suggest;
  final _textFocus = FocusNode();
  final _fieldKey = GlobalKey();
  final _bodyKey = GlobalKey();

  /// The note's current database row; the widget's copy is the one opened.
  late LocalNote _row;
  bool get _readonly => _row.readonly;
  late int _revision;
  late bool _favorite;
  Timer? _debounce;
  Future<void> _tail = Future<void>.value();
  bool _dirty = false;
  bool _failed = false;
  String _failReason = 'local_write';
  bool _preview = false;
  bool _finding = false;
  final _find = TextEditingController();
  List<int> _matches = const [];
  int _matchAt = -1;
  bool _allowPop = false;
  bool _external = false;
  late String _lastText;
  Future<SuggestionSource?>? _sourceFuture;

  /// The note as last saved here or taken from the database.
  late LocalNote _saved;
  StreamSubscription<List<LocalNote>>? _pulled;
  Timer? _live;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = TextEditingController(text: widget.note.title);
    _text = MarkdownTextController(text: widget.note.content);
    _category = TextEditingController(text: widget.note.category);
    _history = EditHistory(_text);
    _lastText = _text.text;
    _revision = widget.note.revision;
    _favorite = widget.note.favorite;
    _saved = widget.note;
    _row = widget.note;
    _suggest = SuggestionController(
      source: _source,
      commands: const [],
      czech: false,
    );
    _textFocus.onKeyEvent = _onKey;
    _text.addListener(_textChanged);
    _pulled = ref
        .read(runtimeProvider)
        .database
        .watchNotes(widget.note.accountId)
        .listen(_takePulled);
    // Another device (or account) writing to the same note sees this one's
    // text within seconds and the other way round.
    _live = Timer.periodic(const Duration(seconds: 4), (_) {
      final state = WidgetsBinding.instance.lifecycleState;
      if (state != null && state != AppLifecycleState.resumed) return;
      ref
          .read(runtimeProvider)
          .sync
          .sync(widget.note.accountId)
          .catchError((Object _) {});
    });
    if (widget.startInChecklist) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openChecklist();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l = AppLocalizations.of(context)!;
    _suggest.czech = Localizations.localeOf(context).languageCode == 'cs';
    _suggest.commands = _localCommands(l);
  }

  Future<SuggestionSource?> _source() => _sourceFuture ??= () async {
    try {
      final runtime = ref.read(runtimeProvider);
      final account = await runtime.database.account(widget.note.accountId);
      if (account == null) return null;
      return await ref.read(suggestionSourceFactoryProvider)(account);
    } on Object {
      return null;
    }
  }();

  List<LocalCommand> _localCommands(AppLocalizations l) {
    SuggestionItem item(
      String id,
      String title,
      IconData icon,
      String insert, {
      int caretBack = 0,
      SuggestionAction action = SuggestionAction.none,
    }) => SuggestionItem(
      id: 'cmd:$id',
      title: title,
      subtitle: insert.split('\n').first.trim(),
      icon: icon,
      insert: insert,
      caretBack: caretBack,
      action: action,
    );
    final now = DateTime.now();
    return [
      LocalCommand(
        item('today', l.cmdToday, Icons.event_outlined, DateFormat('yyyy-MM-dd', 'en').format(now)),
        ['date', 'today', 'datum', 'dnes'],
      ),
      LocalCommand(
        item('time', l.cmdTime, Icons.schedule, DateFormat('HH:mm', 'en').format(now)),
        ['time', 'cas', 'čas'],
      ),
      LocalCommand(item('h1', '${l.fmtHeading} 1', Icons.looks_one_outlined, '# '), ['h1', 'heading', 'nadpis']),
      LocalCommand(item('h2', '${l.fmtHeading} 2', Icons.looks_two_outlined, '## '), ['h2', 'heading', 'nadpis']),
      LocalCommand(item('h3', '${l.fmtHeading} 3', Icons.looks_3_outlined, '### '), ['h3', 'heading', 'nadpis']),
      LocalCommand(item('list', l.fmtList, Icons.format_list_bulleted, '- '), ['list', 'bullet', 'seznam']),
      LocalCommand(item('tasks', l.fmtChecklist, Icons.check_box_outlined, '- [ ] '), ['task', 'todo', 'ukol', 'úkol']),
      LocalCommand(item('quote', l.fmtQuote, Icons.format_quote, '> '), ['quote', 'citace']),
      LocalCommand(item('code', l.fmtCode, Icons.code, '```\n\n```', caretBack: 4), ['code', 'kod', 'kód']),
      LocalCommand(
        item('table', l.cmdTable, Icons.table_chart_outlined, '| A | B |\n| --- | --- |\n|   |   |\n'),
        ['table', 'tabulka'],
      ),
      LocalCommand(item('rule', l.cmdDivider, Icons.horizontal_rule, '---\n'), ['divider', 'rule', 'cara', 'čára']),
      LocalCommand(
        item('info', l.calloutInfo, Icons.info_outline, '::: info\n\n:::\n', caretBack: 5),
        ['callout', 'info'],
      ),
      LocalCommand(
        item('warn', l.calloutWarning, Icons.warning_amber, '::: warn\n\n:::\n', caretBack: 5),
        ['callout', 'warning', 'varovani', 'varování'],
      ),
      LocalCommand(
        item(
          'details',
          l.detailsDefault,
          Icons.expand_circle_down_outlined,
          '<details>\n<summary>${l.detailsDefault}</summary>\n\n\n</details>\n',
          caretBack: 12,
        ),
        ['details', 'summary', 'detail'],
      ),
      LocalCommand(
        item('template', l.templates, Icons.description_outlined, '', action: SuggestionAction.template),
        ['template', 'sablona', 'šablona'],
      ),
    ];
  }

  // ---- text changes ----

  void _textChanged() {
    final changed = _text.text != _lastText;
    _lastText = _text.text;
    if (changed && !_external) _changed();
    if (_preview || _readonly) return;
    _suggest.update(_text.value, _text.document);
    if (_suggest.eagerStart != null && !_suggest.isOpen && changed) {
      _suggest.eagerStart = null;
    }
  }

  void _changed() {
    setState(() {
      _dirty = true;
      _failed = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _save);
  }

  TextEditingValue get _value {
    final v = _text.value;
    return v.selection.isValid
        ? v
        : v.copyWith(selection: TextSelection.collapsed(offset: v.text.length));
  }

  /// Applies [edit] to the text as one undo step and keeps the focus.
  void _apply(TextEditingValue Function(TextEditingValue) edit) {
    if (_readonly) return;
    _history.apply(edit(_value));
    _textFocus.requestFocus();
  }

  void _runCommand(EditorCommand command) {
    switch (command) {
      case EditorCommand.heading1:
        _apply((v) => toggleHeading(v, 1));
      case EditorCommand.heading2:
        _apply((v) => toggleHeading(v, 2));
      case EditorCommand.heading3:
        _apply((v) => toggleHeading(v, 3));
      case EditorCommand.bold:
        _apply((v) => toggleWrap(v, '**', '**'));
      case EditorCommand.italic:
        _apply((v) => toggleWrap(v, '*', '*'));
      case EditorCommand.strike:
        _apply((v) => toggleWrap(v, '~~', '~~'));
      case EditorCommand.quote:
        _apply(toggleQuote);
      case EditorCommand.bullets:
        _apply((v) => toggleList(v, ListKind.bullet));
      case EditorCommand.numbered:
        _apply((v) => toggleList(v, ListKind.numbered));
      case EditorCommand.code:
        _apply(toggleCode);
      case EditorCommand.indent:
        _apply(indent);
      case EditorCommand.outdent:
        _apply(outdent);
      case EditorCommand.task:
        _apply(toggleTask);
      case EditorCommand.link:
        _apply(insertLink);
      case EditorCommand.mention:
        _apply((v) => insertTrigger(v, '@'));
      case EditorCommand.emoji:
        _apply((v) {
          final next = insertTrigger(v, ':');
          _suggest.eagerStart = next.selection.start - 1;
          return next;
        });
      case EditorCommand.smartPicker:
        _insertReference();
      case EditorCommand.template:
        _insertTemplate();
    }
  }

  // ---- suggestions ----

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_suggest.isOpen || event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _suggest.move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _suggest.move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      _suggest.dismiss();
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        _suggest.current != null) {
      if (event is KeyDownEvent) _accept(_suggest.current!);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _accept(SuggestionItem item) async {
    final state = _suggest.state;
    if (state == null) return;
    final q = state.query;
    _suggest.dismiss();
    final v = _value;
    final end = v.selection.isCollapsed && v.selection.start >= q.start
        ? v.selection.start
        : q.end;
    if (q.start >= v.text.length || end > v.text.length) return;
    switch (item.action) {
      case SuggestionAction.none:
        _apply((v) {
          final next = replaceRange(v, q.start, end, item.insert);
          return item.caretBack == 0
              ? next
              : next.copyWith(
                  selection: TextSelection.collapsed(
                    offset: next.selection.start - item.caretBack,
                  ),
                );
        });
      case SuggestionAction.template:
        final template = await showTemplatePicker(context);
        if (template == null || !mounted) return;
        _apply(
          (v) => _replaceChecked(
            v,
            q.start,
            end,
            expandTemplate(template.content, DateTime.now(), title: _title.text),
          ),
        );
      case SuggestionAction.reference:
        final link = await showReferencePicker(
          context,
          source: _source,
          providerId: item.id.substring('ref:'.length),
        );
        if (link == null || !mounted) return;
        _apply((v) => _replaceChecked(v, q.start, end, link));
    }
  }

  /// Replaces the typed trigger text when it is still there, otherwise
  /// inserts at the caret.
  TextEditingValue _replaceChecked(
    TextEditingValue v,
    int start,
    int end,
    String insert,
  ) {
    final intact =
        end <= v.text.length &&
        start < end &&
        '@:/'.contains(v.text[start]);
    return intact
        ? replaceRange(v, start, end, insert)
        : insertAtSelection(v, insert);
  }

  Future<void> _insertReference() async {
    final link = await showReferencePicker(context, source: _source);
    if (link == null || !mounted) return;
    _apply((v) => insertAtSelection(v, link));
  }

  Future<void> _insertTemplate() async {
    final template = await showTemplatePicker(context);
    if (template == null || !mounted) return;
    final content = expandTemplate(
      template.content,
      DateTime.now(),
      title: _title.text,
    );
    _apply((v) => insertAtSelection(v, content));
  }

  Rect? _caretRect() {
    final stack = _bodyKey.currentContext?.findRenderObject();
    final field = _fieldKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || field == null || !stack.attached) return null;
    RenderEditable? editable;
    void visit(RenderObject o) {
      if (editable != null) return;
      if (o is RenderEditable) {
        editable = o;
        return;
      }
      o.visitChildren(visit);
    }

    visit(field);
    final e = editable;
    final sel = _text.selection;
    if (e == null || !e.attached || !sel.isValid || !e.hasSize) return null;
    try {
      final local = e.getLocalRectForCaret(TextPosition(offset: sel.extentOffset));
      return MatrixUtils.transformRect(e.getTransformTo(stack), local);
    } on Object {
      return null;
    }
  }

  Widget _popup() => ListenableBuilder(
    listenable: Listenable.merge([_suggest, _text]),
    builder: (context, _) {
      final box = _bodyKey.currentContext?.findRenderObject();
      if (_preview || !_suggest.isOpen || box is! RenderBox || !box.hasSize) {
        return const SizedBox.shrink();
      }
      final caret = _caretRect();
      final placement = placeSuggestionPopup(
        caret: caret ?? Rect.fromLTWH(0, box.size.height, 0, 0),
        area: box.size,
        items: math.max(1, _suggest.state?.items.length ?? 1),
      );
      return SuggestionPopup(
        controller: _suggest,
        placement: placement,
        onAccept: _accept,
      );
    },
  );

  // ---- preview ----

  /// Switches between the raw text and the preview.
  void _setPreview(bool value) {
    _suggest.dismiss();
    setState(() {
      _preview = value;
      _finding = false;
    });
  }

  /// Edit mode with the caret at [offset] (where it was when null).
  void _startEditing([int? offset]) {
    if (_readonly) return;
    final length = _text.text.length;
    final at = offset ?? (_text.selection.isValid ? _text.selection.extentOffset : length);
    _text.selection = TextSelection.collapsed(offset: at.clamp(0, length));
    _setPreview(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _replaceRange(SourceRange range, String expected, String replacement) {
    final text = _text.text;
    if (range.end > text.length || range.of(text) != expected) return;
    final next = text.replaceRange(range.start, range.end, replacement);
    final caret = _text.selection.isValid
        ? _text.selection.extentOffset.clamp(0, next.length)
        : next.length;
    _history.apply(
      TextEditingValue(text: next, selection: TextSelection.collapsed(offset: caret)),
    );
  }

  /// Attachments of this note (`.attachments.<id>/…`) load through the Notes
  /// API with the account's credentials. Remote URLs stay placeholders: the
  /// preview does not contact third-party hosts.
  // shortcut: no offline cache; an offline preview shows the placeholder.
  Future<List<int>> _loadAttachment(String path) async {
    final remoteId = _row.remoteId ?? widget.note.remoteId;
    if (remoteId == null) throw StateError('not_uploaded');
    final runtime = ref.read(runtimeProvider);
    final account = await runtime.database.account(widget.note.accountId);
    if (account == null) throw StateError('account_missing');
    return (await runtime.clientFor(account)).attachment(remoteId, path);
  }

  // ---- find ----

  void _findChanged() {
    final query = _find.text.toLowerCase();
    final text = _text.text.toLowerCase();
    final found = <int>[];
    if (query.isNotEmpty) {
      var at = text.indexOf(query);
      while (at >= 0) {
        found.add(at);
        at = text.indexOf(query, at + query.length);
      }
    }
    setState(() {
      _matches = found;
      _matchAt = -1;
    });
  }

  /// Selects the next match after the caret ([dir] 1) or the previous one
  /// before it (-1), wrapping around.
  void _findStep(int dir) {
    if (_find.text.isEmpty) return;
    if (_matches.isEmpty) {
      showOwnSnackBar(context, AppLocalizations.of(context)!.notFound);
      return;
    }
    final sel = _text.selection;
    final from = sel.isValid ? (dir > 0 ? sel.end : sel.start) : 0;
    int at;
    if (dir > 0) {
      at = _matches.indexWhere((m) => m >= from);
      if (at < 0) at = 0;
    } else {
      at = _matches.lastIndexWhere((m) => m < from);
      if (at < 0) at = _matches.length - 1;
    }
    _text.selection = TextSelection(
      baseOffset: _matches[at],
      extentOffset: _matches[at] + _find.text.length,
    );
    setState(() => _matchAt = at);
    _textFocus.requestFocus();
  }

  void _toggleFind() {
    if (_preview) return;
    setState(() {
      _finding = !_finding;
      if (!_finding) {
        _matches = const [];
        _matchAt = -1;
      }
    });
  }

  // ---- sync with the database ----

  void _takePulled(List<LocalNote> notes) {
    final note = notes.where((n) => n.id == widget.note.id).firstOrNull;
    if (note == null || !mounted) return;
    // A conflict or a permission change does not raise the revision.
    final shown = note.syncState != _row.syncState || note.readonly != _readonly;
    _row = note;
    if (note.revision > _revision) {
      _adopt(note);
    } else if (shown) {
      setState(() {});
    }
  }

  /// A sync changed the note while it is open: a version from another
  /// device, or that version combined with the text saved here. Whatever
  /// was typed since the last save is combined with it as well.
  void _adopt(LocalNote note) {
    String keep(String saved, String mine, String theirs) =>
        mine == saved ? theirs : mine;
    final title = keep(_saved.title, _title.text, note.title);
    final category = keep(_saved.category, _category.text, note.category);
    final old = _text.text;
    final content = mergeThreeWay(_saved.content, old, note.content);
    if (content == null) {
      // Both sides changed the same lines: nothing is combined silently.
      _conflict(note, title, category);
      return;
    }
    setState(() {
      _revision = note.revision;
      _saved = note;
      if (!_dirty) _favorite = note.favorite;
      if (_title.text != title) _title.text = title;
      if (_category.text != category) _category.text = category;
      if (old != content) {
        // The cursor stays at its text: shifted by what changed before it.
        var same = 0;
        while (same < old.length &&
            same < content.length &&
            old.codeUnitAt(same) == content.codeUnitAt(same)) {
          same++;
        }
        final at = _text.selection.extentOffset;
        _external = true;
        // Text from another device starts a new undo history: local undo
        // must not walk across it.
        _history.rebase(
          TextEditingValue(
            text: content,
            selection: TextSelection.collapsed(
              offset: at <= same
                  ? at
                  : (at + content.length - old.length).clamp(same, content.length),
            ),
          ),
        );
        _external = false;
      }
      _dirty =
          title != note.title ||
          content != note.content ||
          category != note.category ||
          _favorite != note.favorite;
    });
    if (_dirty) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), _save);
    }
  }

  /// Keeps the typed text as the local version and hands the overlap to the
  /// user's decision; nothing is uploaded over the server's change.
  void _conflict(LocalNote note, String title, String category) {
    _debounce?.cancel();
    final content = _text.text, favorite = _favorite;
    final db = ref.read(runtimeProvider).database;
    setState(() {
      _revision = note.revision;
      _saved = note;
      _title.text = title;
      _category.text = category;
    });
    _tail = _tail.then((_) async {
      try {
        _revision = await db.saveConflict(
          accountId: widget.note.accountId,
          id: widget.note.id,
          revision: note.revision,
          title: title,
          content: content,
          category: category,
          favorite: favorite,
        );
        if (mounted) {
          setState(() {
            _failed = false;
            _dirty = _text.text != content;
            _row = _row.copyWith(syncState: 'needsDecision');
          });
        }
      } catch (_) {
        if (mounted) _fail('local_write');
      }
    });
  }

  Future<void> _openRecovery() async {
    await _save();
    final fresh = await ref
        .read(runtimeProvider)
        .database
        .note(widget.note.accountId, widget.note.id);
    if (!mounted || fresh == null) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/recovery'),
        builder: (_) => RecoveryScreen(note: fresh),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _save();
    }
  }

  // ---- saving ----

  /// Local persistence failed: the editor stays open, the failure is listed
  /// under Needs attention until a save succeeds.
  void _fail(String reason) {
    setState(() {
      _failed = true;
      _failReason = reason;
    });
    ref
        .read(runtimeProvider)
        .attention
        .reportSaveFailure(widget.note.accountId, widget.note.id, reason);
  }

  void _clearFailure() {
    ref
        .read(runtimeProvider)
        .attention
        .clearSaveFailure(widget.note.accountId, widget.note.id);
  }

  Future<void> _save() {
    _debounce?.cancel();
    // A read-only note can still save its favorite star; its text fields
    // cannot change.
    if (!_dirty) return _tail;
    final title = _title.text, content = _text.text, category = _category.text;
    final favorite = _favorite;
    final db = ref.read(runtimeProvider).database;
    _tail = _tail.then((_) async {
      try {
        _revision = await db.saveDraft(
          accountId: widget.note.accountId,
          id: widget.note.id,
          revision: _revision,
          title: title,
          content: content,
          category: category,
          favorite: favorite,
        );
        _saved = _saved.copyWith(
          title: title,
          content: content,
          category: category,
          favorite: favorite,
          revision: _revision,
        );
        _clearFailure();
        if (mounted) {
          setState(() {
            _failed = false;
            _dirty =
                _title.text != title ||
                _text.text != content ||
                _category.text != category ||
                _favorite != favorite;
          });
        }
      } on StateError catch (e) {
        // A sync changed the note just now; combine and save again.
        final note = e.message == 'local_revision_changed'
            ? await db.note(widget.note.accountId, widget.note.id)
            : null;
        if (!mounted) return;
        if (note != null && note.revision > _revision) {
          _adopt(note);
        } else {
          _fail(e.message);
        }
      } catch (_) {
        if (mounted) _fail('local_write');
      }
    });
    return _tail;
  }

  Future<void> _retrySave() {
    setState(() => _dirty = true);
    return _save();
  }

  Future<void> _leave() async {
    await _save();
    // A sync may have combined a version from another device meanwhile.
    if (_dirty && !_failed) await _save();
    if (!mounted || _failed || _dirty) return;
    // A new note left empty would reach the server as "New note".
    if (widget.note.remoteId == null &&
        _title.text.trim().isEmpty &&
        _text.text.trim().isEmpty &&
        _category.text.trim().isEmpty) {
      try {
        await ref
            .read(runtimeProvider)
            .database
            .markDeleted(widget.note.accountId, widget.note.id);
      } catch (_) {
        // Already sending; it stays like any other note.
      }
      if (!mounted) return;
    }
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.deleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _debounce?.cancel();
    _dirty = false;
    await _tail;
    try {
      await ref
          .read(runtimeProvider)
          .database
          .markDeleted(widget.note.accountId, widget.note.id);
    } catch (_) {
      if (mounted) _fail('local_write');
      return;
    }
    if (!mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulled?.cancel();
    _live?.cancel();
    _debounce?.cancel();
    _text.removeListener(_textChanged);
    _history.dispose();
    _suggest.dispose();
    _sourceFuture?.then((s) => s?.close());
    _title.dispose();
    _text.dispose();
    _category.dispose();
    _find.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  // ---- surfaces ----

  Future<void> _openShare() async {
    _suggest.dismiss();
    await showShareSheet(
      context,
      note: _row,
      title: _title.text,
      text: () => _text.text,
      flush: _save,
      hasAttachments: _text.document.attachments.isNotEmpty,
    );
  }

  Future<void> _openDetails([_Details focus = _Details.title]) {
    final l = AppLocalizations.of(context)!;
    return showOwnSheet<void>(
      context: context,
      title: l.openDetails,
      fullScreen: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _title,
              readOnly: _readonly,
              autofocus: focus == _Details.title && !_readonly,
              textInputAction: TextInputAction.next,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(
                labelText: l.title,
                prefixIcon: const Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _category,
              readOnly: _readonly,
              autofocus: focus == _Details.category && !_readonly,
              onChanged: (_) => _changed(),
              decoration: InputDecoration(
                labelText: l.category,
                prefixIcon: const Icon(Icons.folder_outlined),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              secondary: Icon(_favorite ? Icons.star : Icons.star_border),
              title: Text(l.favorite),
              value: _favorite,
              onChanged: (v) {
                setSheet(() => _favorite = v);
                _changed();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAttachments() {
    final l = AppLocalizations.of(context)!;
    return showOwnSheet<void>(
      context: context,
      title: l.attachments,
      builder: (_) => AttachmentsList(document: _text.document),
    );
  }

  Future<void> _openChecklist() async {
    _suggest.dismiss();
    _textFocus.unfocus();
    int? edit;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/checklist'),
        builder: (routeContext) => ChecklistScreen(
          text: _text,
          history: _history,
          title: _title.text,
          readonly: _readonly,
          onChanged: _changed,
          onEditAt: (offset) {
            edit = offset;
            Navigator.of(routeContext).pop();
          },
        ),
      ),
    );
    final at = edit;
    if (at != null && mounted) _startEditing(at);
  }

  Future<void> _export() => ref.read(copySenderProvider)(
    title: _title.text,
    text: _text.text,
    asFile: true,
  );

  void _onOverflow(_Overflow item) {
    switch (item) {
      case _Overflow.details:
        _openDetails();
      case _Overflow.favorite:
        _favorite = !_favorite;
        _changed();
      case _Overflow.find:
        _toggleFind();
      case _Overflow.checklist:
        _openChecklist();
      case _Overflow.attachments:
        _openAttachments();
      case _Overflow.history:
        _openRecovery();
      case _Overflow.export:
        _export();
      case _Overflow.delete:
        _delete();
    }
  }

  // ---- build ----

  PopupMenuItem<_Overflow> _menuItem(
    _Overflow value,
    IconData icon,
    String label, {
    bool enabled = true,
    Color? color,
  }) => PopupMenuItem(
    value: value,
    enabled: enabled,
    child: Row(
      children: [
        Icon(icon, color: enabled ? color : null),
        const SizedBox(width: 16),
        Flexible(child: Text(label, style: TextStyle(color: enabled ? color : null))),
      ],
    ),
  );

  List<Widget> _actions(AppLocalizations l) {
    if (_finding) {
      return [
        if (_find.text.isNotEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _matches.isEmpty
                    ? '0'
                    : l.findCount(_matchAt < 0 ? 0 : _matchAt + 1, _matches.length),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        IconButton(
          tooltip: l.findPrevious,
          onPressed: () => _findStep(-1),
          icon: const Icon(Icons.arrow_upward),
        ),
        IconButton(
          tooltip: l.findNext,
          onPressed: () => _findStep(1),
          icon: const Icon(Icons.arrow_downward),
        ),
        IconButton(
          tooltip: l.cancel,
          onPressed: _toggleFind,
          icon: const Icon(Icons.close),
        ),
      ];
    }
    final error = context.own.error;
    return [
      IconButton(
        tooltip: _preview ? l.edit : l.preview,
        onPressed: () => _setPreview(!_preview),
        icon: Icon(_preview ? Icons.edit_outlined : Icons.visibility_outlined),
      ),
      IconButton(
        tooltip: l.shareTitle,
        onPressed: _openShare,
        icon: Icon(
          defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS
              ? Icons.ios_share
              : Icons.share_outlined,
        ),
      ),
      PopupMenuButton<_Overflow>(
        tooltip: l.moreOptions,
        onSelected: _onOverflow,
        itemBuilder: (_) => [
          _menuItem(_Overflow.details, Icons.info_outline, l.openDetails),
          _menuItem(
            _Overflow.favorite,
            _favorite ? Icons.star : Icons.star_border,
            _favorite ? l.unfavorite : l.favorite,
          ),
          _menuItem(_Overflow.find, Icons.search, l.findInNote, enabled: !_preview),
          _menuItem(_Overflow.checklist, Icons.checklist, l.openChecklist),
          _menuItem(_Overflow.attachments, Icons.attach_file, l.attachments),
          _menuItem(_Overflow.history, Icons.history, l.historyRecovery),
          _menuItem(_Overflow.export, Icons.file_download_outlined, l.exportNote),
          _menuItem(
            _Overflow.delete,
            Icons.delete_outline,
            l.delete,
            enabled: !_readonly,
            color: error,
          ),
        ],
      ),
    ];
  }

  Widget _appBarTitle(AppLocalizations l) {
    if (_finding) {
      return TextField(
        controller: _find,
        autofocus: true,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(hintText: l.findInNote, border: InputBorder.none),
        onChanged: (_) => _findChanged(),
        onSubmitted: (_) => _findStep(1),
      );
    }
    return ListenableBuilder(
      listenable: _title,
      builder: (context, _) => Text(
        _title.text.trim().isEmpty ? l.untitled : _title.text.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _banners(AppLocalizations l) {
    return Column(
      children: [
        if (_row.syncState == 'needsDecision')
          OwnBanner(
            tone: OwnTone.decision,
            message: l.decisionRequired,
            actions: [OwnButton.text(label: l.resolve, onPressed: _openRecovery)],
          ),
        if (_readonly)
          OwnBanner(tone: OwnTone.info, icon: Icons.lock_outline, message: l.readonly),
        if (_failed)
          OwnBanner(
            tone: OwnTone.error,
            title: l.saveFailedTitle,
            message: _failReason == 'note_unreadable' ? l.noteUnreadable : l.saveFailed,
            actions: [
              OwnButton.text(label: l.retry, icon: Icons.refresh, onPressed: _retrySave),
              OwnButton.text(
                label: l.copyMarkdown,
                icon: Icons.copy,
                onPressed: () => Clipboard.setData(ClipboardData(text: _text.text)),
              ),
              OwnButton.text(
                label: l.exportDraft,
                icon: Icons.file_download_outlined,
                onPressed: _export,
              ),
            ],
          ),
      ],
    );
  }

  static SingleActivator _primary(LogicalKeyboardKey key, {bool shift = false}) {
    final apple =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    return SingleActivator(key, control: !apple, meta: apple, shift: shift);
  }

  Widget _sourceField(AppLocalizations l, AppSettings settings) {
    final style = LiveMarkdownMetrics.onGrid(
      settings.monospace
          ? monoTextStyle().copyWith(fontSize: settings.fontSize)
          : TextStyle(fontSize: settings.fontSize),
    );
    return Actions(
      actions: {
        UndoTextIntent: CallbackAction<UndoTextIntent>(
          onInvoke: (_) {
            _history.undo();
            return null;
          },
        ),
        RedoTextIntent: CallbackAction<RedoTextIntent>(
          onInvoke: (_) {
            _history.redo();
            return null;
          },
        ),
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: OwnShape.editorMeasure),
            child: TextField(
              key: _fieldKey,
              controller: _text,
              focusNode: _textFocus,
              readOnly: _readonly,
              expands: true,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              inputFormatters: const [ListContinuationFormatter()],
              style: style,
              strutStyle: LiveMarkdownMetrics.strut(settings.fontSize),
              decoration: InputDecoration(
                hintText: l.content,
                filled: false,
                isCollapsed: false,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    _text.monospace = settings.monospace;
    final narrow = MediaQuery.sizeOf(context).width < 600;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // Back closes the innermost layer first.
        if (_suggest.isOpen) {
          _suggest.dismiss();
        } else if (_finding) {
          _toggleFind();
        } else {
          _leave();
        }
      },
      child: CallbackShortcuts(
        bindings: {
          _primary(LogicalKeyboardKey.keyB): () => _runCommand(EditorCommand.bold),
          _primary(LogicalKeyboardKey.keyI): () => _runCommand(EditorCommand.italic),
          _primary(LogicalKeyboardKey.keyK): () => _runCommand(EditorCommand.link),
          _primary(LogicalKeyboardKey.keyS): _save,
          _primary(LogicalKeyboardKey.keyF): _toggleFind,
          _primary(LogicalKeyboardKey.keyP, shift: true): () => _setPreview(!_preview),
          const SingleActivator(LogicalKeyboardKey.keyY, control: true): _history.redo,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_finding) _toggleFind();
          },
        },
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            // A pane next to the list has nothing to go back to.
            leading: (ModalRoute.of(context)?.canPop ?? false)
                ? BackButton(onPressed: _leave)
                : null,
            title: _appBarTitle(l),
            actions: _actions(l),
          ),
          floatingActionButton: _preview && !_readonly && narrow
              ? FloatingActionButton(
                  tooltip: l.editNote,
                  onPressed: _startEditing,
                  child: const Icon(Icons.edit),
                )
              : null,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Header and routine status give way to the text when the
                // keyboard is up or the window is short. The widgets stay in
                // the tree (keyed), so focus, selection and composition
                // survive the change.
                final lowSpace = keyboardOpen || constraints.maxHeight < 360;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    KeyedSubtree(key: const ValueKey('banners'), child: _banners(l)),
                    KeyedSubtree(
                      key: const ValueKey('header'),
                      child: ListenableBuilder(
                        listenable: Listenable.merge([_title, _category]),
                        builder: (context, _) => DocumentHeader(
                          title: _title.text.trim(),
                          category: _category.text,
                          favorite: _favorite,
                          collapsed: lowSpace && !_preview,
                          onTitle: () => _openDetails(_Details.title),
                          onCategory: () => _openDetails(_Details.category),
                        ),
                      ),
                    ),
                    Expanded(
                      key: const ValueKey('body'),
                      child: Stack(
                        key: _bodyKey,
                        fit: StackFit.expand,
                        children: [
                          Positioned.fill(
                            child: _preview
                                ? MarkdownPreview(
                                    text: _text.text,
                                    readonly: _readonly,
                                    onEditAt: _startEditing,
                                    onReplaceRange: _replaceRange,
                                    loadAttachment: (_row.remoteId ?? widget.note.remoteId) == null
                                        ? null
                                        : _loadAttachment,
                                  )
                                : _sourceField(l, settings),
                          ),
                          _popup(),
                        ],
                      ),
                    ),
                    if (keyboardOpen && !_failed)
                      const SizedBox.shrink(key: ValueKey('status'))
                    else
                      Padding(
                        key: const ValueKey('status'),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _failed
                                ? l.saveFailedTitle
                                : _dirty
                                ? l.saving
                                : l.saved,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: _failed ? context.own.error : context.own.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    if (!_preview && !_readonly)
                      KeyedSubtree(
                        key: const ValueKey('dock'),
                        child: FormattingDock(
                          history: _history,
                          onCommand: _runCommand,
                          onAttach: widget.onAttach,
                        ),
                      )
                    else
                      const SizedBox.shrink(key: ValueKey('dock')),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
