import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/background.dart';
import '../data/export.dart';
import '../data/keep_import.dart';
import '../data/notes_widget.dart';
import '../data/runtime.dart';
import '../data/settings.dart';
import '../data/widgets/widget_links.dart';
import '../design/design.dart';
import '../l10n/app_localizations.dart';
import 'accounts.dart';
import 'category_panel.dart';
import 'collection/attention_view.dart';
import 'collection/editor_pane.dart';
import 'collection/note_list.dart';
import 'collection/notebook_actions.dart';
import 'collection/providers.dart';
import 'collection/saved_views.dart';
import 'collection/shared_text.dart';
import 'collection/sheets.dart';
import 'collection/status_area.dart';
import 'attachments/add_attachment.dart';
import 'capture/handle_captures.dart';
import '../data/attachments/providers.dart';
import 'editor.dart';
import 'templates/templates.dart';
import 'templates/templates_screen.dart';
import 'login.dart';
import 'note_rows.dart';
import 'recovery.dart';
import 'search/filter_row.dart';
import 'search/search_filters.dart';
import 'settings.dart';

/// Creates a note from a template or the daily note in [category] of
/// [accountId]; supplied by the writing package. Without it both create an
/// ordinary note.
typedef CreateNoteHook =
    Future<void> Function(
      BuildContext context,
      String accountId,
      String category,
    );

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key, this.onCreateTemplate, this.onCreateDailyNote});

  final CreateNoteHook? onCreateTemplate;
  final CreateNoteHook? onCreateDailyNote;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _shown;
  String? _loadedFor;
  NoteScope _scope = NoteScope.all;
  String _category = '';
  String _subtree = '';
  String? _viewId;
  NoteFilters _filters = NoteFilters.none;
  SortMode _sort = SortMode.modified;
  String _query = '';
  bool _searching = false;
  final _searchField = TextEditingController();
  final _searchFocus = FocusNode();
  final _homeFocus = FocusNode();
  final _selected = <String>{};
  final _expandedBy = <String, Set<String>>{};
  final _viewsBy = <String, List<SavedView>>{};
  final _scroll = ScrollController();
  final _pane = EditorPaneController();
  final _scaffold = GlobalKey<ScaffoldState>();
  Timer? _debounce;
  Timer? _checkTimer;
  Timer? _retry;
  _Index? _index;
  Object? _visibleKey;
  List<NoteRow> _visible = const [];
  NotebookLayout _layout = NotebookLayout.phone;
  bool _busy = false;
  bool _checking = false;
  String? _again;
  StreamSubscription<Uri?>? _widgetClicks;
  final _autoSynced = <String>{};
  late final AppLifecycleListener _lifecycle;

  static const _sortKey = 'sortMode';
  static const _oldSortKey = 'sortByTitle';
  static const _viewStore = SavedViewStore();

  Set<String> get _expanded =>
      _expandedBy.putIfAbsent(_shown ?? '', () => <String>{});
  List<SavedView> get _views => _viewsBy[_shown] ?? const [];
  NotebookActions get _actions =>
      NotebookActions(ref.read(runtimeProvider).database);

  @override
  void initState() {
    super.initState();
    _loadSort();
    _pane.addListener(_paneChanged);
    _pane.onClosed = (id) {
      final account = _shown;
      if (account != null && mounted) _sync(account, quiet: true);
    };
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _retry?.cancel();
        // Always: an editor may have saved its last change only just now.
        syncWhenOnline().catchError((Object _) {});
      },
      onResume: () {
        final id = _shown;
        if (id != null) _sync(id, quiet: true);
        // Ticks queued by the widgets while the app was closed; send them.
        publishAllWidgets(ref.read(runtimeProvider).database).then((changed) {
          for (final account in changed) {
            if (mounted) _sync(account, quiet: true);
          }
        }).ignore();
        // iOS: the share extension leaves text in the App Group meanwhile.
        _takeShared();
      },
    );
    shareChannel.setMethodCallHandler((_) => _takeShared());
    if (Platform.isAndroid) {
      _widgetClicks = HomeWidget.widgetClicked.listen(_openLink);
    }
  }

  void _paneChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _checkTimer?.cancel();
    _retry?.cancel();
    _searchField.dispose();
    _searchFocus.dispose();
    _homeFocus.dispose();
    _scroll.dispose();
    _pane
      ..removeListener(_paneChanged)
      ..dispose();
    shareChannel.setMethodCallHandler(null);
    _widgetClicks?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Links from the home-screen widget and the launcher shortcut:
  /// `ownnotes://new` and `ownnotes://note/<local id>`.
  Future<void> _openLink(Uri? uri) async {
    final link = parseWidgetLink(uri);
    if (link == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (link is OpenAppLink) return;
    final accounts = await ref.read(accountsProvider.future);
    final wanted = switch (link) {
      NewNoteLink(:final accountId) ||
      OpenNoteLink(:final accountId) => accountId,
      _ => null,
    };
    var accountId = accounts.any((a) => a.id == wanted) ? wanted : _shown;
    if (accountId == null || !mounted) return;
    if (link is OpenNoteLink) {
      final db = ref.read(runtimeProvider).database;
      var note = await db.note(accountId, link.noteId);
      if (note == null && link.accountId == null) {
        // An old link may belong to another signed-in account.
        for (final other in accounts) {
          note = await db.note(other.id, link.noteId);
          if (note != null) break;
        }
      }
      if (note == null || !mounted) return;
      accountId = note.accountId;
    }
    if (accountId != _shown) {
      ref.read(selectedAccountIdProvider.notifier).state = accountId;
      _go(NoteScope.all);
    }
    switch (link) {
      case OpenNoteLink(:final noteId):
        await _openById(accountId, noteId);
      case NewNoteLink(:final kind):
        await _createKind(accountId, NewKind.values.byName(kind.name));
      case OpenAppLink():
        break;
    }
  }

  /// Content shared from other apps waits on disk until it is stored as a
  /// note; the capture screen asks for the account and destination.
  Future<void> _takeShared() async {
    final accountId = _shown;
    if (accountId == null || !mounted) return;
    final bool stored;
    try {
      stored = await handleIncomingCaptures(context, ref);
    } catch (_) {
      // The capture stays on disk and is offered again next time.
      return;
    }
    // A saved capture is a new local note; send it like any other edit.
    if (stored && mounted) await _sync(_shown ?? accountId, quiet: true);
  }

  Future<void> _loadSort() async {
    try {
      final prefs = SharedPreferencesAsync();
      final stored = await prefs.getString(_sortKey);
      final mode = SortMode.values.where((s) => s.name == stored).firstOrNull;
      final legacy = mode == null ? await prefs.getBool(_oldSortKey) : null;
      if (!mounted) return;
      if (mode != null) setState(() => _sort = mode);
      if (legacy == true) setState(() => _sort = SortMode.title);
    } catch (_) {
      // Preferences are a convenience; the default order still works.
    }
  }

  void _setSort(SortMode mode) {
    setState(() => _sort = mode);
    SharedPreferencesAsync().setString(_sortKey, mode.name).ignore();
  }

  /// Resets what belongs to one account and loads its device preferences.
  void _switchAccount(String id) {
    _loadedFor = id;
    _scope = NoteScope.all;
    _category = '';
    _subtree = '';
    _viewId = null;
    _filters = NoteFilters.none;
    _query = '';
    _searching = false;
    _searchField.clear();
    _selected.clear();
    _index = null;
    if (_pane.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pane.close());
    }
    _viewStore.load(id).then((views) {
      if (mounted) setState(() => _viewsBy[id] = views);
    });
    SharedPreferencesAsync()
        .getStringList('categoryExpanded.$id')
        .then((v) {
          if (mounted && v != null) setState(() => _expandedBy[id] = v.toSet());
        })
        .catchError((Object _) {});
  }

  void _toggleExpanded(String path) {
    final id = _shown;
    setState(
      () => _expanded.contains(path)
          ? _expanded.remove(path)
          : _expanded.add(path),
    );
    if (id != null) {
      SharedPreferencesAsync()
          .setStringList('categoryExpanded.$id', _expanded.toList())
          .ignore();
    }
  }

  /// Quiet runs are automatic (start, resume, after editing); offline is
  /// normal there, so only a manual sync reports failure. A failed run is
  /// retried while the app stays in front, so notes upload once the
  /// network is back. A manual run shows its "Checking" row only when it
  /// lasts longer than [explicitSyncRowDelay].
  Future<void> _sync(String accountId, {bool quiet = false}) async {
    if (_busy) {
      // The running pass may have started before the latest local edit.
      _again = accountId;
      return;
    }
    _retry?.cancel();
    if (!quiet) {
      _checkTimer?.cancel();
      _checkTimer = Timer(explicitSyncRowDelay, () {
        if (mounted) setState(() => _checking = true);
      });
    }
    setState(() => _busy = true);
    try {
      do {
        _again = null;
        await ref.read(runtimeProvider).sync.sync(accountId);
        // Staged attachments upload once their notes exist on the server;
        // a failure keeps them staged for the next run.
        try {
          await (await ref.read(
            attachmentServiceProvider.future,
          )).flush(accountId);
        } catch (_) {}
        accountId = _again ?? accountId;
      } while (_again != null && mounted);
    } catch (_) {
      if (mounted && !quiet) {
        showOwnSnackBar(context, AppLocalizations.of(context)!.syncFailed);
      }
    } finally {
      _checkTimer?.cancel();
      if (mounted) {
        setState(() {
          _busy = false;
          _checking = false;
        });
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
    final decision = note.syncState == 'needsDecision';
    final name = decision ? '/recovery' : '/note';
    Widget page() => decision
        ? RecoveryScreen(note: note)
        : EditorScreen(
            note: note,
            onAttach: (kind) => addAttachment(context, ref, note, kind),
          );
    if (_layout != NotebookLayout.phone || _pane.isOpen) {
      await _pane.open(note.id, name, (_) => page());
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        settings: RouteSettings(name: name),
        builder: (_) => page(),
      ),
    );
    if (mounted) await _sync(note.accountId, quiet: true);
  }

  Future<void> _importKeep(String accountId) async {
    final l = AppLocalizations.of(context)!;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = picked?.path;
    if (path == null || !mounted) return;
    try {
      final result = await importKeepTakeout(
        zipPath: path,
        database: ref.read(runtimeProvider).database,
        attachments: await ref.read(attachmentServiceProvider.future),
        accountId: accountId,
      );
      if (result.notes == 0) throw const FormatException('no_keep_notes');
      if (!mounted) return;
      showOwnSnackBar(
        context,
        l.importKeepAttachments(
          result.notes,
          result.attachments,
          result.skippedAttachments,
        ),
      );
      await _sync(accountId, quiet: true);
    } catch (_) {
      if (mounted) showOwnSnackBar(context, l.importFailed);
    }
  }

  Future<void> _create(
    String accountId, {
    String title = '',
    String content = '',
    String category = '',
    bool favorite = false,
  }) async {
    try {
      final db = ref.read(runtimeProvider).database;
      final id = await _actions.create(
        accountId,
        title: title,
        content: content,
        category: category,
        favorite: favorite,
      );
      final note = await db.note(accountId, id);
      if (mounted && note != null) await _edit(note);
    } catch (_) {
      if (mounted) {
        showOwnSnackBar(context, AppLocalizations.of(context)!.saveFailed);
      }
    }
  }

  /// Where a note created from the current scope goes (spec 4.2); null when
  /// the user dismissed the question of an ambiguous saved view.
  Future<({String category, bool favorite})?> _destination() async {
    final view = _views.where((v) => v.id == _viewId).firstOrNull;
    if (view != null) {
      final c = view.createCategory;
      if (c != null) return (category: c, favorite: false);
      final l = AppLocalizations.of(context)!;
      final asked = await showCategoryChooser(
        context,
        tree: _index?.tree ?? const [],
        title: l.createWhere,
      );
      return asked == null ? null : (category: asked, favorite: false);
    }
    return switch (_scope) {
      NoteScope.category => (category: _category, favorite: false),
      NoteScope.favorites => (category: '', favorite: true),
      _ => (category: '', favorite: false),
    };
  }

  Future<void> _createKind(String accountId, NewKind kind) async {
    final dest = await _destination();
    if (dest == null || !mounted) return;
    switch (kind) {
      case NewKind.note:
        await _create(
          accountId,
          category: dest.category,
          favorite: dest.favorite,
        );
      case NewKind.checklist:
        await _create(
          accountId,
          content: '- [ ] ',
          category: dest.category,
          favorite: dest.favorite,
        );
      case NewKind.template:
        final hook = widget.onCreateTemplate;
        if (hook != null) {
          await hook(context, accountId, dest.category);
          return;
        }
        final template = await showTemplatePicker(context);
        if (template == null || !mounted) return;
        final runtime = ref.read(runtimeProvider);
        final id = await createFromTemplate(
          runtime,
          accountId,
          template,
          category: dest.category.isEmpty ? null : dest.category,
        );
        await _openById(accountId, id);
      case NewKind.daily:
        final hook = widget.onCreateDailyNote;
        if (hook != null) {
          await hook(context, accountId, dest.category);
          return;
        }
        final daily = await createDailyNote(
          ref.read(runtimeProvider),
          accountId,
        );
        await _openById(accountId, daily.noteId);
    }
  }

  Future<void> _openById(String accountId, String id) async {
    final note = await ref.read(runtimeProvider).database.note(accountId, id);
    if (note != null && mounted) await _edit(note);
  }

  Future<void> _newMenu(String accountId) async {
    final kind = await showNewNoteMenu(context);
    if (kind != null && mounted) await _createKind(accountId, kind);
  }

  // Navigation within the notebook ---------------------------------------

  void _go(
    NoteScope scope, {
    String category = '',
    String? viewId,
    NoteFilters filters = NoteFilters.none,
    String query = '',
  }) {
    setState(() {
      _scope = scope;
      _category = category;
      _viewId = viewId;
      _filters = filters;
      _query = query.trim();
      _selected.clear();
      if (query.isNotEmpty) {
        _searching = true;
        _searchField.text = query;
      } else if (_searching && viewId == null) {
        _searchField.clear();
      }
    });
    _scrollTop();
    final drawer = _scaffold.currentState;
    if (drawer != null && drawer.isDrawerOpen) drawer.closeDrawer();
  }

  void _scrollTop() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _onSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _query = value.trim();
        _viewId = null;
      });
      _scrollTop();
    });
    // The clear button follows the text at once, the filter a moment later.
    setState(() {});
  }

  void _openSearch() {
    setState(() => _searching = true);
    // The shortcut focus node holds focus, so the field asks for it itself.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocus.requestFocus();
    });
  }

  void _closeSearch() {
    _debounce?.cancel();
    _searchField.clear();
    setState(() {
      _searching = false;
      _query = '';
      if (_viewId == null) _filters = NoteFilters.none;
    });
    _homeFocus.requestFocus();
  }

  void _setFilters(NoteFilters filters) {
    setState(() {
      _filters = filters;
      _viewId = null;
    });
    _scrollTop();
  }

  void _escape() {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
    } else if (_searching) {
      _closeSearch();
    }
  }

  // Saved views ------------------------------------------------------------

  Future<void> _saveView() async {
    final accountId = _shown;
    if (accountId == null) return;
    final l = AppLocalizations.of(context)!;
    final name = await showNameDialog(
      context,
      title: l.saveView,
      hint: l.saveViewName,
    );
    if (name == null || !mounted) return;
    final view = SavedView(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      scope: _scope,
      category: _category,
      filters: _filters,
      query: _query,
    );
    final views = [..._views, view];
    setState(() {
      _viewsBy[accountId] = views;
      _viewId = view.id;
    });
    await _viewStore.save(accountId, views);
  }

  Future<void> _deleteView(SavedView view) async {
    final accountId = _shown;
    if (accountId == null) return;
    final views = [..._views]..removeWhere((v) => v.id == view.id);
    setState(() {
      _viewsBy[accountId] = views;
      if (_viewId == view.id) _viewId = null;
    });
    await _viewStore.save(accountId, views);
  }

  // Row and bulk actions ---------------------------------------------------

  void _toggleSelect(NoteRow row) {
    setState(() {
      if (!_selected.remove(row.note.id)) _selected.add(row.note.id);
    });
    if (_selected.length == 1) HapticFeedback.selectionClick();
  }

  List<NoteRow> get _selectedRows => [
    for (final r in _index?.rows ?? const <NoteRow>[])
      if (_selected.contains(r.note.id)) r,
  ];

  Future<void> _rowMenu(NoteRow row, {Set<RowAction>? only}) async {
    final action = await showRowMenu(
      context,
      row,
      canMove: canMove(row),
      canDelete: canDelete(row.note),
      canFavorite: canFavorite(row.note),
      only: only,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case RowAction.open:
        await _edit(row.note);
      case RowAction.favorite:
        await _favorite([row]);
      case RowAction.move:
        await _move([row]);
      case RowAction.export:
        await _export([row]);
      case RowAction.select:
        _toggleSelect(row);
      case RowAction.delete:
        await _delete([row], confirm: false);
    }
  }

  Future<void> _favorite(List<NoteRow> rows) async {
    final l = AppLocalizations.of(context)!;
    if (!rows.every((r) => canFavorite(r.note))) {
      showOwnSnackBar(context, l.bulkMixedFavorite);
      return;
    }
    final value = !rows.every((r) => r.note.favorite);
    final failed = await _actions.setFavorite([
      for (final r in rows) r.note,
    ], value);
    if (!mounted) return;
    setState(_selected.clear);
    if (failed.isNotEmpty) {
      showOwnSnackBar(context, l.bulkFailed(failed.length));
    }
  }

  Future<void> _move(List<NoteRow> rows) async {
    final l = AppLocalizations.of(context)!;
    final category = await showCategoryChooser(
      context,
      tree: _index?.tree ?? const [],
      title: l.moveTitle,
      current: rows.length == 1 ? rows.single.note.category : null,
    );
    if (category == null || !mounted) return;
    final failed = await _actions.move([
      for (final r in rows) r.note,
    ], category);
    if (!mounted) return;
    setState(_selected.clear);
    showOwnSnackBar(
      context,
      failed.isEmpty ? l.notesMoved(rows.length) : l.bulkFailed(failed.length),
    );
  }

  Future<void> _export(List<NoteRow> rows) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final notes = [for (final r in rows) r.note];
      final saved = await FilePicker.saveFile(
        fileName: 'ownnotes-export.zip',
        bytes: exportNotes(notes),
        mimeType: 'application/zip',
      );
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.exportDone(notes.length))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
    }
    if (mounted) setState(_selected.clear);
  }

  Future<void> _delete(List<NoteRow> rows, {required bool confirm}) async {
    final l = AppLocalizations.of(context)!;
    if (confirm) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(l.bulkDeleteConfirm(rows.length)),
          content: Text(l.bulkDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l.delete),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    final open = _pane.openId;
    if (open != null && rows.any((r) => r.note.id == open)) {
      if (!await _pane.close()) return;
    }
    final result = await _actions.delete([for (final r in rows) r.note]);
    if (!mounted) return;
    setState(_selected.clear);
    final deleted = result.deleted;
    if (deleted.isEmpty) {
      showOwnSnackBar(context, l.bulkFailed(result.failed.length));
      return;
    }
    showOwnSnackBar(
      context,
      result.failed.isEmpty
          ? l.notesDeleted(deleted.length)
          : '${l.notesDeleted(deleted.length)} · '
                '${l.bulkFailed(result.failed.length)}',
      actionLabel: l.undoAction,
      onAction: () => _actions.restore(deleted),
    );
  }

  // Attention actions --------------------------------------------------------

  AttentionActions _attentionActions(String accountId) {
    final runtime = ref.read(runtimeProvider);
    Future<void> open(AttentionItem item) async {
      final note =
          item.note ??
          (item.noteId == null
              ? null
              : await runtime.database.note(accountId, item.noteId!));
      if (note != null && mounted) await _edit(note);
    }

    return AttentionActions(
      onResolve: open,
      onOpen: open,
      onRetryDeletion: (item) async {
        final id = item.noteId;
        if (id == null) return;
        try {
          await runtime.sync.retryDeletion(accountId, id);
        } catch (_) {
          // The row keeps its failure state and reason.
        }
      },
      onUndoDeletion: (item) async {
        final id = item.noteId;
        if (id != null) await runtime.database.undoDelete(accountId, id);
      },
      onRetryNote: (_) => _sync(accountId),
      onSaveCopy: (item) async {
        final note = item.note;
        if (note == null) return;
        await _actions.create(
          accountId,
          title: note.title,
          content: note.content,
          category: note.category,
        );
        if (mounted) {
          showOwnSnackBar(context, AppLocalizations.of(context)!.saved);
        }
      },
    );
  }

  // Build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider);
    // The widget hides titles while the app lock is on.
    final locked = ref.watch(settingsProvider.select((s) => s.lock));
    return accounts.when(
      loading: () => Scaffold(body: _ListSkeleton(label: l.checkingForUpdates)),
      error: (_, _) => Scaffold(
        body: OwnStateView.error(
          title: l.loadFailed,
          actions: [
            OwnButton.primary(
              label: l.retry,
              onPressed: () => ref.invalidate(accountsProvider),
            ),
          ],
        ),
      ),
      data: (accounts) {
        final account =
            accounts
                .where((a) => a.id == ref.watch(selectedAccountIdProvider))
                .firstOrNull ??
            accounts.firstOrNull;
        _shown = account?.id;
        if (account == null) return _noAccount(l);
        if (_loadedFor != account.id) _switchAccount(account.id);
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
    _layout = notebookLayout(media.size.width, media.textScaler.scale(16) / 16);
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
            onSubtree: (path) => setState(() => _subtree = path),
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
    } else {
      body = Row(
        children: [
          if (inlineNav && panel != null) ...[
            SizedBox(width: navigationPaneWidth, child: panel),
            const VerticalDivider(width: 1),
          ],
          SizedBox(width: listPaneWidth, child: list),
          const VerticalDivider(width: 1),
          Expanded(child: EditorPane(controller: _pane)),
        ],
      );
    }
    final editorOnly = _layout == NotebookLayout.phone && _pane.isOpen;

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
            floatingActionButton: selecting || editorOnly
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
    _Index? index,
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
    _Index index,
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

  void _clearQuery() {
    _debounce?.cancel();
    _searchField.clear();
    setState(() => _query = '');
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
            'select' => setState(() => _selectFirst()),
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

  /// "Select notes" from the menu enters selection mode on the first row.
  void _selectFirst() {
    final first = _visible.firstOrNull;
    if (first != null) _selected.add(first.note.id);
  }

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
        onPressed: () => setState(_selected.clear),
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

  Future<void> _sortSheet() => showSortFilterSheet(
    context,
    sort: _sort,
    filters: _filters,
    onChanged: (sort, filters) {
      _setSort(sort);
      _setFilters(filters);
    },
    onSaveView: _saveView,
  );

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
        old.locked == locked &&
        old.language == l.localeName) {
      return old;
    }
    final previous = old?.accountId == accountId
        ? {for (final r in old!.rows) r.note.id: r}
        : const <String, NoteRow>{};
    final counts = <String, int>{};
    var favorites = 0;
    var uncategorised = 0;
    var shared = 0;
    for (final n in notes) {
      if (n.kind == 'shared') {
        shared++;
      } else if (n.category.isEmpty) {
        uncategorised++;
      } else {
        counts.update(n.category, (v) => v + 1, ifAbsent: () => 1);
      }
      if (n.favorite) favorites++;
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
    publishNotesWidget(
      accountId,
      notes,
      locked: locked,
      untitled: l.untitled,
      language: l.localeName,
      database: ref.read(runtimeProvider).database,
    );
    return _index = _Index(
      notes: notes,
      accountId: accountId,
      locked: locked,
      language: l.localeName,
      rows: [for (final n in notes) NoteRow.of(n, previous[n.id])],
      tree: tree,
      paths: paths,
      favorites: favorites,
      uncategorised: uncategorised,
      shared: shared,
    );
  }

  List<NoteRow> _visibleRows(
    _Index index,
    NoteScope scope,
    AppLocalizations l,
  ) {
    final key = (index, scope, _category, _filters, _query, _sort);
    if (_visibleKey == key) return _visible;
    _visibleKey = key;
    return _visible = selectRows(
      index.rows,
      scope: scope,
      category: _category,
      filters: _filters,
      query: _query,
      sort: _sort,
      untitled: l.untitled,
    );
  }
}

/// Everything derived from one list of notes, kept between builds.
class _Index {
  _Index({
    required this.notes,
    required this.accountId,
    required this.locked,
    required this.language,
    required this.rows,
    required this.tree,
    required this.paths,
    required this.favorites,
    required this.uncategorised,
    required this.shared,
  });
  final List<LocalNote> notes;
  final String accountId;
  final bool locked;
  final String language;
  final List<NoteRow> rows;
  final List<CategoryNode> tree;
  final Set<String> paths;
  final int favorites;
  final int uncategorised;
  final int shared;
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
