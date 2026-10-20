import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import '../data/account_api.dart';
import '../data/export.dart';
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

/// Called before the account switches: it must persist the open draft and
/// return whether that worked. A failed save keeps the user where they are.
typedef BeforeSwitch = Future<bool> Function();

enum _SwitcherAction { add, manage }

/// Account switcher: a bottom sheet on phones, a popover in the top corner on
/// wide windows. Switching, adding and the "Manage accounts" route are handled
/// here; [beforeSwitch] saves the open draft first.
Future<void> showAccountSwitcher(
  BuildContext context, {
  required String currentId,
  BeforeSwitch? beforeSwitch,
}) async {
  final container = ProviderScope.containerOf(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final l = AppLocalizations.of(context)!;
  final wide = MediaQuery.sizeOf(context).width >= 600;
  Widget body(BuildContext _) => UncontrolledProviderScope(
    container: container,
    child: _SwitcherBody(currentId: currentId),
  );
  final Object? choice = wide
      ? await showDialog<Object>(
          context: context,
          barrierColor: Colors.transparent,
          builder: (dialog) => Align(
            alignment: AlignmentDirectional.topEnd,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Material(
                  elevation: 3,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(dialog).colorScheme.surfaceContainerHigh,
                  child: body(dialog),
                ),
              ),
            ),
          ),
        )
      : await showModalBottomSheet<Object>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: body,
        );
  if (choice == null || !navigator.mounted) return;
  switch (choice) {
    case Account(:final id):
      if (id == currentId) return;
      if (beforeSwitch != null && !await beforeSwitch()) {
        messenger.showSnackBar(SnackBar(content: Text(l.accountSwitchBlocked)));
        return;
      }
      container.read(selectedAccountIdProvider.notifier).state = id;
    case _SwitcherAction.add:
      await navigator.push<void>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/login'),
          builder: (_) => const LoginScreen(),
        ),
      );
    case _SwitcherAction.manage:
      await navigator.push<String>(
        MaterialPageRoute(
          settings: const RouteSettings(name: '/accounts'),
          builder: (_) => AccountsScreen(currentId: currentId),
        ),
      );
    default:
  }
}

class _SwitcherBody extends ConsumerWidget {
  const _SwitcherBody({required this.currentId});
  final String currentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final accounts = ref.watch(accountsProvider).valueOrNull ?? const [];
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Semantics(
                header: true,
                child: Text(
                  l.switchAccount,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            for (final a in accounts)
              _AccountRow(
                account: a,
                selected: a.id == currentId,
                onTap: () => Navigator.of(context).pop(a),
              ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.add),
              title: Text(l.addAccount),
              onTap: () => Navigator.of(context).pop(_SwitcherAction.add),
            ),
            ListTile(
              leading: const Icon(Icons.manage_accounts_outlined),
              title: Text(l.accountsManage),
              onTap: () => Navigator.of(context).pop(_SwitcherAction.manage),
            ),
          ],
        ),
      ),
    );
  }
}

extension on Account {
  String get host => Uri.parse(server).host;
}

/// Name, `user · host`, selection and a repair hint; identical user names on
/// different servers stay apart through the host.
class _AccountRow extends ConsumerWidget {
  const _AccountRow({
    required this.account,
    required this.selected,
    required this.onTap,
  });
  final Account account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    final reauth = account.state == 'reauthRequired';
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.secondaryContainer,
      leading: AccountAvatar(account: account, name: name),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        reauth
            ? '${account.loginName} · ${account.host}\n${l.reasonAuth}'
            : '${account.loginName} · ${account.host}',
        style: reauth ? TextStyle(color: scheme.error) : null,
      ),
      isThreeLine: reauth,
      trailing: selected
          ? Icon(
              Icons.check,
              color: scheme.primary,
              semanticLabel: l.currentAccount,
            )
          : null,
      onTap: onTap,
    );
  }
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, required this.name});
  final Account account;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hue = account.id.codeUnits.fold<int>(0, (a, c) => (a * 31 + c) % 360);
    return CircleAvatar(
      backgroundColor: HSLColor.fromAHSL(
        1,
        hue.toDouble(),
        0.45,
        0.38,
      ).toColor(),
      foregroundColor: Colors.white,
      child: Text(accountInitials(name)),
    );
  }
}

