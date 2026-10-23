part of '../home.dart';

extension _NotebookView on _HomeScreenState {
  Widget _noAccount(AppLocalizations l) => Scaffold(
    appBar: AppBar(
      title: Text(l.appTitle),
      actions: [
        IconButton(
          tooltip: l.addAccount,
          onPressed: _addAccount,
          icon: const Icon(Icons.person_add_outlined),
        ),
      ],
    ),
    body: OwnStateView(
      icon: Icons.cloud_outlined,
      title: l.noAccounts,
      actions: [
        OwnButton.primary(
          label: l.connectNextcloud,
          icon: Icons.login,
          onPressed: _addAccount,
        ),
        OwnButton.secondary(
          label: l.scanLoginQr,
          icon: Icons.qr_code_scanner,
          onPressed: _addAccount,
        ),
      ],
    ),
  );

  Widget _screen(
    Account account,
    List<Account> accounts,
    bool locked,
    AppLocalizations l,
  ) {
    final notesAsync = ref.watch(notesProvider(account.id));
    final notes = notesAsync.valueOrNull;
    final status = ref.watch(syncStatusProvider(account.id)).valueOrNull;
    final attention =
        ref.watch(attentionProvider(account.id)).valueOrNull ?? const [];
    final index = notes == null
        ? null
        : _indexFor(account.id, notes, locked, l);
    final media = MediaQuery.of(context);
    final fold = verticalFold(media);
    final tabletop = fold == null ? tabletopFold(media) : null;
    _layout = notebookLayout(
      media.size.width,
      media.textScaler.scale(16) / 16,
      fold: fold != null || tabletop != null,
    );
    var scope = _scope;
    if (index != null &&
        scope == NoteScope.category &&
        _viewId == null &&
        !index.paths.contains(_category)) {
      scope = NoteScope.all;
    }
    final rows = index == null
        ? const <NoteRow>[]
        : _visibleRows(index, scope, l);
    final selecting = _selected.isNotEmpty;
    final inlineNav = _layout == NotebookLayout.threePane;

    final panel = index == null
        ? null
        : CategoryPanel(
            tree: index.tree,
            total: index.rows.length,
            favorites: index.favorites,
            uncategorised: index.uncategorised,
            shared: index.shared,
            attention: attention.length,
            scope: scope,
            category: _category,
            expanded: _expanded,
            savedViews: _views,
            activeViewId: _viewId,
            subtree: _subtree,
            onSubtree: _setSubtree,
            onSelect: (s, c) => _go(s, category: c),
            onToggle: _toggleExpanded,
            onSelectView: (v) => _go(
              v.scope,
              category: v.category,
              viewId: v.id,
              filters: v.filters,
              query: v.query,
            ),
            onDeleteView: _deleteView,
            onSettings: () {
              _scaffold.currentState?.closeDrawer();
              _openSettings(account);
            },
          );

    final content = _content(
      account,
      index,
      notesAsync,
      rows,
      scope,
      attention,
      status,
      l,
    );
    final list = Column(
      children: [
        if (status != null && !(_searching && media.viewInsets.bottom > 0))
          NotebookStatusArea(
            status: status,
            reauthRequired: account.state == 'reauthRequired',
            saveFailures: attention
                .where((a) => a.kind == AttentionKind.saveFailure)
                .length,
            syncing: _busy,
            showChecking: _checking,
            downloaded: index?.rows.length ?? 0,
            attentionShown: scope == NoteScope.attention,
            onSyncNow: () => _sync(account.id),
            onSignIn: () => _reauthenticate(account),
            onOpenAttention: () => _go(NoteScope.attention),
          ),
        if (_searching)
          FilterRow(
            filters: _filters,
            onChanged: _setFilters,
            scopeLabel: scope == NoteScope.all || _viewId != null
                ? null
                : _scopeTitle(scope, l),
            onClearScope: () => _go(NoteScope.all),
          ),
        if (selecting) _bulkNotice(l),
        Expanded(child: content),
      ],
    );

    final Widget body;
    if (_layout == NotebookLayout.phone) {
      body = _pane.isOpen
          ? EditorPane(controller: _pane)
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: list,
              ),
            );
    } else if (tabletop != null && !inlineNav) {
      body = FoldSplit(
        fold: tabletop,
        top: EditorPane(controller: _pane),
        bottom: list,
      );
    } else if (fold != null && !inlineNav) {
      // Nothing crosses the fold: the list ends where it starts, the editor
      // begins where it ends (a hinge has width, a flat fold has none).
      body = Row(
        children: [
          SizedBox(width: fold.left, child: list),
          if (fold.width > 0)
            SizedBox(width: fold.width)
          else
            const VerticalDivider(width: 1),
          Expanded(child: EditorPane(controller: _pane)),
        ],
      );
    } else {
      body = Row(
        children: [
          if (inlineNav && panel != null) ...[
            SizedBox(width: navigationPaneWidth, child: panel),
            const VerticalDivider(width: 1),
          ],
          SizedBox(width: listWidthFor(media.size.width), child: list),
          const VerticalDivider(width: 1),
          Expanded(child: EditorPane(controller: _pane)),
        ],
      );
    }
    final editorOnly = _layout == NotebookLayout.phone && _pane.isOpen;
    // Where the list pane ends when the editor sits beside it.
    final double? listEnd = switch (_layout) {
      NotebookLayout.phone => null,
      _ when tabletop != null && !inlineNav => null,
      _ when fold != null && !inlineNav => fold.left,
      _ =>
        (inlineNav ? navigationPaneWidth + 1 : 0) +
            listWidthFor(media.size.width),
    };

    final primary =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    SingleActivator key(LogicalKeyboardKey k, {bool shift = false}) =>
        SingleActivator(k, control: !primary, meta: primary, shift: shift);
    return PopScope(
      canPop: !_searching && !selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || _pane.isOpen) return;
        _escape();
      },
      child: CallbackShortcuts(
        bindings: {
          key(LogicalKeyboardKey.keyN): () =>
              _createKind(account.id, NewKind.note),
          key(LogicalKeyboardKey.keyN, shift: true): () =>
              _createKind(account.id, NewKind.checklist),
          key(LogicalKeyboardKey.keyF): _openSearch,
          key(LogicalKeyboardKey.keyF, shift: true): _openSearch,
          const SingleActivator(LogicalKeyboardKey.escape): _escape,
        },
        child: Focus(
          focusNode: _homeFocus,
          autofocus: true,
          child: Scaffold(
            key: _scaffold,
            drawer: inlineNav || panel == null || editorOnly
                ? null
                : Drawer(child: panel),
            appBar: editorOnly
                ? null
                : _appBar(
                    account,
                    accounts,
                    status,
                    attention,
                    scope,
                    l,
                    inlineNav,
                  ),
            floatingActionButtonLocation: listEnd == null
                ? null
                : PaneEndFloat(listEnd),
            // Typing on a half-open foldable: the keyboard covers the list.
            floatingActionButton:
                selecting ||
                    editorOnly ||
                    (tabletop != null && media.viewInsets.bottom > 0)
                ? null
                : FloatingActionButton(
                    tooltip: l.newNote,
                    onPressed: () => _newMenu(account.id),
                    child: const Icon(Icons.add),
                  ),
            body: body,
          ),
        ),
      ),
    );
  }

  Widget _content(
    Account account,
    NoteIndex? index,
    AsyncValue<List<LocalNote>> notesAsync,
    List<NoteRow> rows,
    NoteScope scope,
    List<AttentionItem> attention,
    AccountSyncStatus? status,
    AppLocalizations l,
  ) {
    if (index == null) {
      if (notesAsync.hasError) {
        return OwnStateView.error(
          title: l.loadFailed,
          actions: [
            OwnButton.primary(
              label: l.retry,
              icon: Icons.refresh,
              onPressed: () => ref.invalidate(notesProvider(account.id)),
            ),
          ],
        );
      }
      return _ListSkeleton(label: l.checkingForUpdates);
    }
    if (scope == NoteScope.attention) {
      return AttentionList(
        items: attention,
        actions: _attentionActions(account.id),
        controller: _scroll,
      );
    }
    if (rows.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _sync(account.id),
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              SizedBox(
                height: box.maxHeight,
                child: _emptyState(index, account.id, scope, status, l),
              ),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _sync(account.id),
      child: NoteListView(
        rows: rows,
        showCategory: scope == NoteScope.all || _viewId != null,
        selected: _selected,
        openId: _pane.openId,
        controller: _scroll,
        actions: NoteListActions(
          onOpen: (r) => _edit(r.note),
          onToggleSelect: _toggleSelect,
          onMenu: _rowMenu,
          onFavorite: (r) => _favorite([r]),
          onMoreSwipe: (r) =>
              _rowMenu(r, only: {RowAction.move, RowAction.delete}),
          onRetry: (_) => _sync(account.id),
        ),
      ),
    );
  }

  Widget _emptyState(
    NoteIndex index,
    String accountId,
    NoteScope scope,
    AccountSyncStatus? status,
    AppLocalizations l,
  ) {
    Widget create(
      String label, {
      String category = '',
      bool favorite = false,
    }) => OwnButton.primary(
      label: label,
      icon: Icons.add,
      onPressed: () =>
          _create(accountId, category: category, favorite: favorite),
    );
    if (index.rows.isEmpty) {
      if (_busy && status?.lastCheckedAt == null) {
        return OwnStateView(
          icon: Icons.cloud_download_outlined,
          title: l.downloadingTitle,
        );
      }
      return OwnStateView(
        icon: Icons.note_add_outlined,
        title: l.noNotes,
        actions: [create(l.createNoteAction)],
      );
    }
    if (_query.isNotEmpty || !_filters.isEmpty) {
      return OwnStateView(
        icon: Icons.search_off,
        title: l.noMatches,
        message: _query.isEmpty ? null : '“$_query”',
        actions: [
          if (!_filters.isEmpty)
            OwnButton.primary(
              label: l.clearFilters,
              onPressed: () => _setFilters(NoteFilters.none),
            ),
          if (_query.isNotEmpty)
            OwnButton.secondary(label: l.clearSearch, onPressed: _clearQuery),
        ],
      );
    }
    return switch (scope) {
      NoteScope.favorites => OwnStateView(
        icon: Icons.star_outline,
        title: l.emptyFavoritesTitle,
        message: l.emptyFavoritesBody,
      ),
      NoteScope.shared => OwnStateView(
        icon: Icons.group_outlined,
        title: l.emptySharedTitle,
        message: l.emptySharedBody,
      ),
      NoteScope.category => OwnStateView(
        icon: Icons.folder_outlined,
        title: l.emptyCategoryTitle(_category),
        actions: [create(l.createHere, category: _category)],
      ),
      _ => OwnStateView(
        icon: Icons.folder_outlined,
        title: l.noNotesHere,
        actions: [create(l.newNoteHere)],
      ),
    };
  }

  Widget _bulkNotice(AppLocalizations l) {
    final rows = _selectedRows;
    final notes = [
      if (!rows.every((r) => canFavorite(r.note))) l.bulkMixedFavorite,
      if (!rows.every(canMove)) l.bulkMixedMove,
      if (!rows.every((r) => canDelete(r.note))) l.bulkMixedDelete,
    ];
    if (notes.isEmpty) return const SizedBox.shrink();
    final colors = context.own;
    return Semantics(
      container: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: OwnSpace.phoneInset,
          vertical: OwnSpace.s,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: colors.info),
            const SizedBox(width: OwnSpace.s),
            Expanded(
              child: Text(
                notes.join(' '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _scopeTitle(NoteScope scope, AppLocalizations l) => switch (scope) {
    NoteScope.all => l.allNotes,
    NoteScope.favorites => l.favorites,
    NoteScope.uncategorised => l.uncategorised,
    NoteScope.shared => l.sharedWithMe,
    NoteScope.attention => l.needsAttention,
    NoteScope.category => _category,
  };

  AppBar _appBar(
    Account account,
    List<Account> accounts,
    AccountSyncStatus? status,
    List<AttentionItem> attention,
    NoteScope scope,
    AppLocalizations l,
    bool inlineNav,
  ) {
    if (_selected.isNotEmpty) return _selectionBar(l);
    if (_searching) return _searchBar(account, scope, l);
    final view = _views.where((v) => v.id == _viewId).firstOrNull;
    final title = view?.name ?? _scopeTitle(scope, l);
    final name = _accountLabel(account, accounts);
    final offline = status?.problem == 'offline' && status!.pendingUploads == 0;
    return AppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 64,
      titleSpacing: inlineNav ? OwnSpace.l : 0,
      leading: inlineNav
          ? null
          : IconButton(
              tooltip: l.categoriesMenu,
              onPressed: () => _scaffold.currentState?.openDrawer(),
              icon: const Icon(Icons.menu),
            ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          AccountSubtitle(
            name: name,
            busy: _busy,
            offline: offline,
            attention:
                status != null &&
                (status.needsAttention > 0 ||
                    account.state == 'reauthRequired'),
            onTap: () => showSyncDetails(
              context,
              accountId: account.id,
              onSyncNow: () => _sync(account.id),
              onOpenAttention: () => _go(NoteScope.attention),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: l.search,
          onPressed: _openSearch,
          icon: const Icon(Icons.search),
        ),
        _accountButton(account, l),
        PopupMenuButton<String>(
          tooltip: l.moreOptions,
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => switch (value) {
            'sync' => _sync(account.id),
            'select' => _selectFirst(),
            'sort' => _sortSheet(),
            'settings' => _openSettings(account),
            _ => _importKeep(account.id),
          },
          itemBuilder: (_) => [
            _menuItem('sync', Icons.sync, l.syncNow),
            _menuItem('select', Icons.checklist_rtl, l.selectNotes),
            _menuItem('sort', Icons.tune, l.sortAndFilter),
            _menuItem('settings', Icons.settings_outlined, l.settings),
            _menuItem('import', Icons.upload_file_outlined, l.importKeep),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: OwnSpace.m),
            Expanded(child: Text(label)),
          ],
        ),
      );

  AppBar _searchBar(Account account, NoteScope scope, AppLocalizations l) =>
      AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: _closeSearch,
          icon: const BackButtonIcon(),
        ),
        title: TextField(
          controller: _searchField,
          focusNode: _searchFocus,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l.search,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          onChanged: _onSearch,
        ),
        actions: [
          if (_searchField.text.isNotEmpty)
            IconButton(
              tooltip: l.clearSearch,
              onPressed: _clearQuery,
              icon: const Icon(Icons.close),
            ),
          IconButton(
            tooltip: l.sortAndFilter,
            onPressed: _sortSheet,
            icon: const Icon(Icons.tune),
          ),
        ],
      );

  AppBar _selectionBar(AppLocalizations l) {
    final rows = _selectedRows;
    final allFavorite = rows.isNotEmpty && rows.every((r) => r.note.favorite);
    final favoriteOk = rows.every((r) => canFavorite(r.note));
    final moveOk = rows.every(canMove);
    final deleteOk = rows.every((r) => canDelete(r.note));
    return AppBar(
      automaticallyImplyLeading: false,
      leading: IconButton(
        tooltip: l.clearSelection,
        onPressed: _clearSelection,
        icon: const Icon(Icons.close),
      ),
      title: Text(l.selectedCount(rows.length)),
      actions: [
        IconButton(
          tooltip: allFavorite ? l.bulkUnfavorite : l.bulkFavorite,
          onPressed: favoriteOk ? () => _favorite(rows) : null,
          icon: Icon(allFavorite ? Icons.star : Icons.star_outline),
        ),
        IconButton(
          tooltip: l.bulkMove,
          onPressed: moveOk ? () => _move(rows) : null,
          icon: const Icon(Icons.drive_file_move_outlined),
        ),
        IconButton(
          tooltip: l.bulkExport,
          onPressed: () => _export(rows),
          icon: const Icon(Icons.ios_share),
        ),
        IconButton(
          tooltip: l.delete,
          onPressed: deleteOk ? () => _delete(rows, confirm: true) : null,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  void _openSettings(Account account) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/settings'),
      builder: (_) => SettingsScreen(account: account),
    ),
  );

  String _accountLabel(Account account, List<Account> accounts) {
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    final clash = accounts.any(
      (a) => a.id != account.id && a.loginName == account.loginName,
    );
    return clash ? '$name · ${Uri.parse(account.server).host}' : name;
  }

  Widget _accountButton(Account account, AppLocalizations l) {
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    return IconButton(
      tooltip: l.switchAccount,
      onPressed: _busy
          ? null
          : () => showAccountSwitcher(
              context,
              currentId: account.id,
              beforeSwitch: _pane.close,
            ),
      icon: SizedBox.square(
        dimension: 32,
        child: AccountAvatar(account: account, name: name),
      ),
    );
  }

  void _addAccount() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => const LoginScreen(),
    ),
  );

  void _reauthenticate(Account account) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => LoginScreen(reauthenticate: account),
    ),
  );
}

/// Placeholder rows while no cached content exists. Static, so reduced
/// motion has nothing to switch off.
class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.own;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.raised,
        borderRadius: BorderRadius.circular(OwnShape.compactRadius),
      ),
    );
    return Semantics(
      label: label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.all(OwnSpace.phoneInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(180, 16),
                    const SizedBox(height: OwnSpace.s),
                    bar(280, 12),
                    const SizedBox(height: OwnSpace.xs),
                    bar(120, 12),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
