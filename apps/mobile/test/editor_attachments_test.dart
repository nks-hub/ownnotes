import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/attachments/attachment_cache.dart';
import 'package:nextcloudnotes/data/attachments/attachment_service.dart';
import 'package:nextcloudnotes/data/attachments/providers.dart';
import 'package:nextcloudnotes/data/attachments/staging.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/editor/preview.dart';
import 'package:nextcloudnotes/features/attachments/attachments_sheet.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:nextcloudnotes/main.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'app_test.dart' show Vault, phoneTest;
import 'transfers_ui_test.dart' show until;

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
);
const _markdown = '![photo](.attachments.7/photo%201.png)';
const _path = '.attachments.7/photo 1.png';

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  late AppRuntime runtime;
  late Directory dir;
  late AttachmentService service;
  late http.Client transport;
  var offline = false;
  final requests = <String>[];

  setUp(() {
    offline = false;
    requests.clear();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  Future<void> setup(WidgetTester tester, {bool readonly = false}) async {
    await tester.runAsync(() async {
      dir = await Directory.systemTemp.createTemp('editor-attachments');
      http.Response notes() => http.Response(
        jsonEncode([
          {
            'id': 7,
            'etag': 'etag1',
            'title': 'With image',
            'content': _markdown,
            'category': '',
            'favorite': false,
            'readonly': readonly,
            'modified': 10,
          },
        ]),
        200,
        headers: {'content-type': 'application/json'},
      );
      runtime = AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        Vault(),
        transport: () => MockClient((_) async => notes()),
      );
      transport = MockClient((request) async {
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({'filename': '.attachments.7/later.png'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        requests.add(request.url.queryParameters['path']!);
        if (offline) throw const SocketException('offline');
        return http.Response.bytes(
          _png,
          200,
          headers: {'content-type': 'image/png'},
        );
      });
      service = AttachmentService(
        database: runtime.database,
        staging: AttachmentStaging(Directory('${dir.path}/staging')),
        cache: AttachmentCache(Directory('${dir.path}/cache')),
        clientFor: (account) async => AttachmentsClient(
          base: ServerBase.parse(account.server),
          transport: transport,
          loginName: account.loginName,
          appPassword: 'secret',
          route: AttachmentRoute.current,
        ),
      );
      await runtime.accounts.add(
        LoginCredentials(
          server: ServerBase.parse('https://cloud.test'),
          loginName: 'test',
          appPassword: 'secret',
        ),
      );
    });
    addTearDown(() async {
      transport.close();
      await runtime.close();
      await dir.delete(recursive: true);
    });
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(runtime),
          attachmentServiceProvider.overrideWith((_) => service),
        ],
        child: const OwnNotesApp(),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('With image'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Preview'));
    await _settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // Pending directory reads need their fake-zone continuations before teardown.
    await _settle(tester);
  }

  Future<void> attachments(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Attachments'));
    await _settle(tester);
    expect(find.byType(AttachmentsPanel), findsOneWidget);
  }

  phoneTest('editor menu retries a staged file and inserts its link', (
    tester,
  ) async {
    await setup(tester);
    final staged = (await tester.runAsync(() async {
      final account = (await runtime.database.watchAccounts().first).single;
      await runtime.sync.sync(account.id);
      final note =
          (await runtime.database.select(runtime.database.localNotes).get())
              .single;
      final file = File('${dir.path}/later.png');
      await file.writeAsBytes(_png);
      final item = await service.stage(
        accountId: note.accountId,
        noteId: note.id,
        source: file,
        name: 'later.png',
      );
      await service.staging.update(
        item.copyWith(state: StagedState.failed, error: 'denied'),
      );
      return item;
    }))!;
    await open(tester);
    await attachments(tester);
    expect(find.byKey(Key('staged-${staged.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('retry-${staged.id}')));
    await until(
      tester,
      () => find.byKey(Key('staged-${staged.id}')).evaluate().isEmpty,
    );
    expect(find.byKey(Key('staged-${staged.id}')), findsNothing);
    expect(
      find.byKey(const Key('ref-.attachments.7/later.png')),
      findsOneWidget,
    );
    final note = (await tester.runAsync(
      () => runtime.database.note(staged.accountId, staged.noteId),
    ))!;
    expect(
      note.content,
      '$_markdown\n\n![later.png](.attachments.7/later.png)',
    );
    await close(tester);
  });

  phoneTest(
    'removing a link from the editor keeps the file and supports undo',
    (tester) async {
      await setup(tester);
      await open(tester);
      await attachments(tester);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove link from note'));
      await _settle(tester);
      final note = (await tester.runAsync(
        () => runtime.database.select(runtime.database.localNotes).get(),
      ))!.single;
      expect(note.content, '');
      expect(requests, [_path]);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit source'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Undo'));
      await tester.pump();
      final source = tester.widget<TextField>(
        find.byWidgetPredicate((w) => w is TextField && w.expands),
      );
      expect(source.controller!.text, _markdown);
      await close(tester);
    },
  );

  phoneTest('read-only attachments can be viewed without removal actions', (
    tester,
  ) async {
    await setup(tester, readonly: true);
    await open(tester);
    await attachments(tester);
    expect(find.text('photo 1.png'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Remove link from note'), findsNothing);
    expect(find.text('Delete file on server'), findsNothing);
    await close(tester);
  });

  phoneTest('editor caches downloaded images and reopens offline', (
    tester,
  ) async {
    await setup(tester);
    await open(tester);
    expect(requests, [_path]);
    expect(find.bySemanticsLabel('photo'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    final account = (await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    ))!.single;
    expect(
      await tester.runAsync(() => service.cache.read(account.id, 7, _path)),
      _png,
    );
    await close(tester);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    offline = true;
    service = AttachmentService(
      database: runtime.database,
      staging: service.staging,
      cache: AttachmentCache(Directory('${dir.path}/cache')),
      clientFor: (_) async => throw StateError('must use stored image'),
    );
    await open(tester);
    expect(find.bySemanticsLabel('photo'), findsOneWidget);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNothing);
    expect(requests, [_path]);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  phoneTest('failed image retries in preview without editing the note', (
    tester,
  ) async {
    await setup(tester);
    offline = true;
    await open(tester);
    expect(find.text('Image not loaded. Retry'), findsOneWidget);
    expect(requests, [_path]);
    offline = false;
    await tester.tap(find.text('Image not loaded. Retry'));
    await _settle(tester);
    expect(requests, [_path, _path]);
    expect(find.text('Image not loaded. Retry'), findsNothing);
    expect(find.bySemanticsLabel('photo'), findsOneWidget);
    expect(find.byTooltip('Edit source'), findsOneWidget);
    final note = (await tester.runAsync(
      () => runtime.database.select(runtime.database.localNotes).get(),
    ))!.single;
    expect(note.content, _markdown);
    await close(tester);
  });

  testWidgets('invalid UTF-8 and external images do not invoke the loader', (
    tester,
  ) async {
    final loaded = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MarkdownPreview(
            text:
                '![broken](.attachments.7/%FF.png)\n\n![remote](https://images.test/p.png)',
            readonly: true,
            onEditAt: (_) => fail('read-only preview cannot edit'),
            onReplaceRange: (_, _, _) => fail('no text edits'),
            loadAttachment: (path) async {
              loaded.add(path);
              return _png;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(loaded, isEmpty);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
