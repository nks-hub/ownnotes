import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/recovery.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';

class _Vault implements CredentialVault {
  final entries = <String, String>{};
  @override
  Future<void> write(String reference, String password) async {
    entries[reference] = password;
  }

  @override
  Future<String?> read(String reference) async => entries[reference];
  @override
  Future<void> delete(String reference) async {
    entries.remove(reference);
  }

  @override
  Future<Set<String>> references() async => entries.keys.toSet();
}

void main() {
  late AppRuntime runtime;
  late LocalNote note;
  var serverEtag = 'e1';
  var serverContent = 'one\nserver two\nthree';
  var readonly = false;
  var exists = true;

  Future<void> start(
    WidgetTester tester, {
    String reason = 'remote_conflict',
  }) async {
    serverEtag = 'e1';
    serverContent = 'one\nserver two\nthree';
    readonly = false;
    exists = true;
    runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        _Vault(),
        transport: () => MockClient((r) async {
          if (!exists) return http.Response('', 404);
          return http.Response(
            jsonEncode({
              'id': 7,
              'etag': serverEtag,
              'title': 'Plan',
              'content': serverContent,
              'category': '',
              'favorite': false,
              'readonly': readonly,
              'modified': 10,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    addTearDown(runtime.close);
    note = (await tester.runAsync(() async {
      final account = await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      final db = runtime.database;
      await db
          .into(db.localNotes)
          .insert(
            LocalNotesCompanion.insert(
              id: 'n1',
              accountId: account,
              title: 'Plan',
              content: 'one\ndevice two\nthree',
              remoteId: const Value(7),
              etag: const Value('e0'),
              baseContent: const Value('one\ntwo\nthree'),
              baseTitle: const Value('Plan'),
              baseCategory: const Value(''),
              baseFavorite: const Value(false),
              syncState: const Value('needsDecision'),
              updatedAt: 1,
            ),
          );
      await db
          .into(db.operations)
          .insert(
            OperationsCompanion.insert(
              id: 'op',
              accountId: account,
              noteId: 'n1',
              revision: 1,
              kind: 'update',
              payload: '{}',
              state: const Value('needsDecision'),
              errorCode: Value(reason),
            ),
          );
      return (await db.note(account, 'n1'))!;
    }))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RecoveryScreen(note: note),
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('Device, Server and an editable Result; stale server blocks', (
    tester,
  ) async {
    await start(tester);
    expect(
      find.text('Both this phone and the server changed this note.'),
      findsOneWidget,
    );
    expect(find.text('Change 1 of 1'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
    expect(find.text('Server'), findsOneWidget);
    expect(find.text('Result'), findsWidgets);
    // Both originals are stored as soon as the server version is known.
    await tester.runAsync(() async {
      final copies = await runtime.database
          .select(runtime.database.recoveryCopies)
          .get();
      expect(copies.map((c) => c.kind), unorderedEquals(['device', 'server']));
    });

    await tester.tap(find.text('Result').first);
    await settle(tester);
    final field = find.byType(TextField);
    expect(
      tester.widget<TextField>(field).controller!.text,
      'one\ndevice two\nthree',
    );
    await tester.enterText(field, 'one\nmine and theirs\nthree');
    await tester.pump();

    // The server moves on while the owner is deciding.
    serverEtag = 'e2';
    serverContent = 'one\nserver two again\nthree';
    await tester.tap(find.text('Use result'));
    await settle(tester);
    expect(find.textContaining('changed again'), findsOneWidget);
    expect(
      tester.widget<TextField>(field).controller!.text,
      'one\nmine and theirs\nthree',
    );
    await tester.runAsync(() async {
      final row = (await runtime.database.note(note.accountId, 'n1'))!;
      expect(row.syncState, 'needsDecision');
      expect(row.content, 'one\ndevice two\nthree');
    });

    // Reviewed again: the same click now applies the Result.
    await tester.tap(find.text('Use result'));
    await settle(tester);
    await tester.runAsync(() async {
      final db = runtime.database;
      final row = (await db.note(note.accountId, 'n1'))!;
      expect(row.syncState, 'draft');
      expect(row.content, 'one\nmine and theirs\nthree');
      expect(row.etag, 'e2');
      final copies = await db.select(db.recoveryCopies).get();
      expect(
        copies.map((c) => c.content),
        containsAll(['one\ndevice two\nthree', 'one\nserver two again\nthree']),
      );
    });
  });

  testWidgets('leaving keeps the unfinished Result for the next visit', (
    tester,
  ) async {
    await start(tester);
    await tester.tap(find.text('Result').first);
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'half done');
    await tester.tap(find.text('Leave unresolved'));
    await settle(tester);
    await tester.runAsync(() async {
      expect(
        await NoteRecovery(runtime.database).savedResult(note),
        'half done',
      );
      expect(
        (await runtime.database.note(note.accountId, 'n1'))!.syncState,
        'needsDecision',
      );
    });
  });

  testWidgets('server deletion offers its own choices, not Keep local', (
    tester,
  ) async {
    await start(tester, reason: 'remote_deleted');
    exists = false;
    await tester.tap(find.text('Use result'));
    await settle(tester);
    expect(find.textContaining('deleted on the server'), findsOneWidget);
    expect(find.text('Save as new note'), findsOneWidget);
    expect(find.text('Keep in recovery'), findsOneWidget);
    expect(find.text('Use result'), findsNothing);
  });

  testWidgets('permission loss keeps the text and offers an own copy', (
    tester,
  ) async {
    await start(tester);
    readonly = true;
    serverEtag = 'e1';
    await tester.tap(find.text('Use result'));
    await settle(tester);
    expect(find.textContaining('no longer lets you edit'), findsWidgets);
    expect(find.text('Save as new note'), findsOneWidget);
    expect(find.text('Use result'), findsNothing);
    await tester.runAsync(() async {
      expect(
        (await runtime.database.note(note.accountId, 'n1'))!.content,
        'one\ndevice two\nthree',
      );
    });
  });

  testWidgets('attachment move: the way out follows the server category', (
    tester,
  ) async {
    await start(tester, reason: 'move_integrity_required');
    expect(find.text('Use result, keep server category'), findsOneWidget);
    expect(find.textContaining('cannot change its category'), findsOneWidget);
  });

  testWidgets('phone layout at 200% text keeps every action reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(411 * 2.6, 800 * 2.6);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await start(tester);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Keep as separate note'));
    expect(find.text('Keep as separate note'), findsOneWidget);
    expect(find.text('Use server version'), findsOneWidget);
  });
}

Future<void> settle(WidgetTester tester) => tester.runAsync(() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 50));
  }
});
