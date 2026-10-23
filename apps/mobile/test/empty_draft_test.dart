import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/attachment_service.dart';
import 'package:nextcloudnotes/data/attachments/providers.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/editor.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/transfer_fixtures.dart';
import 'transfers_ui_test.dart' show until;

void main() {
  for (final scenario in [
    'empty',
    'queued file',
    'unreadable staging',
    'corrupt metadata',
  ]) {
    testWidgets('closing a new draft with $scenario preserves accepted files', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final env = (await tester.runAsync(TransferEnv.create))!;
      addTearDown(env.dispose);
      String? stagedPath;
      final note = (await tester.runAsync(() async {
        final id = await env.db.createDraft(env.accountId);
        if (scenario == 'queued file' || scenario == 'corrupt metadata') {
          final item = await env.service.stage(
            accountId: env.accountId,
            noteId: id,
            source: await env.file('pending.png'),
            name: 'pending.png',
          );
          expect(await env.service.upload(item.id), isA<WaitingForNote>());
          stagedPath = env.service.staging.dataFile(item.id).path;
          if (scenario == 'corrupt metadata') {
            await File(
              '${env.service.staging.root.path}/${item.id}/meta.json',
            ).writeAsString('{broken');
          }
        }
        return (await env.db.note(env.accountId, id))!;
      }))!;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runtimeProvider.overrideWithValue(env.runtime),
            attachmentServiceProvider.overrideWith((_) async {
              if (scenario == 'unreadable staging') {
                throw const FileSystemException('staging unavailable');
              }
              return env.service;
            }),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
                  ),
                  child: const Text('Open draft'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open draft'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await until(tester, () => find.text('Open draft').evaluate().isNotEmpty);
      final saved = await tester.runAsync(
        () => env.db.note(env.accountId, note.id),
      );
      expect(saved, scenario == 'empty' ? isNull : isNotNull);
      if (scenario == 'queued file') {
        final item = (await tester.runAsync(
          () => env.service.pending(env.accountId, note.id),
        ))!.single;
        expect(
          await tester.runAsync(
            () => env.service.staging.dataFile(item.id).readAsBytes(),
          ),
          [1, 2, 3],
        );
        expect(env.server.uploads, isEmpty);
      }
      if (stagedPath != null) {
        expect(await tester.runAsync(() => File(stagedPath!).readAsBytes()), [
          1,
          2,
          3,
        ]);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
