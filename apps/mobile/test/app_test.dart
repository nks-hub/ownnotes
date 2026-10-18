import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:ownnotes/data/runtime.dart';
import 'package:ownnotes/main.dart';

class Vault implements CredentialVault {
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
  testWidgets('empty state offers account onboarding', (tester) async {
    final runtime = (await tester.runAsync(() async {
      final runtime = AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
      );
      await runtime.initialize().timeout(const Duration(seconds: 5));
      return runtime;
    }))!;
    addTearDown(runtime.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('Connect your Nextcloud account.'), findsOneWidget);
    await tester.tap(find.byTooltip('Add account'));

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('Nextcloud server URL'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('HTTP pull reaches SQLite and UI; editor persists raw Markdown', (
    tester,
  ) async {
    final runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), Vault()),
    ))!;
    final db = runtime.database;
    addTearDown(runtime.close);
    final id = (await tester.runAsync(
      () => runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      ),
    ))!;
    final sync = SyncCoordinator(
      db,
      (_) async => NotesClient(
        base: ServerBase.parse('https://cloud.test'),
        loginName: 'test',
        appPassword: 'secret',
        transport: MockClient(
          (r) async => http.Response(
            jsonEncode([
              {
                'id': 7,
                'etag': 'etag1',
                'title': 'From HTTP',
                'content': '# original',
                'category': '',
                'favorite': false,
                'readonly': false,
                'modified': 10,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    );
    await tester.runAsync(() => sync.sync(id));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('From HTTP'), findsOneWidget);
    await tester.tap(find.text('From HTTP'));

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    final field = find.byWidgetPredicate((w) => w is TextField && w.expands);
    await tester.enterText(field, '# modified\n\n🙂 **raw**');
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    await tester.runAsync(() async {
      final notes = await db.select(db.localNotes).get();
      expect(notes.single.content, '# modified\n\n🙂 **raw**');
      expect(notes.single.syncState, 'draft');
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
