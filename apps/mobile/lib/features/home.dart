import 'dart:async';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/background.dart';
import '../data/keep_import.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';
import 'editor.dart';
import 'login.dart';
import 'recovery.dart';
import 'settings.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selected;
  String? _shown;
  String? _category;
  String _search = '';
  bool _busy = false;
  String? _again;
  bool _byTitle = false;
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
  }

  @override
  void dispose() {
    _share.setMethodCallHandler(null);
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
  }) async {
    try {
      final db = ref.read(runtimeProvider).database;
      final id = await db.createDraft(
        accountId,
        title: title,
        content: content,
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
    return accounts.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, _) => Scaffold(body: Center(child: Text(l.loadFailed))),
      data: (accounts) {
        final account =
            accounts.where((a) => a.id == _selected).firstOrNull ??
            accounts.firstOrNull;
        _shown = account?.id;
        if (account != null && _autoSynced.add(account.id)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _sync(account.id, quiet: true);
            _takeShared();
          });
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(l.appTitle),
            actions: [
              if (account != null)
                IconButton(
                  tooltip: l.sync,
                  onPressed: _busy ? null : () => _sync(account.id),
                  icon: const Icon(Icons.sync),
                ),
              IconButton(
                tooltip: l.addAccount,
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    settings: const RouteSettings(name: '/login'),
                    builder: (_) => const LoginScreen(),
                  ),
                ),
                icon: const Icon(Icons.person_add_outlined),
              ),
              if (account != null)
                PopupMenuButton<void>(
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/settings'),
                          builder: (_) => SettingsScreen(account: account),
                        ),
                      ),
                      child: Text(l.settings),
                    ),
                    PopupMenuItem(
                      onTap: _toggleSort,
                      child: Text(_byTitle ? l.sortByModified : l.sortByTitle),
                    ),
                    PopupMenuItem(
                      onTap: () => _importKeep(account.id),
                      child: Text(l.importKeep),
                    ),
                  ],
                ),
            ],
          ),
          floatingActionButton: account == null
              ? null
              : FloatingActionButton(
                  tooltip: l.newNote,
                  onPressed: () => _create(account.id),
                  child: const Icon(Icons.add),
                ),
          body: account == null
              ? _EmptyText(l.noAccounts)
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Column(
                      children: [
                        if (_busy) const LinearProgressIndicator(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: account.id,
                            items: accounts
                                .map(
                                  (a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(
                                      '${a.loginName} · ${Uri.parse(a.server).host}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: _busy
                                ? null
                                : (id) => setState(() => _selected = id),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: l.search,
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (value) =>
                                setState(() => _search = value.toLowerCase()),
                          ),
                        ),
                        Expanded(
                          child: ref
                              .watch(notesProvider(account.id))
                              .when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                error: (_, _) =>
                                    Center(child: Text(l.loadFailed)),
                                data: (notes) {
                                  final categories =
                                      notes
                                          .map((n) => n.category)
                                          .where((c) => c.isNotEmpty)
                                          .toSet()
                                          .toList()
                                        ..sort();
                                  final category =
                                      categories.contains(_category)
                                      ? _category
                                      : null;
                                  final filtered = notes
                                      .where(
                                        (n) =>
                                            (category == null ||
                                                n.category == category ||
                                                n.category.startsWith(
                                                  '$category/',
                                                )) &&
                                            '${n.title}\n${n.content}\n${n.category}'
                                                .toLowerCase()
                                                .contains(_search),
                                      )
                                      .toList();
                                  if (_byTitle) {
                                    filtered.sort(
                                      (a, b) => _shownTitle(a, l)
                                          .toLowerCase()
                                          .compareTo(
                                            _shownTitle(b, l).toLowerCase(),
                                          ),
                                    );
                                  }
                                  final unsent = notes
                                      .where(
                                        (n) =>
                                            n.syncState == 'draft' ||
                                            n.syncState == 'sending',
                                      )
                                      .length;
                                  final problem = ref
                                      .read(runtimeProvider)
                                      .sync
                                      .problem(account.id);
                                  final list = filtered.isEmpty
                                      ? ListView(
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          children: [_EmptyText(l.noNotes)],
                                        )
                                      : _list(filtered, l);
                                  return Column(
                                    children: [
                                      if (unsent > 0 && !_busy)
                                        ListTile(
                                          leading: const Icon(
                                            Icons.cloud_off_outlined,
                                          ),
                                          title: Text(l.unsent(unsent)),
                                          subtitle: problem == null
                                              ? null
                                              : Text(_reason(problem, l)),
                                        ),
                                      if (categories.isNotEmpty)
                                        SizedBox(
                                          height: 56,
                                          child: ListView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                            ),
                                            children: [
                                              for (final c in [
                                                null,
                                                ...categories,
                                              ])
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8,
                                                      ),
                                                  child: ChoiceChip(
                                                    label: Text(
                                                      c ?? l.allCategories,
                                                    ),
                                                    selected: c == category,
                                                    onSelected: (_) => setState(
                                                      () => _category = c,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      Expanded(
                                        child: RefreshIndicator(
                                          onRefresh: () => _sync(account.id),
                                          child: list,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
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

  Widget _list(List<LocalNote> filtered, AppLocalizations l) =>
      ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final n = filtered[index];
          return ListTile(
            key: ValueKey(n.id),
            minVerticalPadding: 16,
            title: Text(
              _shownTitle(n, l),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              n.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            leading: Icon(
              n.syncState == 'needsDecision'
                  ? Icons.warning_amber
                  : n.favorite
                  ? Icons.star
                  : Icons.description_outlined,
            ),
            trailing: n.syncState == 'clean'
                ? null
                : const Icon(Icons.cloud_upload_outlined),
            onTap: () => _edit(n),
          );
        },
      );
}

class _EmptyText extends StatelessWidget {
  const _EmptyText(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
