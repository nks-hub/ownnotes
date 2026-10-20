import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/markdown/live_controller.dart';
import '../core/markdown/live_styling.dart';
import '../core/markdown/markdown_document.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';
import 'recovery.dart';

export '../core/markdown/live_controller.dart' show MarkdownTextController;

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

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({required this.note, super.key});
  final LocalNote note;
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final MarkdownTextController _text;

  /// The note's current database row; the widget's copy is the one opened.
  late LocalNote _row;
  bool get _readonly => _row.readonly;
  late final TextEditingController _category;
  late int _revision;
  late bool _favorite;
  Timer? _debounce;
  Future<void> _tail = Future<void>.value();
  bool _dirty = false;
  bool _failed = false;
  bool _preview = false;
  bool _tapConsumed = false;
  Offset? _down;
  Duration? _downAt;
  bool _finding = false;
  final _find = TextEditingController();
  final _textFocus = FocusNode();

  /// Selects the next match after the cursor, wrapping to the start.
  void _findNext() {
    final query = _find.text.toLowerCase();
    if (query.isEmpty) return;
    final text = _text.text.toLowerCase();
    var at = text.indexOf(query, _text.selection.end.clamp(0, text.length));
    if (at < 0) at = text.indexOf(query);
    if (at < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.notFound)),
      );
      return;
    }
    _text.selection = TextSelection(
      baseOffset: at,
      extentOffset: at + query.length,
    );
    _textFocus.requestFocus();
  }

  bool _allowPop = false;
  final _images = <String, Future<List<int>>>{};
  int _boxes = 0;

  /// Switches between the raw text and the preview.
  void _setPreview(bool value) {
    setState(() {
      _preview = value;
      _finding = false;
    });
  }

  /// Edit mode with the caret at [offset] (the end when null).
  void _startEditing([int? offset]) {
    if (_readonly) return;
    _text.selection = TextSelection.collapsed(
      offset: (offset ?? _text.text.length).clamp(0, _text.text.length),
    );
    _setPreview(false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFocus.requestFocus();
    });
  }

  void _pointerUp(PointerUpEvent e) {
    final down = _down, at = _downAt;
    _down = null;
    // A drag scrolls and a long press selects; only a short tap edits.
    if (down == null ||
        at == null ||
        !_preview ||
        _readonly ||
        (e.position - down).distance > kTouchSlop ||
        e.timeStamp - at > kLongPressTimeout) {
      return;
    }
    // Links and checkboxes claim the tap after this event is dispatched.
    scheduleMicrotask(() {
      if (!_tapConsumed && mounted && _preview) _editAt(e.position, e.viewId);
    });
  }

  void _editAt(Offset global, int viewId) {
    final hit = HitTestResult();
    WidgetsBinding.instance.hitTestInView(hit, global, viewId);
    for (final entry in hit.path) {
      final target = entry.target;
      final (String, int)? found = switch (target) {
        RenderParagraph() => (
          target.text.toPlainText(),
          target.getPositionForOffset(target.globalToLocal(global)).offset,
        ),
        RenderEditable(:final text?) => (
          text.toPlainText(),
          target.getPositionForPoint(global).offset,
        ),
        _ => null,
      };
      if (found == null) continue;
      final (plain, at) = found;
      final word = RegExp(r'[\p{L}\p{N}]+', unicode: true)
          .allMatches(plain)
          .where((m) => m.end >= at && m.start <= at)
          .firstOrNull;
      _startEditing(
        sourceOffsetFor(
          _text.text,
          word?.group(0) ?? '',
          plain.substring(word?.start ?? at.clamp(0, plain.length)),
        ),
      );
      return;
    }
  }

  /// Replaces the selection with [left] + selection + [right].
  void _wrap(String left, String right) {
    final text = _text.text;
    final sel = _text.selection;
    final a = sel.isValid ? sel.start : text.length;
    final b = sel.isValid ? sel.end : text.length;
    _text.value = TextEditingValue(
      text: text.replaceRange(a, b, '$left${text.substring(a, b)}$right'),
      selection: TextSelection(
        baseOffset: a + left.length,
        extentOffset: b + left.length,
      ),
    );
    _changed();
    _textFocus.requestFocus();
  }

  /// Puts [marker] at the start of the line holding the caret.
  void _prefix(String marker) {
    final text = _text.text;
    final caret = _text.selection.isValid ? _text.selection.start : text.length;
    final start = caret == 0 ? 0 : text.lastIndexOf('\n', caret - 1) + 1;
    // A second tap on the heading button makes it one level deeper.
    final deeper = marker == '# ' && text.startsWith('#', start);
    final added = deeper ? '#' : marker;
    _text.value = TextEditingValue(
      text: text.replaceRange(start, start, added),
      selection: TextSelection.collapsed(offset: caret + added.length),
    );
    _changed();
    _textFocus.requestFocus();
  }

  Widget _toolbar(AppLocalizations l) {
    Widget button(String tip, IconData icon, VoidCallback onTap) =>
        IconButton(tooltip: tip, onPressed: onTap, icon: Icon(icon));
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            button(l.fmtBold, Icons.format_bold, () => _wrap('**', '**')),
            button(l.fmtItalic, Icons.format_italic, () => _wrap('*', '*')),
            button(l.fmtHeading, Icons.title, () => _prefix('# ')),
            button(l.fmtList, Icons.format_list_bulleted, () => _prefix('- ')),
            button(l.fmtChecklist, Icons.checklist, () => _prefix('- [ ] ')),
            button(l.fmtLink, Icons.link, () => _wrap('[', '](https://)')),
          ],
        ),
      ),
    );
  }

  /// The preview builds checkboxes in document order, so the n-th one is the
  /// n-th task item in the raw text. A tick edits that one character.
  Widget _checkbox(bool value) {
    final index = _boxes++;
    // Shrunk to the text line, otherwise the 48 px tap target sits below it.
    return Checkbox(
      value: value,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      onChanged: _readonly
          ? null
          : (_) {
              _tapConsumed = true;
              final doc = MarkdownDocument.parse(_text.text);
              final task = doc.renderedTasks().elementAtOrNull(index);
              final next = task == null ? null : doc.toggled(_text.text, task);
              if (next == null) return;
              _text.text = next;
              _changed();
            },
    );
  }

  /// Attachments of this note (`.attachments.<id>/…`) load through the Notes
  /// API with the account's credentials. Remote URLs stay placeholders: the
  /// preview does not contact third-party hosts.
  // shortcut: no offline cache; an offline preview shows the placeholder.
  Widget _image(MarkdownImageConfig config, Widget placeholder) {
    final remoteId = widget.note.remoteId;
    if (remoteId == null || config.uri.hasScheme) return placeholder;
    final path = Uri.decodeFull(config.uri.toString());
    final bytes = _images.putIfAbsent(path, () async {
      final runtime = ref.read(runtimeProvider);
      final account = await runtime.database.account(widget.note.accountId);
      if (account == null) throw StateError('account_missing');
      return (await runtime.clientFor(account)).attachment(remoteId, path);
    });
    return FutureBuilder<List<int>>(
      future: bytes,
      builder: (context, snapshot) => switch (snapshot) {
        AsyncSnapshot(hasData: true, :final data?) => Image.memory(
          Uint8List.fromList(data),
          width: config.width,
          height: config.height,
          semanticLabel: config.alt,
          errorBuilder: (_, _, _) => placeholder,
        ),
        AsyncSnapshot(hasError: true) => placeholder,
        _ => const SizedBox.square(
          dimension: 48,
          child: Center(child: CircularProgressIndicator()),
        ),
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _title = TextEditingController(text: widget.note.title);
    _text = MarkdownTextController(text: widget.note.content);
    _category = TextEditingController(text: widget.note.category);
    _revision = widget.note.revision;
    _favorite = widget.note.favorite;
    _saved = widget.note;
    _row = widget.note;
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
  }

  StreamSubscription<List<LocalNote>>? _pulled;
  Timer? _live;

  /// The note as last saved here or taken from the database.
  late LocalNote _saved;

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
        _text.value = TextEditingValue(
          text: content,
          selection: TextSelection.collapsed(
            offset: at <= same
                ? at
                : (at + content.length - old.length).clamp(
                    same,
                    content.length,
                  ),
          ),
        );
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
        if (mounted) setState(() => _failed = true);
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

  void _changed() {
    setState(() {
      _dirty = true;
      _failed = false;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _save);
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
          setState(() => _failed = true);
        }
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
    });
    return _tail;
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
      if (mounted) setState(() => _failed = true);
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
    _title.dispose();
    _text.dispose();
    _category.dispose();
    _find.dispose();
    _textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _finding
              ? TextField(
                  controller: _find,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.findInNote,
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _findNext(),
                )
              : Text(l.appTitle),
          actions: [
            if (_finding)
              IconButton(
                tooltip: l.findNext,
                onPressed: _findNext,
                icon: const Icon(Icons.arrow_downward),
              ),
            if (!_preview)
              IconButton(
                tooltip: _finding ? l.cancel : l.findInNote,
                onPressed: () => setState(() => _finding = !_finding),
                icon: Icon(_finding ? Icons.close : Icons.search),
              ),
            IconButton(
              tooltip: _preview ? l.edit : l.preview,
              onPressed: () => _setPreview(!_preview),
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
            ),
            IconButton(
              tooltip: l.save,
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
            if (!_readonly)
              IconButton(
                tooltip: l.delete,
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        floatingActionButton:
            _preview &&
                !_readonly &&
                MediaQuery.sizeOf(context).width < 600
            ? FloatingActionButton(
                tooltip: l.editNote,
                onPressed: _startEditing,
                child: const Icon(Icons.edit),
              )
            : null,
        body: SafeArea(
          // A phone on its side leaves too little height for a fixed layout;
          // the editor then scrolls as a whole. The keyboard does not count:
          // switching layout when it opens rebuilds the focused field, which
          // closes the keyboard again (seen on Galaxy S21 in portrait).
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _body(l, compact: constraints.maxHeight + keyboard < 400),
          ),
        ),
      ),
    );
  }

  void _openLink(String text, String? href, String title) {
    _tapConsumed = true;
    final uri = href == null ? null : Uri.tryParse(href);
    if (uri == null || !{'http', 'https', 'mailto'}.contains(uri.scheme)) {
      return;
    }
    launchUrl(uri, mode: LaunchMode.externalApplication).ignore();
  }

  Widget _body(AppLocalizations l, {required bool compact}) {
    final settings = ref.watch(settingsProvider);
    final image = Semantics(
      label: l.imageUnavailable,
      child: const Icon(Icons.image_not_supported_outlined),
    );
    _boxes = 0;
    _text.monospace = settings.monospace;
    final Widget text = _preview
        ? Listener(
            onPointerDown: (e) {
              _down = e.position;
              _downAt = e.timeStamp;
              _tapConsumed = false;
            },
            onPointerUp: _pointerUp,
            onPointerCancel: (_) => _down = null,
            child: compact
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                    data: _text.text,
                    selectable: true,
                    sizedImageBuilder: (c) => _image(c, image),
                    checkboxBuilder: _checkbox,
                    onTapLink: _openLink,
                  ),
                )
              : Markdown(
                  data: _text.text,
                  selectable: true,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  sizedImageBuilder: (c) => _image(c, image),
                  checkboxBuilder: _checkbox,
                  onTapLink: _openLink,
                ),
          )
        : Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _text,
              focusNode: _textFocus,
              readOnly: _readonly,
              expands: !compact,
              minLines: compact ? 6 : null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              style: LiveMarkdownMetrics.onGrid(
                settings.monospace
                    ? monoTextStyle().copyWith(fontSize: settings.fontSize)
                    : TextStyle(fontSize: settings.fontSize),
              ),
              strutStyle: LiveMarkdownMetrics.strut(settings.fontSize),
              decoration: InputDecoration(
                hintText: l.content,
                border: InputBorder.none,
              ),
              onChanged: (_) => _changed(),
            ),
          );
    final children = [
      if (_row.syncState == 'needsDecision')
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Text(l.decisionRequired),
              TextButton(onPressed: _openRecovery, child: Text(l.resolve)),
            ],
          ),
        ),
      if (_readonly) Text(l.readonly),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _title,
                readOnly: _readonly,
                decoration: InputDecoration(labelText: l.title),
                onChanged: (_) => _changed(),
              ),
            ),
            IconButton(
              tooltip: l.favorite,
              onPressed: () {
                _favorite = !_favorite;
                _changed();
              },
              icon: Icon(_favorite ? Icons.star : Icons.star_border),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _category,
          readOnly: _readonly,
          decoration: InputDecoration(labelText: l.category),
          onChanged: (_) => _changed(),
        ),
      ),
      compact ? text : Expanded(child: text),
      // A phone on its side has no height to spare for it.
      if (!compact && !_preview && !_readonly) _toolbar(l),
      Padding(
        padding: const EdgeInsets.all(8),
        child: Semantics(
          liveRegion: true,
          child: Text(
            _failed
                ? l.saveFailed
                : _dirty
                ? l.saving
                : l.saved,
            style: _failed
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ),
    ];
    return compact ? ListView(children: children) : Column(children: children);
  }
}
