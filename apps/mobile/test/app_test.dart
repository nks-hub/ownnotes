import 'dart:convert';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/main.dart';

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
  testWidgets('text shared from another app becomes a new note', (
    tester,
  ) async {
    var shared = <String, String>{
      'title': 'From Keep',
      'text': '- [ ] milk\n- [x] bread',
    };
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.nkshub.nextcloudnotes/share'),
      (call) async {
        final value = shared;
        shared = const {};
        return value.isEmpty ? null : value;
      },
    );
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient(
          (r) async => http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      ),
    ))!;
    addTearDown(runtime.close);
    await tester.runAsync(
      () => runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );
    await tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });

    expect(find.widgetWithText(TextField, 'From Keep'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, '- [ ] milk\n- [x] bread'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      final db = runtime.database;
      final note = await db.select(db.localNotes).getSingle();
      expect(note.title, 'From Keep');
      expect(note.content, '- [ ] milk\n- [x] bread');
    });

    // A share without a subject takes its title from the first text line.
    // Shared while the first editor is still open.
    shared = {'title': '', 'text': '\n  Call the garage  \nabout tyres'};
    await tester.runAsync(() async {
      // Not awaited: the handler only returns once the opened editor closes.
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.nkshub.nextcloudnotes/share',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('shared'),
        ),
        (_) {},
      );
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(() async {
      final db = runtime.database;
      final titles = (await db.select(db.localNotes).get()).map((n) => n.title);
      expect(titles, containsAll(['From Keep', 'Call the garage']));
    });
    expect(find.widgetWithText(TextField, 'Call the garage'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('deleting from the editor removes the note on the server', (
    tester,
  ) async {
    final requests = <String>[];
    var exists = true;
    final note = {
      'id': 7,
      'etag': 'etag1',
      'title': 'From HTTP',
      'content': '# original',
      'category': '',
      'favorite': false,
      'readonly': false,
      'modified': 10,
    };
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          requests.add('${r.method} ${r.url.pathSegments.last}');
          if (r.method == 'DELETE') exists = false;
          if (r.method == 'GET' && r.url.pathSegments.last == '7') {
            return http.Response('', 304);
          }
          return http.Response(
            jsonEncode(r.method == 'DELETE' || !exists ? [] : [note]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    addTearDown(runtime.close);
    await tester.runAsync(
      () => runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      ),
    );
    Future<void> settle() => tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump(const Duration(milliseconds: 100));
      }
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );
    await settle();
    await tester.tap(find.text('From HTTP'));
    await settle();
    await tester.tap(find.byTooltip('Delete'));
    await settle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await settle();

    expect(requests, contains('DELETE 7'));
    expect(find.text('From HTTP'), findsNothing);
    await tester.runAsync(() async {
      final db = runtime.database;
      expect(await db.select(db.localNotes).get(), isEmpty);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('opening pulls without a tap; leaving the editor uploads', (
    tester,
  ) async {
    final requests = <String>[];
    var etag = 'etag1';
    var content = '# original';
    Map<String, Object> note() => {
      'id': 7,
      'etag': etag,
      'title': 'From HTTP',
      'content': content,
      'category': '',
      'favorite': false,
      'readonly': false,
      'modified': 10,
    };
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          if (r.method == 'PUT') {
            expect(r.headers['If-Match'], '"$etag"');
            content = (jsonDecode(r.body) as Map)['content'] as String;
            etag = 'etag2';
          }
          return http.Response(
            jsonEncode(r.url.pathSegments.last == 'notes' ? [note()] : note()),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    addTearDown(runtime.close);
    await tester.runAsync(
      () => runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      ),
    );
    Future<void> settle() => tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );
    await settle();
    expect(find.text('From HTTP'), findsOneWidget);
    expect(requests, ['GET /index.php/apps/notes/api/v1/notes']);

    await tester.tap(find.text('From HTTP'));
    await settle();
    final field = find.byWidgetPredicate((w) => w is TextField && w.expands);
    await tester.enterText(field, '# edited offline-first');
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
    await tester.pageBack();
    await settle();

    expect(requests, contains('PUT /index.php/apps/notes/api/v1/notes/7'));
    expect(content, '# edited offline-first');
    await tester.runAsync(() async {
      final db = runtime.database;
      final stored = await db.select(db.localNotes).getSingle();
      expect(stored.syncState, 'clean');
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
