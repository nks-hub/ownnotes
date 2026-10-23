part of '../editor.dart';

extension _EditorView on _EditorScreenState {
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
        Flexible(
          child: Text(label, style: TextStyle(color: enabled ? color : null)),
        ),
      ],
    ),
  );

  List<Widget> _actions(AppLocalizations l) {
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
          _menuItem(
            _Overflow.find,
            Icons.search,
            l.findInNote,
            enabled: !_preview,
          ),
          _menuItem(_Overflow.checklist, Icons.checklist, l.openChecklist),
          _menuItem(_Overflow.attachments, Icons.attach_file, l.attachments),
          _menuItem(_Overflow.history, Icons.history, l.historyRecovery),
          _menuItem(
            _Overflow.export,
            Icons.file_download_outlined,
            l.exportNote,
          ),
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
            actions: [
              OwnButton.text(label: l.resolve, onPressed: _openRecovery),
            ],
          ),
        if (_readonly)
          OwnBanner(
            tone: OwnTone.info,
            icon: Icons.lock_outline,
            message: l.readonly,
          ),
        if (_failed)
          OwnBanner(
            tone: OwnTone.error,
            title: l.saveFailedTitle,
            message: _failReason == 'note_unreadable'
                ? l.noteUnreadable
                : l.saveFailed,
            actions: [
              OwnButton.text(
                label: l.retry,
                icon: Icons.refresh,
                onPressed: _retrySave,
              ),
              OwnButton.text(
                label: l.copyMarkdown,
                icon: Icons.copy,
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: _text.text)),
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

  static SingleActivator _primary(
    LogicalKeyboardKey key, {
    bool shift = false,
  }) {
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

  Widget _buildEditor(BuildContext context) {
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
          _primary(LogicalKeyboardKey.keyB): () =>
              _runCommand(EditorCommand.bold),
          _primary(LogicalKeyboardKey.keyI): () =>
              _runCommand(EditorCommand.italic),
          _primary(LogicalKeyboardKey.keyK): () =>
              _runCommand(EditorCommand.link),
          _primary(LogicalKeyboardKey.keyS): _save,
          _primary(LogicalKeyboardKey.keyF): _toggleFind,
          _primary(LogicalKeyboardKey.keyP, shift: true): () =>
              _setPreview(!_preview),
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              _history.redo,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (_finding) _toggleFind();
          },
        },
        child: Scaffold(
          appBar: _finding
              ? NoteFindBar(
                  source: _text,
                  query: _find,
                  sourceFocus: _textFocus,
                  onClose: _toggleFind,
                  leading: (ModalRoute.of(context)?.canPop ?? false)
                      ? BackButton(onPressed: _leave)
                      : null,
                )
              : AppBar(
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
                    KeyedSubtree(
                      key: const ValueKey('banners'),
                      child: _banners(l),
                    ),
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
                                    loadAttachment:
                                        (_row.remoteId ??
                                                widget.note.remoteId) ==
                                            null
                                        ? null
                                        : (path) async => (await ref.read(
                                            attachmentServiceProvider.future,
                                          )).load(_row, path),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _failed
                                ? l.saveFailedTitle
                                : _dirty
                                ? l.saving
                                : l.saved,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: _failed
                                      ? context.own.error
                                      : context.own.textSecondary,
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
                          onAttach: widget.onAttach == null ? null : _attach,
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
