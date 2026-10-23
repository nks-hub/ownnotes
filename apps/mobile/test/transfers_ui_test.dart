import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/providers.dart';
import 'package:nextcloudnotes/data/attachments/attachment_insertion.dart';
import 'package:nextcloudnotes/data/attachments/staging.dart';
import 'package:nextcloudnotes/data/capture/capture_store.dart';
import 'package:nextcloudnotes/data/capture/providers.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/attachments/add_attachment.dart';
import 'package:nextcloudnotes/features/attachments/attach_sources.dart';
import 'package:nextcloudnotes/features/attachments/attachments_sheet.dart';
import 'package:nextcloudnotes/features/attachments/voice_engine.dart';
import 'package:nextcloudnotes/features/attachments/voice_screen.dart';
import 'package:nextcloudnotes/features/capture/capture_screen.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

import 'support/transfer_fixtures.dart';

class _Engine implements VoiceEngine {
  _Engine(this.dir);
  final Directory dir;
  final calls = <String>[];
  String? path;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> start(String p) async {
    calls.add('start');
    path = p;
    File(p).writeAsBytesSync(List.filled(2048, 1));
  }

  @override
  Future<void> pause() async => calls.add('pause');
  @override
  Future<void> resume() async => calls.add('resume');
  @override
  Future<String?> stop() async {
    calls.add('stop');
    return path;
  }

  @override
  Future<void> dispose() async {}
}

class _Player implements VoicePlayer {
  final done = StreamController<void>.broadcast();
  final played = <String>[];
  @override
  Future<void> play(String path) async => played.add(path);
  @override
  Future<void> stop() async {}
  @override
  Stream<void> get completed => done.stream;
  @override
  Future<void> dispose() async {}
}

/// Unmounts the tree so drift's close timers run inside the test.
Future<void> finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(milliseconds: 10));
}

Future<void> until(WidgetTester tester, bool Function() done) async {
  // Real file I/O, slower while the full suite runs files in parallel; the
  // count bounds real waiting (15 ms each), fake time does not advance it.
  for (var i = 0; i < 600 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done(), isTrue, reason: 'condition not reached');
}

