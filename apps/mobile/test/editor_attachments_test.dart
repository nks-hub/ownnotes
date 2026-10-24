import 'dart:async';
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
import 'package:nextcloudnotes/features/attachments/attach_sources.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:nextcloudnotes/main.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'app_test.dart' show Vault, phoneTest;
import 'transfers_ui_test.dart' show until;
import 'support/transfer_fixtures.dart' show FileSources;

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
  Completer<void>? pendingImage;
  final requests = <String>[];

  setUp(() {
    offline = false;
    pendingImage = null;
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
        await pendingImage?.future;
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

  Future<void> open(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(runtime),
          attachmentServiceProvider.overrideWith((_) => service),
          ...overrides,
        ],
        child: const OwnNotesApp(),
      ),
    );
    await _settle(tester);
    await tester.tap(find.text('With image'));
    await _settle(tester);
    await tester.tap(find.byTooltip('Preview'));
    await _settle(tester);
    if (pendingImage == null) {
      await until(
        tester,
        () =>
            find.bySemanticsLabel('photo').evaluate().isNotEmpty ||
            find.text('Image not loaded. Retry').evaluate().isNotEmpty,
      );
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    // Pending directory reads need their fake-zone continuations before teardown.
    await _settle(tester);
    // Queue a final cache operation so Windows handles close before deletion.
    var cacheIdle = false;
    final size = service.cache.sizeBytes().whenComplete(() => cacheIdle = true);
    await until(tester, () => cacheIdle);
    await size;
  }

  Future<void> attachments(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More options'));
    // A preview can still be reading its image; its spinner need not settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Attachments'), findsOneWidget);
    await tester.tap(find.text('Attachments'));
    await _settle(tester);
    expect(find.byType(AttachmentsPanel), findsOneWidget);
  }

  for (final failWrite in [false, true]) {
    phoneTest(
      'attachment insertion commits before acknowledgment; failed write: $failWrite',
      (tester) async {
        await setup(tester);
        final file = (await tester.runAsync(() async {
          final f = File('${dir.path}/later.png');
          await f.writeAsBytes(_png);
          return f;
        }))!;
        await open(
          tester,
          overrides: [
            attachmentSourcesProvider.overrideWithValue(
              FileSources([PickedFile(path: file.path, name: 'later.png')]),
            ),
          ],
        );
        final note = (await tester.runAsync(
          () => runtime.database.select(runtime.database.localNotes).get(),
        ))!.single;
        if (failWrite) {
          await tester.runAsync(
            () => runtime.database.customStatement(
              "CREATE TRIGGER reject_content BEFORE UPDATE OF content ON local_notes "
              "BEGIN SELECT RAISE(FAIL, 'test write failure'); END",
            ),
          );
        }
        await tester.tap(find.byTooltip('Edit source'));
        await tester.pumpAndSettle();
        final source = tester
            .widget<TextField>(
              find.byWidgetPredicate((w) => w is TextField && w.expands),
            )
            .controller!;
        source.selection = const TextSelection.collapsed(offset: 0);
        await tester.tap(find.byTooltip('Attach'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('File'));
        if (failWrite) {
          await until(
            tester,
            () => find
                .text('Could not save on this device')
                .evaluate()
                .isNotEmpty,
          );
          expect(
            (await tester.runAsync(
              () => service.pending(note.accountId, note.id),
            ))!.single.state,
            StagedState.uploaded,
          );
          expect(await tester.runAsync(() => service.flush(note.accountId)), 0);
          await tester.runAsync(
            () =>
                runtime.database.customStatement('DROP TRIGGER reject_content'),
          );
          await tester.tap(find.text('Retry').first);
        }
        await until(
          tester,
          () =>
              source.text.contains('later.png') &&
              find.text('Saved locally').evaluate().isNotEmpty,
        );
        await _settle(tester);
        expect(
          source.text,
          '$_markdown\n![later.png](.attachments.7/later.png)',
        );
        final saved = (await tester.runAsync(
          () => runtime.database.note(note.accountId, note.id),
        ))!;
        expect(saved.content, source.text);
        expect(
          await tester.runAsync(() => service.pending(note.accountId, note.id)),
          isEmpty,
        );
        await tester.tap(find.byTooltip('Undo'));
        await tester.pump(const Duration(milliseconds: 400));
        await _settle(tester);
        expect(source.text, _markdown);
        expect(await tester.runAsync(() => service.flush(note.accountId)), 0);
        await close(tester);
      },
    );
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
    pendingImage = Completer<void>();
    await setup(tester, readonly: true);
    addTearDown(() {
      if (!pendingImage!.isCompleted) pendingImage!.complete();
    });
    await open(tester);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await attachments(tester);
    expect(find.text('photo 1.png'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(AttachmentsPanel),
        matching: find.byTooltip('More options'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Keep offline'), findsOneWidget);
    expect(find.text('Remove link from note'), findsNothing);
    expect(find.text('Delete file on server'), findsNothing);
    await tester.binding.handlePopRoute();
    pendingImage!.complete();
    // Both the preview and panel thumbnail must finish their cache writes.
    await until(
      tester,
      () => find.byType(Image, skipOffstage: false).evaluate().length == 2,
    );
    expect(requests, [_path]);
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
    await until(
      tester,
      () => find.text('Image not loaded. Retry').evaluate().isNotEmpty,
    );
    expect(find.text('Image not loaded. Retry'), findsOneWidget);
    expect(requests, [_path]);
    offline = false;
    await tester.tap(find.text('Image not loaded. Retry'));
    await until(
      tester,
      () => find.bySemanticsLabel('photo').evaluate().isNotEmpty,
    );
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
