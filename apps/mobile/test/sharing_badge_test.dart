import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/design/design.dart';
import 'package:nextcloudnotes/features/editor/share_sheet.dart';
import 'package:nextcloudnotes/features/note_rows.dart';
import 'package:nextcloudnotes/features/note_tile.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

import 'app_test.dart' show Vault;

void main() {
  testWidgets('a public share is marked without claiming there are no shares', (
    tester,
  ) async {
    final runtime = AppRuntime(
      NotesDatabase(NativeDatabase.memory()),
      Vault(),
      transport: () => MockClient(
        (r) async => http.Response(
          jsonEncode(
            r.url.path.endsWith('/shares')
                ? {
                    'ocs': {
                      'meta': {'statuscode': 200},
                      'data': [
                        {'share_type': 3},
                      ],
                    },
                  }
                : {
                    'id': 7,
                    'etag': 'e',
                    'title': 'Plan',
                    'content': 'body',
                    'category': '',
                    'favorite': false,
                    'readonly': false,
                    'modified': 1,
                    'internalPath': '/Notes/Plan.md',
                  },
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(runtime.close);
    final note = (await tester.runAsync(() async {
      final accountId = await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      await runtime.database
          .into(runtime.database.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: 'note',
              accountId: accountId,
              title: 'Plan',
              content: 'body',
              updatedAt: 1,
              remoteId: const Value(7),
              syncState: const Value('clean'),
            ),
          );
      return (await runtime.database.note(accountId, 'note'))!;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: MaterialApp(
          locale: const Locale('en'),
          theme: OwnTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ShareSheetBody(
              note: note,
              title: note.title,
              text: () => note.content,
              flush: () async => fail('an uploaded note does not need a flush'),
              hasAttachments: false,
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(find.textContaining('other sharing methods'), findsOneWidget);
    expect(find.text('Not shared with anyone yet.'), findsNothing);
    final saved = await tester.runAsync(
      () => runtime.database.note(note.accountId, note.id),
    );
    expect(saved!.sharedByMe, isTrue);
    expect(saved.kind, 'note');
    expect(saved.content, note.content);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('Czech outgoing badge fits a narrow row at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const note = LocalNote(
      id: 'n',
      accountId: 'a',
      title: 'Plan',
      content: 'text',
      category: '',
      favorite: false,
      readonly: false,
      revision: 1,
      syncState: 'clean',
      updatedAt: 1,
      kind: 'note',
      sharedByMe: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('cs'),
        theme: OwnTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: NoteTile(
            row: NoteRow.of(note),
            showCategory: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sdílíš s ostatními'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
