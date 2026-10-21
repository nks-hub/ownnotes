import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart' show Account;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/runtime.dart';
import '../l10n/app_localizations.dart';
import 'accounts.dart';
import 'login.dart';

const _website = 'https://ownnotes.nks-hub.cz/';
const _privacy = 'https://ownnotes.nks-hub.cz/p/soukromi';
const _support = 'dev@nks-hub.cz';

/// Nextcloud and Notes versions of the account's server; null values when it
/// does not say, an error when it cannot be reached.
final serverVersionsProvider = FutureProvider.autoDispose
    .family<({String? nextcloud, String? notes}), Account>((ref, account) async {
      final password = await ref
          .read(runtimeProvider)
          .vault
          .read(account.credentialRef);
      if (password == null) throw StateError('reauth_required');
      final transport = ref.read(accountTransportProvider)();
      try {
        return await AttachmentsClient(
          base: ServerBase.parse(account.server),
          transport: transport,
          loginName: account.loginName,
          appPassword: password,
          route: AttachmentRoute.legacy,
        ).versions();
      } finally {
        transport.close();
      }
    });

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

/// What the app is, which version runs, the server it talks to, and where to
/// get help.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({required this.account, super.key});
  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final info = ref.watch(packageInfoProvider).valueOrNull;
    final version = info == null
        ? ''
        : l.aboutVersion(info.version, info.buildNumber);
    final server = ref.watch(serverVersionsProvider(account));
    final host = Uri.parse(account.server).host;

    void open(String url) =>
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsAbout)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const SizedBox(height: 24),
            const Center(child: BrandMark(size: 72)),
            const SizedBox(height: 12),
            Text(
              l.appTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (version.isNotEmpty)
              Text(
                version,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Text(
                l.onboardingBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(l.aboutFormatTitle),
              subtitle: Text(l.aboutFormatBody),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text('${l.aboutServer} · $host'),
              subtitle: Text(
                server.when(
                  loading: () => '…',
                  error: (_, _) => l.aboutServerUnknown,
                  data: (v) {
                    final parts = [
                      if (v.nextcloud != null) 'Nextcloud ${v.nextcloud}',
                      if (v.notes != null) 'Notes ${v.notes}',
                    ];
                    return parts.isEmpty
                        ? l.aboutServerUnknown
                        : parts.join(' · ');
                  },
                ),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.public),
              title: Text(l.aboutWebsite),
              subtitle: const Text('ownnotes.nks-hub.cz'),
              onTap: () => open(_website),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(l.aboutPrivacy),
              onTap: () => open(_privacy),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(l.aboutSupport),
              subtitle: const Text(_support),
              // The version in the subject saves asking for it.
              onTap: () => open(
                Uri(
                  scheme: 'mailto',
                  path: _support,
                  query: 'subject=${Uri.encodeComponent('OwnNotes $version')}',
                ).toString(),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.gavel_outlined),
              title: Text(l.aboutLicenses),
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appTitle,
                applicationVersion: version,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(8),
                  child: BrandMark(size: 64),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l.aboutCopyright,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
