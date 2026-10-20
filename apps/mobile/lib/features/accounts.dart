import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import '../data/account_api.dart';
import '../data/notes_widget.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';
import 'login.dart';

/// The account the note list shows; null means the first one. Set by
/// [AccountsScreen] when the user switches.
final selectedAccountIdProvider = StateProvider<String?>((ref) => null);

/// Test seam: where account calls get their HTTP client from. Each call opens
/// and closes its own client.
final accountTransportProvider = Provider<http.Client Function()>(
  (ref) => http.Client.new,
);

/// Server-side display name, null while unknown or when the server is
/// unreachable; the list falls back to the login name.
final accountDisplayNameProvider = FutureProvider.autoDispose
    .family<String?, Account>((ref, account) async {
      final password = await ref
          .read(runtimeProvider)
          .vault
          .read(account.credentialRef);
      if (password == null) return null;
      final client = ref.read(accountTransportProvider)();
      try {
        return await AccountApi(client).displayName(
          ServerBase.parse(account.server),
          account.loginName,
          password,
        );
      } finally {
        client.close();
      }
    });

/// Opens the account list and returns the id the user switched to, if any.
Future<String?> openAccounts(BuildContext context, {String? currentId}) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/accounts'),
        builder: (_) => AccountsScreen(currentId: currentId),
      ),
    );

/// Revokes the app password on the server while it is still valid, then wipes
/// the account from this phone. The server step is best effort, since people
/// often remove an account because the server is gone or the password was
/// already revoked; it never blocks the local wipe. Returns whether the
/// server confirmed the revocation.
Future<bool> removeAccountEverywhere(
  AppRuntime runtime,
  Account account,
  http.Client Function() transport,
) async {
  var revoked = false;
  final password = await runtime.vault.read(account.credentialRef);
  if (password != null) {
    final client = transport();
    try {
      await AccountApi(
        client,
      ).revoke(ServerBase.parse(account.server), account.loginName, password);
      revoked = true;
    } catch (_) {
      // Deliberately silent: the request carries the app password.
    } finally {
      client.close();
    }
  }
  await runtime.accounts.remove(account.id);
  await clearNotesWidget(account.id);
  return revoked;
}

String accountInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'[\s._@-]+'))
      .where((w) => w.isNotEmpty);
  final letters = words.take(2).map((w) => String.fromCharCode(w.runes.first));
  final text = letters.join().toUpperCase();
  return text.isEmpty ? '?' : text;
}

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key, this.currentId});

  /// Highlighted account when nothing was switched yet.
  final String? currentId;
  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _removing = <String>{};

  Future<void> _add() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      settings: const RouteSettings(name: '/login'),
      builder: (_) => const LoginScreen(),
    ),
  );

  Future<void> _signInAgain(Account account) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/login'),
          builder: (_) => LoginScreen(reauthenticate: account),
        ),
      );

  Future<void> _remove(Account account) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // Notes never uploaded exist only on this phone; say how many would go.
    final notes = await ref.read(notesProvider(account.id).future);
    final unsent = notes.where((n) => n.syncState != 'clean').length;
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${account.loginName} · ${Uri.parse(account.server).host}'),
        content: Text(
          unsent == 0 ? l.removeAccountConfirm : l.removeAccountUnsent(unsent),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.removeAccount),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _removing.add(account.id));
    try {
      final revoked = await removeAccountEverywhere(
        ref.read(runtimeProvider),
        account,
        ref.read(accountTransportProvider),
      );
      final selected = ref.read(selectedAccountIdProvider);
      if (selected == account.id) {
        ref.read(selectedAccountIdProvider.notifier).state = null;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            revoked ? l.accountRemovedRevoked : l.accountRemovedNotRevoked,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.accountRemoveFailed)));
    } finally {
      if (mounted) setState(() => _removing.remove(account.id));
    }
  }

  void _switch(Account account) {
    ref.read(selectedAccountIdProvider.notifier).state = account.id;
    Navigator.of(context).pop(account.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider);
    final selected = ref.watch(selectedAccountIdProvider) ?? widget.currentId;
    return Scaffold(
      appBar: AppBar(title: Text(l.accounts)),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(l.loadFailed)),
        data: (accounts) {
          final current =
              accounts.where((a) => a.id == selected).firstOrNull ??
              accounts.firstOrNull;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                children: [
                  if (accounts.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.noAccounts, textAlign: TextAlign.center),
                    ),
                  for (final account in accounts)
                    _AccountTile(
                      key: ValueKey(account.id),
                      account: account,
                      isCurrent: account.id == current?.id,
                      removing: _removing.contains(account.id),
                      onSwitch: () => _switch(account),
                      onRemove: () => _remove(account),
                      onSignInAgain: () => _signInAgain(account),
                    ),
                  const Divider(),
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.add)),
                    title: Text(l.addAccount),
                    onTap: _add,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({
    super.key,
    required this.account,
    required this.isCurrent,
    required this.removing,
    required this.onSwitch,
    required this.onRemove,
    required this.onSignInAgain,
  });
  final Account account;
  final bool isCurrent;
  final bool removing;
  final VoidCallback onSwitch;
  final VoidCallback onRemove;
  final VoidCallback onSignInAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    final host = Uri.parse(account.server).host;
    final hue = account.id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) % 360);
    return ListTile(
      selected: isCurrent,
      leading: CircleAvatar(
        backgroundColor: HSLColor.fromAHSL(
          1,
          hue.toDouble(),
          0.45,
          0.38,
        ).toColor(),
        foregroundColor: Colors.white,
        child: Text(accountInitials(name)),
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        account.state == 'reauthRequired'
            ? '${account.loginName} · $host\n${l.reasonAuth}'
            : '${account.loginName} · $host',
        style: account.state == 'reauthRequired'
            ? TextStyle(color: scheme.error)
            : null,
      ),
      isThreeLine: account.state == 'reauthRequired',
      onTap: removing || isCurrent ? null : onSwitch,
      trailing: removing
          ? const SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCurrent)
                  Icon(
                    Icons.check_circle,
                    color: scheme.primary,
                    semanticLabel: l.currentAccount,
                  ),
                PopupMenuButton<bool>(
                  onSelected: (remove) => remove ? onRemove() : onSignInAgain(),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: false, child: Text(l.signInAgain)),
                    PopupMenuItem(value: true, child: Text(l.removeAccount)),
                  ],
                ),
              ],
            ),
    );
  }
}