void main() {
  late TransferEnv env;
  late BuildContext hostContext;
  late WidgetRef hostRef;

  Future<void> pumpHost(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    env = (await tester.runAsync(TransferEnv.create))!;
    addTearDown(env.runtime.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(env.runtime),
          attachmentServiceProvider.overrideWith((ref) => env.service),
          ...overrides,
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              hostContext = context;
              hostRef = ref;
              return const Scaffold(body: Text('host'));
            },
          ),
        ),
      ),
    );
  }

  Future<LocalNote> note(WidgetTester tester, {int? remoteId = 42}) async {
    return (await tester.runAsync(() async {
      await env.addNote(remoteId: remoteId, content: 'Hello');
      return (await env.db.note(env.accountId, 'n1'))!;
    }))!;
  }

  testWidgets('a picked file is uploaded and the markdown comes back once', (
    tester,
  ) async {
    final file = await _tmp(tester, 'Zpráva.pdf');
    await pumpHost(
      tester,
      overrides: [
        attachmentSourcesProvider.overrideWithValue(
          FileSources([PickedFile(path: file.path, name: 'Zpráva.pdf')]),
        ),
      ],
    );
    final n = await note(tester);
    final result = await tester.runAsync(
      () => addAttachment(hostContext, hostRef, n, AttachKind.file),
    );
    await tester.pump();
    expect(result?.markdown, '[Zpráva.pdf](.attachments.42/Zpr%C3%A1va.pdf)');
    expect(env.server.uploads, ['Zpráva.pdf']);
    expect(
      await tester.runAsync(() => env.service.pending(env.accountId, 'n1')),
      isNotEmpty,
    );
    await finish(tester);
  });

  testWidgets(
    'a failed upload can be kept for later and retried in the sheet',
    (tester) async {
      final file = await _tmp(tester, 'a.png');
      await pumpHost(
        tester,
        overrides: [
          attachmentSourcesProvider.overrideWithValue(
            FileSources([PickedFile(path: file.path, name: 'a.png')]),
          ),
        ],
      );
      final n = await note(tester);
      env.server.failures.add(403);
      final future = addAttachment(hostContext, hostRef, n, AttachKind.photo);
      AttachmentInsertion? result;
      var finished = false;
      unawaited(
        future.then((v) {
          result = v;
          finished = true;
        }),
      );
      await until(
        tester,
        () => find.text('Upload failed').evaluate().isNotEmpty,
      );
      expect(find.textContaining('did not allow'), findsOneWidget);
      await tester.tap(find.text('Keep for later'));
      await until(tester, () => finished);
      expect(result, isNull);

      final staged = (await tester.runAsync(
        () => env.service.pending(env.accountId, 'n1'),
      ))!;
      expect(staged.single.state, StagedState.failed);

      unawaited(showAttachmentsSheet(hostContext, hostRef, n));
      await until(
        tester,
        () =>
            find.byKey(Key('retry-${staged.single.id}')).evaluate().isNotEmpty,
      );
      expect(find.textContaining('Failed'), findsOneWidget);
      await tester.tap(find.byKey(Key('retry-${staged.single.id}')));
      await until(tester, () => env.server.uploads.isNotEmpty);
      await until(
        tester,
        () => find.byKey(Key('staged-${staged.single.id}')).evaluate().isEmpty,
      );
      expect(
        (await tester.runAsync(
          () => env.db.note(env.accountId, 'n1'),
        ))!.content,
        'Hello\n\n![a.png](.attachments.42/a.png)',
      );
      await finish(tester);
    },
  );

  testWidgets('a note not on the server yet shows the file as waiting', (
    tester,
  ) async {
    final file = await _tmp(tester, 'b.png');
    await pumpHost(
      tester,
      overrides: [
        attachmentSourcesProvider.overrideWithValue(
          FileSources([PickedFile(path: file.path, name: 'b.png')]),
        ),
      ],
    );
    final n = await note(tester, remoteId: null);
    final result = await tester.runAsync(
      () => addAttachment(hostContext, hostRef, n, AttachKind.file),
    );
    await tester.pump();
    expect(result, isNull);
    expect(find.textContaining('Saved on device'), findsOneWidget);
    unawaited(showAttachmentsSheet(hostContext, hostRef, n));
    await until(
      tester,
      () => find
          .textContaining('Waiting for the note to be uploaded')
          .evaluate()
          .isNotEmpty,
    );
    expect(env.server.uploads, isEmpty);
    await finish(tester);
  });

  testWidgets('removing a link and deleting the file are separate actions', (
    tester,
  ) async {
    await pumpHost(tester);
    final n = (await tester.runAsync(() async {
      await env.addNote(content: 'x ![p.png](.attachments.42/p.png) y');
      return (await env.db.note(env.accountId, 'n1'))!;
    }))!;
    final removed = <String>[];
    unawaited(
      showAttachmentsSheet(
        hostContext,
        hostRef,
        n,
        onRemoveReference: (r) async => removed.add(r.path),
      ),
    );
    await until(tester, () => find.text('p.png').evaluate().isNotEmpty);
    await tester.pumpAndSettle();
    expect(find.textContaining('The file stays on the server'), findsOneWidget);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Remove link from note'), findsOneWidget);
    expect(find.text('Delete file on server'), findsOneWidget);
    await tester.tap(find.text('Remove link from note'));
    await tester.pumpAndSettle();
    expect(removed, ['.attachments.42/p.png']);
    expect(env.server.deletes, isEmpty);
    await finish(tester);
  });

  group('voice', () {
    testWidgets('pause, resume, stop, listen and attach', (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('voice'),
      ))!;
      final engine = _Engine(dir);
      final player = _Player();
      String? attached;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceEngineFactoryProvider.overrideWithValue(() => engine),
            voicePlayerFactoryProvider.overrideWithValue(() => player),
            voiceDirectoryProvider.overrideWith((ref) => dir),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () async =>
                    attached = await Navigator.of(context).push<String>(
                      MaterialPageRoute(
                        builder: (_) => const VoiceRecordingScreen(),
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start recording'));
      await until(tester, () => find.text('Recording').evaluate().isNotEmpty);
      await tester.tap(find.text('Pause'));
      await until(tester, () => find.text('Paused').evaluate().isNotEmpty);
      await tester.tap(find.text('Resume'));
      await until(tester, () => find.text('Recording').evaluate().isNotEmpty);
      // The app is sent to the background: the recording pauses and is kept.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await until(tester, () => find.text('Paused').evaluate().isNotEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.textContaining('interrupted'), findsOneWidget);
      await tester.tap(find.text('Stop'));
      await until(
        tester,
        () => find.text('Recording stopped').evaluate().isNotEmpty,
      );
      await tester.tap(find.text('Listen'));
      await tester.pump();
      expect(player.played, [engine.path]);
      await tester.tap(find.text('Attach'));
      await tester.pumpAndSettle();
      expect(attached, engine.path);
      expect(engine.calls, ['start', 'pause', 'resume', 'pause', 'stop']);
      expect(File(engine.path!).existsSync(), isTrue);
      await finish(tester);
    });

    testWidgets('an unattached recording is offered again', (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('voice'),
      ))!;
      final left = File('${dir.path}/voice-1.m4a')
        ..writeAsBytesSync(List.filled(4096, 2));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voiceEngineFactoryProvider.overrideWithValue(() => _Engine(dir)),
            voicePlayerFactoryProvider.overrideWithValue(_Player.new),
            voiceDirectoryProvider.overrideWith((ref) => dir),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const VoiceRecordingScreen(),
          ),
        ),
      );
      await until(
        tester,
        () =>
            find.text('Recovered an earlier recording.').evaluate().isNotEmpty,
      );
      expect(find.text('Attach'), findsOneWidget);
      expect(left.existsSync(), isTrue);
      await finish(tester);
    });
  });

  group('capture screen', () {
    Future<Capture> stored(WidgetTester tester, CaptureStore store) async {
      await tester.runAsync(
        () => store.ingest(
          const NativeCapture(
            id: 'c1',
            title: 'Odkaz',
            text: 'https://example.org/clanek',
            createdAt: 1,
            files: [],
          ),
        ),
      );
      return (await tester.runAsync(store.pending))!.single;
    }

    Future<void> open(
      WidgetTester tester,
      CaptureStore store,
      Capture capture,
      List<bool?> results,
    ) async {
      await pumpHost(
        tester,
        overrides: [captureStoreProvider.overrideWith((ref) => store)],
      );
      unawaited(
        Navigator.of(hostContext)
            .push<bool>(
              MaterialPageRoute(
                builder: (_) => CaptureScreen(capture: capture),
              ),
            )
            .then(results.add),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('closing the screen keeps the capture pending', (tester) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('cap'),
      ))!;
      final store = CaptureStore(dir);
      final capture = await stored(tester, store);
      final results = <bool?>[];
      await open(tester, store, capture, results);
      expect(find.text('Shared content'), findsOneWidget);
      expect(find.text('https://example.org/clanek'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(results, [null]);
      expect(await tester.runAsync(store.pending), hasLength(1));
      expect(
        await tester.runAsync(() => env.db.select(env.db.localNotes).get()),
        isEmpty,
      );
      await finish(tester);
    });

    testWidgets(
      'one account is prefilled; saving makes a note and finishes it',
      (tester) async {
        final dir = (await tester.runAsync(
          () => Directory.systemTemp.createTemp('cap'),
        ))!;
        final store = CaptureStore(dir);
        final capture = await stored(tester, store);
        final results = <bool?>[];
        await open(tester, store, capture, results);
        await until(
          tester,
          () =>
              find.byKey(Key('account-${env.accountId}')).evaluate().isNotEmpty,
        );
        final save = find.widgetWithText(FilledButton, 'Save on device');
        expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
        await tester.enterText(find.byType(TextField).first, 'Inbox');
        await tester.tap(save);
        await until(tester, () => results.isNotEmpty);
        expect(results, [true]);
        final notes = (await tester.runAsync(
          () => env.db.select(env.db.localNotes).get(),
        ))!;
        expect(notes.single.title, 'Odkaz');
        expect(notes.single.content, 'https://example.org/clanek');
        expect(notes.single.category, 'Inbox');
        expect(await tester.runAsync(store.pending), isEmpty);
        await finish(tester);
      },
    );

    testWidgets('with two accounts nothing is saved until one is chosen', (
      tester,
    ) async {
      final dir = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('cap'),
      ))!;
      final store = CaptureStore(dir);
      final capture = await stored(tester, store);
      final results = <bool?>[];
      await open(tester, store, capture, results);
      final second = (await tester.runAsync(
        () => env.runtime.accounts.add(
          LoginCredentials(
            server: ServerBase.parse('https://other.test'),
            loginName: 'anna',
            appPassword: 'secret',
          ),
        ),
      ))!;
      await until(
        tester,
        () => find.byKey(Key('account-$second')).evaluate().isNotEmpty,
      );
      final save = find.widgetWithText(FilledButton, 'Save on device');
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Choose the account for this content.'), findsOneWidget);
      await tester.tap(find.byKey(Key('account-$second')));
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
      await finish(tester);
    });
  });
}

Future<File> _tmp(WidgetTester tester, String name) async {
  return (await tester.runAsync(() async {
    final dir = await Directory.systemTemp.createTemp('pick');
    return File('${dir.path}/$name')..writeAsBytesSync([1, 2, 3]);
  }))!;
}
