import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_store/notes_store.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';
import 'editor.dart';
import 'login.dart';
import 'recovery.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _selected;
  String? _shown;
  String _search = '';
  bool _busy = false;
  String? _again;
  final _autoSynced = <String>{};
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        final id = _shown;
        if (id != null) _sync(id, quiet: true);
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  /// Quiet runs are automatic (start, resume, after editing); offline is
  /// normal there, so only a manual sync reports failure.
  Future<void> _sync(String accountId, {bool quiet = false}) async {
    if (_busy) {
      // The running pass may have started before the latest local edit.
      _again = accountId;
      return;
    }
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
      if (mounted) setState(() => _busy = false);
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

  Future<void> _create(String accountId) async {
    try {
      final db = ref.read(runtimeProvider).database;
      final id = await db.createDraft(accountId);
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
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _sync(account.id, quiet: true),
          );
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
                                  final filtered = notes
                                      .where(
                                        (n) =>
                                            '${n.title}\n${n.content}\n${n.category}'
                                                .toLowerCase()
                                                .contains(_search),
                                      )
                                      .toList();
                                  if (filtered.isEmpty) {
                                    return _EmptyText(l.noNotes);
                                  }
                                  return ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final n = filtered[index];
                                      return ListTile(
                                        key: ValueKey(n.id),
                                        minVerticalPadding: 16,
                                        title: Text(
                                          n.title.isEmpty
                                              ? l.untitled
                                              : n.title,
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
                                            : const Icon(
                                                Icons.cloud_upload_outlined,
                                              ),
                                        onTap: () => _edit(n),
                                      );
                                    },
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
