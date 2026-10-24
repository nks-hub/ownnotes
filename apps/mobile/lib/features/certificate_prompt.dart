import 'package:flutter/material.dart';
import 'package:notes_protocol/notes_protocol.dart';

import '../l10n/app_localizations.dart';

Future<bool> confirmServerCertificate(
  BuildContext context,
  CertificateEncounter encounter,
) async {
  final strings = AppLocalizations.of(context)!;
  final changed =
      encounter.outcome.refusal == CertificateRefusal.pinnedFingerprintMismatch;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('certificate-trust-dialog'),
          scrollable: true,
          title: Text(
            changed
                ? strings.certificateChangedTitle
                : strings.certificateUnverifiedTitle,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                changed
                    ? strings.certificateChangedBody(encounter.host)
                    : strings.certificateUnverifiedBody(encounter.host),
              ),
              const SizedBox(height: 16),
              Text(
                strings.certificateFingerprintLabel,
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              SelectableText(
                RegExp(r'.{2}')
                    .allMatches(encounter.fingerprint)
                    .map((m) => m.group(0)!)
                    .join(':')
                    .toUpperCase(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(changed ? strings.close : strings.cancel),
            ),
            if (encounter.outcome.decision == CertificateTrustDecision.ask)
              FilledButton(
                key: const Key('certificate-trust-confirm'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(strings.certificateTrustAction),
              ),
          ],
        ),
      ) ??
      false;
}