enum _DetailAction { signInAgain, remove }

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

  Future<void> _details(Account account) async {
    final action = await showModalBottomSheet<_DetailAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AccountDetails(account: account),
    );
    if (!mounted) return;
    switch (action) {
      case _DetailAction.signInAgain:
        await _signInAgain(account);
      case _DetailAction.remove:
        await _remove(account);
      case null:
    }
  }

  Future<void> _exportUnsent(Account account, List<LocalNote> unsent) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await FilePicker.saveFile(
        fileName: 'ownnotes-${account.loginName}-unsent.zip',
        bytes: exportNotes(unsent),
        mimeType: 'application/zip',
      );
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l.exportDone(unsent.length))),
        );
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l.exportFailed)));
    }
  }

  Future<void> _remove(Account account) async {
    final l = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    // Notes never uploaded exist only on this phone; say how many would go.
    final notes = await ref.read(notesProvider(account.id).future);
    final unsent = notes.where((n) => n.syncState != 'clean').toList();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${account.loginName} · ${account.host}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                unsent.isEmpty
                    ? l.removeAccountConfirm
                    : l.removeAccountUnsent(unsent.length),
              ),
              const SizedBox(height: 12),
              Text(l.removeLocalNote),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          if (unsent.isNotEmpty)
            TextButton(
              onPressed: () => _exportUnsent(account, unsent),
              child: Text(l.exportUnsent),
            ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.removeFromDevice),
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
                      onDetails: () => _details(account),
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
    required this.onDetails,
    required this.onRemove,
    required this.onSignInAgain,
  });
  final Account account;
  final bool isCurrent;
  final bool removing;
  final VoidCallback onSwitch;
  final VoidCallback onDetails;
  final VoidCallback onRemove;
  final VoidCallback onSignInAgain;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    final reauth = account.state == 'reauthRequired';
    return ListTile(
      selected: isCurrent,
      leading: AccountAvatar(account: account, name: name),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        reauth
            ? '${account.loginName} · ${account.host}\n${l.reasonAuth}'
            : '${account.loginName} · ${account.host}',
        style: reauth ? TextStyle(color: scheme.error) : null,
      ),
      isThreeLine: reauth,
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
                PopupMenuButton<int>(
                  onSelected: (i) => switch (i) {
                    0 => onDetails(),
                    1 => onSignInAgain(),
                    _ => onRemove(),
                  },
                  itemBuilder: (_) => [
                    _menuItem(0, Icons.info_outline, l.accountDetails),
                    _menuItem(1, Icons.login_outlined, l.signInAgain),
                    _menuItem(2, Icons.delete_outline, l.removeFromDevice),
                  ],
                ),
              ],
            ),
    );
  }
}

PopupMenuItem<int> _menuItem(int value, IconData icon, String label) =>
    PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 16),
          Flexible(child: Text(label)),
        ],
      ),
    );

class _AccountDetails extends ConsumerWidget {
  const _AccountDetails({required this.account});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name =
        ref.watch(accountDisplayNameProvider(account)).valueOrNull ??
        account.loginName;
    final notes = ref.watch(notesProvider(account.id)).valueOrNull;
    final unsent = notes?.where((n) => n.syncState != 'clean').length ?? 0;
    final reauth = account.state == 'reauthRequired';
    Widget fact(String label, String value, {Color? color}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(color: color)),
        ],
      ),
    );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                AccountAvatar(account: account, name: name),
                const SizedBox(width: 16),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(name, style: theme.textTheme.titleLarge),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            fact(l.accountUserLabel, account.loginName),
            fact(l.accountServerLabel, account.server),
            fact(
              l.accountStatusLabel,
              reauth ? l.reasonAuth : l.accountSignedIn,
              color: reauth ? scheme.error : null,
            ),
            if (notes != null)
              fact(
                l.storageNotes(notes.length),
                l.storageUnsent(unsent),
                color: unsent > 0 ? scheme.error : null,
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.login_outlined),
              onPressed: () =>
                  Navigator.of(context).pop(_DetailAction.signInAgain),
              label: Text(l.signInAgain),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => Navigator.of(context).pop(_DetailAction.remove),
              label: Text(l.removeFromDevice),
            ),
          ],
        ),
      ),
    );
  }
}
