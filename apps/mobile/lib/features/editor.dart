import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';

class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({required this.note, super.key});
  final LocalNote note;
  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _title;
  late final TextEditingController _text;
  late final TextEditingController _category;
  late int _revision;
  late bool _favorite;
  Timer? _debounce;
  Future<void> _tail = Future<void>.value();
  bool _dirty = false;
  bool _failed = false;
  bool _preview = false;
  bool _allowPop = false;
  final _images = <String, Future<List<int>>>{};

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
    _text = TextEditingController(text: widget.note.content);
    _category = TextEditingController(text: widget.note.category);
    _revision = widget.note.revision;
    _favorite = widget.note.favorite;
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
    if (!_dirty || widget.note.readonly) return _tail;
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
      } catch (_) {
        if (mounted) setState(() => _failed = true);
      }
    });
    return _tail;
  }

  Future<void> _leave() async {
    await _save();
    if (!mounted || _failed || _dirty) return;
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
    _debounce?.cancel();
    _title.dispose();
    _text.dispose();
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.appTitle),
          actions: [
            IconButton(
              tooltip: _preview ? l.edit : l.preview,
              onPressed: () => setState(() => _preview = !_preview),
              icon: Icon(
                _preview ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
            ),
            IconButton(
              tooltip: l.save,
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
            ),
            if (!widget.note.readonly)
              IconButton(
                tooltip: l.delete,
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SafeArea(
          // A phone on its side with the keyboard up leaves too little height
          // for a fixed layout; the editor then scrolls as a whole.
          child: LayoutBuilder(
            builder: (context, constraints) =>
                _body(l, compact: constraints.maxHeight < 400),
          ),
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l, {required bool compact}) {
    final image = Semantics(
      label: l.imageUnavailable,
      child: const Icon(Icons.image_not_supported_outlined),
    );
    final Widget text = _preview
        ? (compact
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                    data: _text.text,
                    selectable: true,
                    sizedImageBuilder: (c) => _image(c, image),
                  ),
                )
              : Markdown(
                  data: _text.text,
                  selectable: true,
                  sizedImageBuilder: (c) => _image(c, image),
                ))
        : Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _text,
              readOnly: widget.note.readonly,
              expands: !compact,
              minLines: compact ? 6 : null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                hintText: l.content,
                border: InputBorder.none,
              ),
              onChanged: (_) => _changed(),
            ),
          );
    final children = [
      if (widget.note.syncState == 'needsDecision')
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.decisionRequired),
        ),
      if (widget.note.readonly) Text(l.readonly),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _title,
                readOnly: widget.note.readonly,
                decoration: InputDecoration(labelText: l.title),
                onChanged: (_) => _changed(),
              ),
            ),
            IconButton(
              tooltip: l.favorite,
              onPressed: widget.note.readonly
                  ? null
                  : () {
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
          readOnly: widget.note.readonly,
          decoration: InputDecoration(labelText: l.category),
          onChanged: (_) => _changed(),
        ),
      ),
      compact ? text : Expanded(child: text),
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
