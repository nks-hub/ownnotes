import 'dart:async';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/background.dart';
import '../data/keep_import.dart';
import '../data/notes_widget.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../l10n/app_localizations.dart';
import 'category_panel.dart';
import 'accounts.dart';
import 'editor.dart';
import 'login.dart';
import 'note_rows.dart';
import 'note_tile.dart';
import 'recovery.dart';
import 'settings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _shown;
  NoteScope _scope = NoteScope.all;
  String _category = '';
  String _search = '';
  bool _searching = false;
  final _searchField = TextEditingController();
  Timer? _debounce;
  final _expanded = <String>{};
  final _scaffold = GlobalKey<ScaffoldState>();
  bool _bannerHidden = false;
  String? _bannerKey;
  _Index? _index;
  Object? _visibleKey;
  List<NoteRow> _visible = const [];
  bool _busy = false;
  String? _again;
  bool _byTitle = false;
  StreamSubscription<Uri?>? _widgetClicks;
  Timer? _retry;
  final _autoSynced = <String>{};
  late final AppLifecycleListener _lifecycle;

  static const _share = MethodChannel('com.nkshub.nextcloudnotes/share');
  static const _sortKey = 'sortByTitle';

  @override
  void initState() {
    super.initState();
    _loadSort();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _retry?.cancel();
        // Always: an editor may have saved its last change only just now.
        syncWhenOnline().catchError((Object _) {});
      },
      onResume: () {
        final id = _shown;
        if (id != null) _sync(id, quiet: true);
        // iOS: the share extension leaves text in the App Group meanwhile.
        _takeShared();
      },
    );
    _share.setMethodCallHandler((_) => _takeShared());
    if (Platform.isAndroid) {
      _widgetClicks = HomeWidget.widgetClicked.listen(_openLink);
    }
  }

  /// Links from the home-screen widget and the launcher shortcut:
  /// `ownnotes://new` and `ownnotes://note/<local id>`.
  Future<void> _openLink(Uri? link) async {
    final accountId = _shown;
    if (link == null || link.scheme != 'ownnotes' || accountId == null) return;
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (link.host == 'new') {
      await _create(accountId);
      return;
    }
    final id = link.pathSegments.firstOrNull;
    if (link.host != 'note' || id == null) return;
    final db = ref.read(runtimeProvider).database;
    var note = await db.note(accountId, id);
    if (note == null) {
      // The link may belong to another signed-in account.
      for (final other in await ref.read(accountsProvider.future)) {
        if (other.id == accountId) continue;
        note = await db.note(other.id, id);
        if (note != null) break;
      }
    }
    if (note == null || !mounted) return;
    if (note.accountId != accountId) {
      ref.read(selectedAccountIdProvider.notifier).state = note.accountId;
      setState(() => _scope = NoteScope.all);
    }
    await _edit(note);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchField.dispose();
    _share.setMethodCallHandler(null);
    _widgetClicks?.cancel();
    _retry?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Text shared from another app (Google Keep, Samsung Notes, ...) becomes a
  /// new note of the shown account. Without an account it waits on the
  /// platform side until one exists.
  Future<void> _takeShared() async {
    final accountId = _shown;
    if (accountId == null) return;
    final Map<String, String>? shared;
    try {
      shared = await _share.invokeMapMethod<String, String>('takeShared');
    } on MissingPluginException {
      return; // Only Android and iOS register the share target.
    }
    if (shared == null || !mounted) return;
    final text = shared['text'] ?? '';
    // An open editor saved its text when the app went to the background.
    Navigator.of(context).popUntil((route) => route.isFirst);
    final db = ref.read(runtimeProvider).database;
    final recent = (await ref.read(notesProvider(accountId).future))
        .where(
          (n) =>
              !n.readonly && (n.syncState == 'clean' || n.syncState == 'draft'),
        )
        .take(8)
        .toList();
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;
    // Dismissing the dialog still keeps the text, as a new note.
    final target = recent.isEmpty
        ? null
        : await showDialog<LocalNote>(
            context: context,
            builder: (context) => SimpleDialog(
              title: Text(l.shareTo),
              children: [
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.newNote),
                ),
                for (final note in recent)
                  SimpleDialogOption(
                    onPressed: () => Navigator.of(context).pop(note),
                    child: Text(
                      _shownTitle(note, l),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          );
    if (target == null) {
      await _create(
        accountId,
        title: _titleOr(shared['title'] ?? '', text),
        content: text,
      );
      return;
    }
    try {
      final current = (await db.note(accountId, target.id))!;
      await db.saveDraft(
        accountId: accountId,
        id: current.id,
        revision: current.revision,
        title: current.title,
        content: current.content.isEmpty
            ? text
            : '${current.content.trimRight()}\n\n$text',
        category: current.category,
        favorite: current.favorite,
      );
      final updated = await db.note(accountId, current.id);
      if (mounted && updated != null) await _edit(updated);
    } catch (_) {
      // The note changed meanwhile; the text is not lost, it becomes a note.
      await _create(accountId, content: text);
    }
  }

  static String _titleOr(String title, String text) =>
      title.trim().isNotEmpty ? title : titleFromContent(text);

  Future<void> _loadSort() async {
    try {
      final byTitle = await SharedPreferencesAsync().getBool(_sortKey);
      if (mounted && byTitle != null) setState(() => _byTitle = byTitle);
    } catch (_) {
      // Preferences are a convenience; the default order still works.
    }
  }

  void _toggleSort() {
    setState(() => _byTitle = !_byTitle);
    SharedPreferencesAsync().setBool(_sortKey, _byTitle).ignore();
  }

  /// Quiet runs are automatic (start, resume, after editing); offline is
  /// normal there, so only a manual sync reports failure. A failed run is
  /// retried while the app stays in front, so notes upload once the
  /// network is back.
  Future<void> _sync(String accountId, {bool quiet = false}) async {
    if (_busy) {
      // The running pass may have started before the latest local edit.
      _again = accountId;
      return;
    }
    _retry?.cancel();
    setState(() => _busy = true);
    try {
      do {
        _again = null;
        await ref.read(runtimeProvider).sync.sync(accountId);
        accountId = _again ?? accountId;
      } while (_again != null && mounted);
    } catch (_) {
      if (mounted && !quiet) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.syncFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (ref.read(runtimeProvider).sync.problem(accountId) != null) {
          _retry = Timer(
            const Duration(seconds: 30),
            () => _sync(accountId, quiet: true),
          );
        }
      }
    }
  }

  Future<void> _edit(LocalNote note) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: note.syncState == 'needsDecision' ? '/recovery' : '/note',
        ),
        builder: (_) => note.syncState == 'needsDecision'
            ? RecoveryScreen(note: note)
            : EditorScreen(note: note),
      ),
    );
    if (mounted) await _sync(note.accountId, quiet: true);
  }

  Future<void> _importKeep(String accountId) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.path;
    if (path == null) return;
    try {
      final input = InputFileStream(path);
      final List<KeepNote> notes;
      try {
        notes = readKeepTakeout(ZipDecoder().decodeStream(input));
      } finally {
        await input.close();
      }
      if (notes.isEmpty) throw const FormatException('no_keep_notes');
      final db = ref.read(runtimeProvider).database;
      for (final note in notes) {
        await db.createDraft(
          accountId,
          title: _titleOr(note.title, note.content),
          content: note.content,
          category: note.category,
        );
      }
      messenger.showSnackBar(
        SnackBar(content: Text(l.importDone(notes.length))),
      );
      await _sync(accountId, quiet: true);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed)));
    }
  }

  Future<void> _create(
    String accountId, {
    String title = '',
    String content = '',
    String category = '',
  }) async {
    try {
      final db = ref.read(runtimeProvider).database;
      final id = await db.createDraft(
        accountId,
        title: title,
        content: content,
        category: category,
      );
      final note = await db.note(accountId, id);
      if (mounted && note != null) await _edit(note);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.saveFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider);
    // The widget hides titles while the app lock is on.
    final locked = ref.watch(settingsProvider.select((s) => s.lock));
    return accounts.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(body: Center(child: Text(l.loadFailed))),
      data: (accounts) {
        final account =
            accounts
                .where((a) => a.id == ref.watch(selectedAccountIdProvider))
                .firstOrNull ??
            accounts.firstOrNull;
        _shown = account?.id;
        if (account == null) {
          return Scaffold(
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
            body: _EmptyText(l.noAccounts),
          );
        }
        if (_autoSynced.add(account.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sync(account.id, quiet: true);
            _takeShared();
            if (Platform.isAndroid) {
              HomeWidget.initiallyLaunchedFromHomeWidget().then(_openLink);
            }
          });
        }
        return _screen(account, accounts, locked, l);
      },
    );
  }

  Widget _screen(
    Account account,
    List<Account> accounts,
    bool locked,
    AppLocalizations l,
  ) {
    final notesAsync = ref.watch(notesProvider(account.id));
    final notes = notesAsync.valueOrNull;
    final index = notes == null
        ? null
        : _indexFor(account.id, notes, locked, l);
    final wide = MediaQuery.sizeOf(context).width >= 840;
    var scope = _scope;
    if (index != null &&
        scope == NoteScope.category &&
        !index.paths.contains(_category)) {
      scope = NoteScope.all;
    }
    final rows = index == null
        ? const <NoteRow>[]
        : _visibleRows(index, scope, _category, l);

    final problem = account.state == 'reauthRequired'
        ? 'auth'
        : ref.read(runtimeProvider).sync.problem(account.id);
    final unsent = index?.unsent ?? 0;
    final conflicts = index?.conflicts ?? 0;
    final hasStatus = problem != null || unsent > 0 || conflicts > 0;
    final bannerKey = '${account.id}|$problem|${unsent > 0}|${conflicts > 0}';
    if (_bannerKey != bannerKey) {
      _bannerKey = bannerKey;
      _bannerHidden = false;
    }

    final panel = index == null
        ? null
        : CategoryPanel(
            tree: index.tree,
            total: index.rows.length,
            favorites: index.favorites,
            uncategorised: index.uncategorised,
            scope: scope,
            category: _category,
            expanded: _expanded,
            onSelect: (s, c) {
              setState(() {
                _scope = s;
                _category = c;
              });
              if (!wide) _scaffold.currentState?.closeDrawer();
            },
            onToggle: (path) => setState(
              () => _expanded.contains(path)
                  ? _expanded.remove(path)
                  : _expanded.add(path),
            ),
          );

    final title = switch (scope) {
      NoteScope.all => l.appTitle,
      NoteScope.favorites => l.favorites,
      NoteScope.uncategorised => l.uncategorised,
      NoteScope.category => _category,
    };
    final createCategory = scope == NoteScope.category ? _category : '';

    final Widget content;
    if (index == null) {
      content = notesAsync.hasError
          ? Center(child: Text(l.loadFailed))
          : const Center(child: CircularProgressIndicator());
    } else {
      content = Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          if (hasStatus && !_busy && !_bannerHidden)
            _StatusBanner(
              critical: problem == 'auth' || conflicts > 0,
              lines: [
                if (conflicts > 0) l.conflictsCount(conflicts),
                if (unsent > 0) l.unsent(unsent),
                if (problem != null) _reason(problem, l),
              ],
              actions: [
                if (conflicts > 0 && index.firstConflict != null)
                  TextButton(
                    onPressed: () => _edit(index.firstConflict!),
                    child: Text(l.resolveNow),
                  ),
                if (problem == 'auth')
                  TextButton(
                    onPressed: _addAccount,
                    child: Text(l.signInAgain),
                  ),
                if (problem != 'auth' && (problem != null || unsent > 0))
                  TextButton(
                    onPressed: () => _sync(account.id),
                    child: Text(l.retry),
                  ),
              ],
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _sync(account.id),
              child: rows.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        _emptyState(index, account.id, createCategory, l),
                      ],
                    )
                  : ListView.builder(
                      key: ValueKey('$scope|$_category|$_search|$_byTitle'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: rows.length,
                      itemBuilder: (context, i) => NoteTile(
                        key: ValueKey(rows[i].note.id),
                        row: rows[i],
                        showCategory: scope == NoteScope.all,
                        onTap: () => _edit(rows[i].note),
                      ),
                    ),
            ),
          ),
        ],
      );
    }
    final centered = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: content,
      ),
    );

    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeSearch();
      },
      child: Scaffold(
        key: _scaffold,
        drawer: wide || panel == null ? null : Drawer(child: panel),
        appBar: AppBar(
          automaticallyImplyLeading: !_searching,
          titleSpacing: 0,
          leading: _searching
              ? IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: _closeSearch,
                  icon: const BackButtonIcon(),
                )
              : null,
          title: _searching
              ? TextField(
                  controller: _searchField,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l.search,
                    border: InputBorder.none,
                  ),
                  onChanged: _onSearch,
                )
              : Text(title, overflow: TextOverflow.ellipsis),
          actions: _searching
              ? [
                  if (_searchField.text.isNotEmpty)
                    IconButton(
                      tooltip: l.clearSearch,
                      onPressed: () {
                        _searchField.clear();
                        _onSearch('');
                      },
                      icon: const Icon(Icons.close),
                    ),
                ]
              : [
                  IconButton(
                    tooltip: l.search,
                    onPressed: () => setState(() => _searching = true),
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: l.sync,
                    onPressed: _busy ? null : () => _sync(account.id),
                    icon: const Icon(Icons.sync),
                  ),
                  if (hasStatus)
                    IconButton(
                      tooltip: l.syncStatus,
                      onPressed: () =>
                          setState(() => _bannerHidden = !_bannerHidden),
                      icon: Icon(
                        problem == 'auth' || conflicts > 0
                            ? Icons.error_outline
                            : Icons.cloud_off_outlined,
                        color: problem == 'auth' || conflicts > 0
                            ? Theme.of(context).colorScheme.error
                            : null,
                      ),
                    ),
                  _accountMenu(account, accounts, l),
                  PopupMenuButton<String>(
                    onSelected: (value) => switch (value) {
                      'settings' => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/settings'),
                          builder: (_) => SettingsScreen(account: account),
                        ),
                      ),
                      'sort' => _toggleSort(),
                      _ => _importKeep(account.id),
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'settings', child: Text(l.settings)),
                      PopupMenuItem(
                        value: 'sort',
                        child: Text(
                          _byTitle ? l.sortByModified : l.sortByTitle,
                        ),
                      ),
                      PopupMenuItem(value: 'import', child: Text(l.importKeep)),
                    ],
                  ),
                ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: l.newNote,
          onPressed: () => _create(account.id, category: createCategory),
          child: const Icon(Icons.add),
        ),
        body: wide && panel != null
            ? Row(
                children: [
                  SizedBox(width: 280, child: panel),
                  const VerticalDivider(width: 1),
                  Expanded(child: centered),
                ],
              )
            : centered,
      ),
    );
  }

  Widget _accountMenu(
    Account account,
    List<Account> accounts,
    AppLocalizations l,
  ) {
    final name = account.loginName;
    return PopupMenuButton<String>(
      tooltip: l.switchAccount,
      icon: CircleAvatar(
        radius: 14,
        child: Text(
          name.isEmpty
              ? '?'
              : String.fromCharCode(name.runes.first).toUpperCase(),
        ),
      ),
      onSelected: (id) {
        if (id == _addKey) {
          _addAccount();
        } else if (id == _manageKey) {
          openAccounts(context, currentId: account.id);
        } else {
          ref.read(selectedAccountIdProvider.notifier).state = id;
        }
      },
      itemBuilder: (_) => [
        for (final a in accounts)
          PopupMenuItem(
            value: a.id,
            enabled: !_busy,
            child: Row(
              children: [
                SizedBox(
                  width: 28,
                  child: a.id == account.id
                      ? const Icon(Icons.check, size: 18)
                      : null,
                ),
                Flexible(
                  child: Text(
                    '${a.loginName} · ${Uri.parse(a.server).host}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _addKey,
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child: Icon(Icons.person_add_outlined, size: 18),
              ),
              Text(l.addAccount),
            ],
          ),
        ),
        PopupMenuItem(
          value: _manageKey,
          child: Row(
            children: [
              const SizedBox(
                width: 28,
                child: Icon(Icons.manage_accounts_outlined, size: 18),
              ),
              Text(l.accounts),
            ],
          ),
        ),
      ],
    );
  }

  static const _addKey = '__add_account__';
  static const _manageKey = '__manage_accounts__';

  void _addAccount() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => const LoginScreen(),
    ),
  );

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _search = value.trim().toLowerCase());
    });
    // The clear button follows the text at once, the filter a moment later.
    setState(() {});
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchField.clear();
    setState(() {
      _searching = false;
      _search = '';
    });
  }

  Widget _emptyState(
    _Index index,
    String accountId,
    String category,
    AppLocalizations l,
  ) {
    if (index.rows.isEmpty) return _EmptyText(l.noNotes);
    if (_search.isNotEmpty) {
      return _EmptyText(
        l.noMatches,
        action: TextButton(onPressed: _closeSearch, child: Text(l.clearSearch)),
      );
    }
    return _EmptyText(
      l.noNotesHere,
      action: FilledButton.tonal(
        onPressed: () => _create(accountId, category: category),
        child: Text(l.newNoteHere),
      ),
    );
  }

  /// Rows are rebuilt only when the notes list changes, not on every build;
  /// that is also the one place the home-screen widget gets its data.
  _Index _indexFor(
    String accountId,
    List<LocalNote> notes,
    bool locked,
    AppLocalizations l,
  ) {
    final old = _index;
    if (old != null &&
        old.accountId == accountId &&
        identical(old.notes, notes) &&
        old.locked == locked) {
      return old;
    }
    final previous = old?.accountId == accountId
        ? {for (final r in old!.rows) r.note.id: r}
        : const <String, NoteRow>{};
    final counts = <String, int>{};
    var favorites = 0;
    var uncategorised = 0;
    var unsent = 0;
    var conflicts = 0;
    LocalNote? firstConflict;
    for (final n in notes) {
      if (n.category.isEmpty) {
        uncategorised++;
      } else {
        counts.update(n.category, (v) => v + 1, ifAbsent: () => 1);
      }
      if (n.favorite) favorites++;
      switch (n.syncState) {
        case 'draft' || 'sending':
          unsent++;
        case 'needsDecision':
          conflicts++;
          firstConflict ??= n;
      }
    }
    final tree = buildCategoryTree(counts);
    final paths = <String>{};
    void walk(List<CategoryNode> nodes) {
      for (final n in nodes) {
        paths.add(n.path);
        walk(n.children);
      }
    }

    walk(tree);
    publishNotesWidget(accountId, notes, locked: locked, untitled: l.untitled);
    return _index = _Index(
      notes: notes,
      accountId: accountId,
      locked: locked,
      rows: [for (final n in notes) NoteRow.of(n, previous[n.id])],
      tree: tree,
      paths: paths,
      favorites: favorites,
      uncategorised: uncategorised,
      unsent: unsent,
      conflicts: conflicts,
      firstConflict: firstConflict,
    );
  }

  List<NoteRow> _visibleRows(
    _Index index,
    NoteScope scope,
    String category,
    AppLocalizations l,
  ) {
    final key = (index, scope, category, _search, _byTitle);
    if (_visibleKey == key) return _visible;
    final rows = [
      for (final r in index.rows)
        if (r.inScope(scope, category) &&
            (_search.isEmpty || r.haystack.contains(_search)))
          r,
    ];
    if (_byTitle) {
      final untitled = l.untitled.toLowerCase();
      final keys = {
        for (final r in rows)
          r: r.title.isEmpty ? untitled : r.title.toLowerCase(),
      };
      rows.sort((a, b) => keys[a]!.compareTo(keys[b]!));
    }
    _visibleKey = key;
    return _visible = rows;
  }

  /// A note not uploaded yet shows the name the server will give it.
  static String _shownTitle(LocalNote n, AppLocalizations l) {
    final title = n.title.trim().isEmpty
        ? titleFromContent(n.content)
        : n.title;
    return title.isEmpty ? l.untitled : title;
  }

  static String _reason(String problem, AppLocalizations l) =>
      switch (problem) {
        'offline' => l.reasonOffline,
        'auth' => l.reasonAuth,
        'locked' => l.reasonLocked,
        'storage_full' => l.reasonStorageFull,
        _ => l.reasonServer,
      };
}

/// Everything derived from one list of notes, kept between builds.
class _Index {
  _Index({
    required this.notes,
    required this.accountId,
    required this.locked,
    required this.rows,
    required this.tree,
    required this.paths,
    required this.favorites,
    required this.uncategorised,
    required this.unsent,
    required this.conflicts,
    required this.firstConflict,
  });
  final List<LocalNote> notes;
  final String accountId;
  final bool locked;
  final List<NoteRow> rows;
  final List<CategoryNode> tree;
  final Set<String> paths;
  final int favorites;
  final int uncategorised;
  final int unsent;
  final int conflicts;
  final LocalNote? firstConflict;
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.lines,
    required this.actions,
    required this.critical,
  });
  final List<String> lines;
  final List<Widget> actions;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = critical
        ? scheme.onErrorContainer
        : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: critical ? scheme.errorContainer : scheme.secondaryContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in lines)
                Text(line, style: TextStyle(color: color)),
              if (actions.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(children: actions),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text, {this.action});
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    ),
  );
}
