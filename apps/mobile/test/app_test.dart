import 'dart:convert';
import 'package:drift/drift.dart' show Value;
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
import 'package:nextcloudnotes/features/editor.dart';
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

    // Phone on its side with the keyboard up: no overflow, text still editable.
    await tester.binding.setSurfaceSize(const Size(800, 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('# original'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
    await tester.pumpAndSettle();

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
    final server = <Map<String, Object?>>[];
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
        transport: () => MockClient((r) async {
          // Created notes are kept so they stay listed (and offered).
          if (r.method == 'POST') {
            final sent = jsonDecode(r.body) as Map<String, Object?>;
            server.add({
              ...sent,
              'id': 100 + server.length,
              'etag': 'e${server.length}',
              'readonly': false,
              'modified': 10,
            });
          }
          return http.Response(
            jsonEncode(r.method == 'POST' ? server.last : server),
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
    // Existing notes are offered too; this one goes to a new note.
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'New note'));
    await settle();
    await tester.runAsync(() async {
      final db = runtime.database;
      final titles = (await db.select(db.localNotes).get()).map((n) => n.title);
      expect(titles, containsAll(['From Keep', 'Call the garage']));
    });
    expect(find.widgetWithText(TextField, 'Call the garage'), findsOneWidget);

    // A third share is appended to an existing note.
    shared = {'title': '', 'text': '- [ ] eggs'};
    await tester.runAsync(() async {
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'com.nkshub.nextcloudnotes/share',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('shared'),
        ),
        (_) {},
      );
    });
    await settle();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.widgetWithText(SimpleDialogOption, 'From Keep'));
    await settle();
    expect(
      find.widgetWithText(TextField, '- [ ] milk\n- [x] bread\n\n- [ ] eggs'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('preview shows an image attached to the note', (tester) async {
    // 1x1 transparent PNG.
    final png = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
    );
    final attachmentPaths = <String>[];
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          if (r.url.pathSegments.contains('attachment')) {
            attachmentPaths.add(r.url.queryParameters['path']!);
            return http.Response.bytes(
              png,
              200,
              headers: {'content-type': 'image/png'},
            );
          }
          return http.Response(
            jsonEncode([
              {
                'id': 7,
                'etag': 'etag1',
                'title': 'With image',
                'content': '![photo](.attachments.7/photo%201.png)',
                'category': '',
                'favorite': false,
                'readonly': false,
                'modified': 10,
              },
            ]),
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
    await tester.tap(find.text('With image'));
    await settle();
    await tester.tap(find.byTooltip('Preview'));
    await settle();

    expect(attachmentPaths, ['.attachments.7/photo 1.png']);
    expect(find.bySemanticsLabel('photo'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
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
  testWidgets('an open note takes a change made on another phone', (
    tester,
  ) async {
    var etag = 'etag1';
    var content = '# original';
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          // The server answers a stale If-Match with the note it holds.
          var status = 200;
          if (r.method == 'PUT') {
            if (r.headers['If-Match'] == '"$etag"') {
              content = (jsonDecode(r.body) as Map)['content'] as String;
              etag = '${etag}x';
            } else {
              status = 412;
            }
          }
          final note = {
            'id': 7,
            'etag': etag,
            'title': 'Shared',
            'content': content,
            'category': '',
            'favorite': false,
            'readonly': false,
            'modified': 10,
          };
          return http.Response(
            jsonEncode(r.url.pathSegments.last == 'notes' ? [note] : note),
            status,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    ))!;
    addTearDown(runtime.close);
    final accountId = (await tester.runAsync(
      () => runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      ),
    ))!;
    Future<void> settle() => tester.runAsync(() async {
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        await tester.pump();
      }
    });

    // The editor's own sync runs on its timer, in test time.
    Future<void> live() async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
        await settle();
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: const OwnNotesApp(),
      ),
    );
    await settle();
    await tester.tap(find.text('Shared'));
    await settle();

    // The other phone saves while this editor is open, then a sync runs.
    content = '# original\nfrom the other phone';
    etag = 'etag2';
    await tester.runAsync(() => runtime.sync.sync(accountId));
    await settle();
    final field = find.byWidgetPredicate((w) => w is TextField && w.expands);
    expect(
      tester.widget<TextField>(field).controller!.text,
      '# original\nfrom the other phone',
    );

    await tester.enterText(field, '# original\nfrom the other phone\nand me');
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
    // The open editor uploads by itself.
    await live();
    expect(content, '# original\nfrom the other phone\nand me');

    // Both write at once: a first line here, a last line on the other phone.
    content = '$content\ntheirs';
    etag = 'other';
    await tester.enterText(
      field,
      'mine\n# original\nfrom the other phone\nand me',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
    await live();
    const both = 'mine\n# original\nfrom the other phone\nand me\ntheirs';
    expect(content, both);
    expect(tester.widget<TextField>(field).controller!.text, both);
    await tester.pageBack();
    await settle();
    expect(content, both);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('a note deleted on another phone can be deleted here too', (
    tester,
  ) async {
    final requests = <String>[];
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          requests.add('${r.method} ${r.url.pathSegments.last}');
          if (r.url.pathSegments.last == 'notes') {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('', 404);
        }),
      ),
    ))!;
    addTearDown(runtime.close);
    await tester.runAsync(() async {
      final accountId = await runtime.accounts.add(
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
              accountId: accountId,
              title: 'Gone',
              content: 'kept text',
              remoteId: const Value(7),
              etag: const Value('e1'),
              syncState: const Value('needsDecision'),
              updatedAt: 1,
            ),
          );
    });
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
    await tester.tap(find.text('Gone'));
    await settle();
    await tester.tap(find.text('Compare server version'));
    await settle();
    expect(find.textContaining('deleted on the server'), findsOneWidget);
    await tester.tap(find.text('Delete on this phone too'));
    await settle();
    await settle();

    // The delete reads the note first; 404 means there is nothing to delete.
    expect(requests.where((r) => r == 'GET 7'), hasLength(2));
    expect(find.text('Gone'), findsNothing);
    await tester.runAsync(() async {
      final db = runtime.database;
      expect(await db.select(db.localNotes).get(), isEmpty);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('a new note left empty is discarded', (tester) async {
    final methods = <String>[];
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((r) async {
          methods.add(r.method);
          return http.Response(
            '[]',
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
    await tester.tap(find.byTooltip('New note'));
    await settle();
    await tester.pageBack();
    await settle();

    expect(methods, isNot(contains('POST')));
    await tester.runAsync(() async {
      final db = runtime.database;
      expect(await db.select(db.localNotes).get(), isEmpty);
    });
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('the keyboard opening keeps the note text focused', (
    tester,
  ) async {
    // Galaxy S21 in portrait: with the keyboard up less than 400 points
    // remain for the editor.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
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
    await tester.tap(find.byTooltip('New note'));
    await settle();
    final text = find.widgetWithText(TextField, 'Markdown text');
    await tester.tap(text);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 1300);
    await tester.pump();
    expect(tester.widget<TextField>(text).focusNode!.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  test('task marks skip fenced code', () {
    const text = '- [ ] a\n```\n- [ ] code\n```\n1. [x] b';
    expect(taskMarks(text).map((i) => text[i]), [' ', 'x']);
    expect(taskMarks(text).last, text.lastIndexOf('x'));
  });
  testWidgets('a checkbox ticked in preview edits the Markdown', (
    tester,
  ) async {
    var etag = 'etag1';
    var content = '- [ ] a\n```\n- [ ] code\n```\n- [ ] b';
    Map<String, Object> note() => {
      'id': 7,
      'etag': etag,
      'title': 'Tasks',
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
          if (r.method == 'PUT') {
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
    await tester.tap(find.text('Tasks'));
    await settle();
    // Find in note selects the next match and wraps around.
    await tester.tap(find.byTooltip('Find in note'));
    await settle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Find in note'),
      '[ ]',
    );
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle();
    final editor = tester.widget<TextField>(
      find.byWidgetPredicate((w) => w is TextField && w.expands),
    );
    expect(
      editor.controller!.selection,
      const TextSelection(baseOffset: 2, extentOffset: 5),
    );
    await tester.tap(find.byTooltip('Next match'));
    await tester.tap(find.byTooltip('Next match'));
    await tester.tap(find.byTooltip('Next match'));
    await settle();
    expect(editor.controller!.selection.baseOffset, 2);
    await tester.tap(find.byTooltip('Preview'));
    await settle();
    expect(find.byType(Checkbox), findsNWidgets(2));
    await tester.tap(find.byType(Checkbox).last);
    await tester.pump(const Duration(milliseconds: 400));
    await settle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isTrue);
    await tester.pageBack();
    await settle();

    expect(content, '- [ ] a\n```\n- [ ] code\n```\n- [x] b');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets('unsent notes show a count and the reason', (tester) async {
    final runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((_) async => throw Exception('offline')),
      ),
    ))!;
    addTearDown(runtime.close);
    final accountId = (await tester.runAsync(() async {
      await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
      final account = (await runtime.database.watchAccounts().first).single;
      await runtime.database.createDraft(
        account.id,
        content: '# Written offline',
      );
      return account.id;
    }))!;
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

    expect(runtime.sync.problem(accountId), 'offline');
    expect(find.text('Not sent yet: 1'), findsOneWidget);
    expect(find.textContaining('No connection'), findsOneWidget);
    expect(find.text('Written offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
