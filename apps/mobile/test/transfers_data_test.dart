import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/attachment_cache.dart';
import 'package:nextcloudnotes/data/attachments/attachment_markdown.dart';
import 'package:nextcloudnotes/data/attachments/attachment_service.dart';
import 'package:nextcloudnotes/data/attachments/staging.dart';
import 'package:nextcloudnotes/data/capture/capture_inbox.dart';
import 'package:nextcloudnotes/data/capture/capture_store.dart';

import 'support/transfer_fixtures.dart';

class _FakeSource implements CaptureSource {
  _FakeSource(this.items);
  final List<NativeCapture> items;
  final acked = <String>[];
  final events = <String>[];
  @override
  Future<List<NativeCapture>> list() async => [...items];
  @override
  Future<void> ack(String id) async {
    events.add('ack $id');
    acked.add(id);
    items.removeWhere((c) => c.id == id);
  }
}

void main() {
  group('markdown', () {
    test('images and links are written the way the Notes app does', () {
      expect(
        attachmentMarkdown('.attachments.42/pixel ü (1).png', image: true),
        '![pixel ü (1).png](.attachments.42/pixel%20%C3%BC%20%281%29.png)',
      );
      expect(
        attachmentMarkdown('.attachments.42/memo.m4a', image: false),
        '[memo.m4a](.attachments.42/memo.m4a)',
      );
    });
    test('names are made safe and keep their extension', () {
      expect(safeAttachmentName('../a:b?.png'), 'a_b_.png');
      expect(safeAttachmentName(''), 'attachment');
      final long = safeAttachmentName('${'x' * 300}.jpeg');
      expect(long.length, 120);
      expect(long, endsWith('.jpeg'));
      expect(mimeForName('A.JPG'), 'image/jpeg');
    });
  });

  group('staging', () {
    late Directory dir;
    setUp(() async => dir = await Directory.systemTemp.createTemp('stg'));
    tearDown(() => dir.delete(recursive: true));

    test(
      'a staged file survives a restart and an interrupted upload resets',
      () async {
        final src = File('${dir.path}/photo.png')..writeAsBytesSync([9, 8, 7]);
        final first = AttachmentStaging(Directory('${dir.path}/s'));
        final item = await first.stage(
          id: 'a1',
          accountId: 'acc',
          noteId: 'n1',
          name: 'photo.png',
          mime: 'image/png',
          source: src,
        );
        await first.update(item.copyWith(state: StagedState.uploading));
        await src.delete(); // The picker's temporary copy is gone.

        final second = AttachmentStaging(Directory('${dir.path}/s'));
        await second.recoverInterrupted();
        final back = await second.list(accountId: 'acc', noteId: 'n1');
        expect(back.single.name, 'photo.png');
        expect(back.single.state, StagedState.stored);
        expect(await second.dataFile('a1').readAsBytes(), [9, 8, 7]);
      },
    );

    test(
      'staging the same id twice adds nothing; half copies are dropped',
      () async {
        final src = File('${dir.path}/f.bin')..writeAsBytesSync([1]);
        final staging = AttachmentStaging(Directory('${dir.path}/s'));
        Future<StagedAttachment> stage() => staging.stage(
          id: 'x',
          accountId: 'a',
          noteId: 'n',
          name: 'f.bin',
          mime: 'application/octet-stream',
          source: src,
        );
        final one = await stage();
        final two = await stage();
        expect(two.createdAt, one.createdAt);
        expect(await staging.list(), hasLength(1));

        // A copy that died before its metadata was written.
        await Directory('${dir.path}/s/broken').create(recursive: true);
        await File('${dir.path}/s/broken/data').writeAsBytes([1]);
        await staging.recoverInterrupted();
        expect(Directory('${dir.path}/s/broken').existsSync(), isFalse);
        expect(await staging.list(), hasLength(1));
      },
    );
  });

  group('cache', () {
    test(
      'keeps what was read, evicts least recently used, never caches errors',
      () async {
        final dir = await Directory.systemTemp.createTemp('cache');
        addTearDown(() => dir.delete(recursive: true));
        final cache = AttachmentCache(dir, maxFileBytes: 10, maxTotalBytes: 12);
        expect(await cache.write('a', 1, 'p/one', List.filled(6, 1)), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await cache.write('a', 1, 'p/two', List.filled(6, 2)), isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(await cache.write('a', 1, 'p/three', List.filled(6, 3)), isTrue);
        expect(await cache.contains('a', 1, 'p/one'), isFalse);
        expect(await cache.contains('a', 1, 'p/three'), isTrue);
        expect(await cache.write('a', 1, 'p/big', List.filled(11, 1)), isFalse);

        await expectLater(
          cache.load('a', 2, 'p/x', () async => throw StateError('offline')),
          throwsStateError,
        );
        expect(await cache.contains('a', 2, 'p/x'), isFalse);
        expect(await cache.load('a', 2, 'p/x', () async => [5]), [5]);
        expect(await cache.load('a', 2, 'p/x', () async => throw 'unused'), [
          5,
        ]);
      },
    );
  });

  group('attachment service', () {
    late TransferEnv env;
    setUp(() async => env = await TransferEnv.create());
    tearDown(() => env.dispose());

    test('uploads and returns the markdown for the returned path', () async {
      await env.addNote();
      final item = await env.service.stage(
        accountId: env.accountId,
        noteId: 'n1',
        source: await env.file('Foto 1.png'),
        name: 'Foto 1.png',
      );
      final out = await env.service.upload(item.id);
      expect(out, isA<Uploaded>());
      expect(
        (out as Uploaded).markdown,
        '![Foto 1.png](.attachments.42/Foto%201.png)',
      );
      expect(env.server.uploads, ['Foto 1.png']);
      // Kept for offline previews.
      final note = (await env.db.note(env.accountId, 'n1'))!;
      expect(
        await env.service.isCached(note, '.attachments.42/Foto 1.png'),
        isTrue,
      );
    });

    test('a note not on the server yet keeps the file staged', () async {
      await env.addNote(remoteId: null);
      final item = await env.service.stage(
        accountId: env.accountId,
        noteId: 'n1',
        source: await env.file('a.pdf'),
        name: 'a.pdf',
      );
      expect(await env.service.upload(item.id), isA<WaitingForNote>());
      expect(env.server.uploads, isEmpty);
      expect(
        (await env.service.pending(env.accountId, 'n1')).single.state,
        StagedState.stored,
      );
    });

    test(
      'server errors retry, refusals fail with a code and can be retried',
      () async {
        final slow = await TransferEnv.create(
          retryDelays: const [
            Duration(milliseconds: 1),
            Duration(milliseconds: 1),
          ],
        );
        addTearDown(slow.dispose);
        await slow.addNote();
        slow.server.failures.addAll([500, 502]);
        final item = await slow.service.stage(
          accountId: slow.accountId,
          noteId: 'n1',
          source: await slow.file('a.png'),
          name: 'a.png',
        );
        expect(await slow.service.upload(item.id), isA<Uploaded>());

        await slow.service.complete(item.id);
        final big = await slow.service.stage(
          accountId: slow.accountId,
          noteId: 'n1',
          source: await slow.file('b.png'),
          name: 'b.png',
        );
        slow.server.failures.add(413);
        final failed = await slow.service.upload(big.id);
        expect((failed as UploadFailed).code, 'too_large');
        expect(
          (await slow.service.pending(slow.accountId, 'n1')).single.state,
          StagedState.failed,
        );
        expect(await slow.service.retry(big.id), isA<Uploaded>());
      },
    );

    test(
      'offline ends as a retriable failure that survives a restart',
      () async {
        await env.addNote();
        final item = await env.service.stage(
          accountId: env.accountId,
          noteId: 'n1',
          source: await env.file('a.png'),
          name: 'a.png',
        );
        env.server.offline = true;
        expect(
          (await env.service.upload(item.id) as UploadFailed).code,
          'offline',
        );

        final restarted = env.restarted();
        env.server.offline = false;
        expect(await restarted.flush(env.accountId), 1);
        final note = (await env.db.note(env.accountId, 'n1'))!;
        expect(note.content, 'body\n\n![a.png](.attachments.42/a.png)');
        expect(await restarted.pending(env.accountId, 'n1'), isEmpty);
      },
    );

    test(
      'flush appends references once and stays quiet for finished files',
      () async {
        await env.addNote(content: '');
        for (final name in ['x.png', 'y.m4a']) {
          await env.service.stage(
            accountId: env.accountId,
            noteId: 'n1',
            source: await env.file(name),
            name: name,
          );
        }
        expect(await env.service.flush(env.accountId), 2);
        final note = (await env.db.note(env.accountId, 'n1'))!;
        expect(
          note.content,
          '![x.png](.attachments.42/x.png)\n[y.m4a](.attachments.42/y.m4a)',
        );
        expect(note.revision, 2);
        expect(await env.service.flush(env.accountId), 0);
      },
    );

    test('deleting needs a server that can and clears the cache', () async {
      await env.addNote();
      expect(await env.service.canDelete(env.accountId), isTrue);
      await env.service.cache.write(
        env.accountId,
        42,
        '.attachments.42/a.png',
        [1],
      );
      await env.service.deleteRemote(
        env.accountId,
        42,
        '.attachments.42/a.png',
      );
      expect(env.server.deletes, ['.attachments.42/a.png']);
      expect(
        await env.service.cache.contains(
          env.accountId,
          42,
          '.attachments.42/a.png',
        ),
        isFalse,
      );
    });
  });

  group('captures', () {
    late Directory dir;
    late CaptureStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('cap');
      store = CaptureStore(Directory('${dir.path}/store'));
    });
    tearDown(() => dir.delete(recursive: true));

    NativeCapture native(
      String id, {
      String text = 'hello',
      List<CaptureFile> files = const [],
    }) => NativeCapture(
      id: id,
      title: 'Title',
      text: text,
      createdAt: 1,
      files: files,
    );

    test(
      'the platform inbox is acknowledged only after the capture is stored',
      () async {
        final src = _FakeSource([native('one'), native('two')]);
        final seen = <String>[];
        final checking = _CheckingSource(src, store, seen);
        expect(await drainCaptures(checking, store), 2);
        expect(seen, ['one stored at ack', 'two stored at ack']);
        expect(
          (await store.pending()).map((c) => c.id),
          containsAll(['one', 'two']),
        );
      },
    );

    test('a capture that cannot be stored is not acknowledged', () async {
      final src = _FakeSource([
        native(
          'bad',
          files: const [
            CaptureFile(name: 'x', mime: 'a/b', path: '/does/not/exist'),
          ],
        ),
        native('good'),
      ]);
      await expectLater(
        drainCaptures(src, store),
        throwsA(isA<FileSystemException>()),
      );
      expect(src.acked, ['good']);
      expect((await store.pending()).map((c) => c.id), ['good']);
      expect(src.items.map((c) => c.id), ['bad']);
    });

    test(
      'repeated delivery stores once, even after the capture was finished',
      () async {
        final src = _FakeSource([native('same')]);
        expect(await drainCaptures(src, store), 1);
        // The ack was lost: the platform delivers it again.
        src.items.add(native('same'));
        expect(await drainCaptures(src, store), 0);
        expect(await store.pending(), hasLength(1));
        expect(src.items, isEmpty);

        await store.complete('same');
        src.items.add(native('same'));
        expect(await drainCaptures(src, store), 0);
        expect(await store.pending(), isEmpty);
      },
    );

    test('files are copied, never moved, from the platform folder', () async {
      final f = File('${dir.path}/p.png')..writeAsBytesSync([4, 5]);
      await store.ingest(
        native(
          'f',
          files: [CaptureFile(name: 'p.png', mime: 'image/png', path: f.path)],
        ),
      );
      expect(f.existsSync(), isTrue);
      final c = (await store.pending()).single;
      expect(await File(c.files.single.path).readAsBytes(), [4, 5]);
    });

    test(
      'converting is repeatable: one note, attachments staged once',
      () async {
        final env = await TransferEnv.create();
        addTearDown(env.dispose);
        final f = await env.file('pic.png');
        await store.ingest(
          native(
            'cap1',
            files: [
              CaptureFile(name: 'pic.png', mime: 'image/png', path: f.path),
            ],
          ),
        );
        final capture = (await store.pending()).single;
        Future<String> run() => convertCapture(
          database: env.db,
          attachments: env.service,
          store: store,
          capture: capture,
          accountId: env.accountId,
          target: const NewNote(category: 'Inbox'),
        );
        await run();
        await run(); // A crash before complete() would run it again.
        final notes = await env.db.select(env.db.localNotes).get();
        expect(notes.where((n) => n.id == 'cap1'), hasLength(1));
        expect(notes.single.content, 'hello');
        expect(notes.single.category, 'Inbox');
        expect(await env.service.pending(env.accountId, 'cap1'), hasLength(1));
        expect(await store.pending(), isEmpty);
      },
    );

    test(
      'append adds the text once and a missing target becomes a new note',
      () async {
        final env = await TransferEnv.create();
        addTearDown(env.dispose);
        await env.addNote(content: 'first');
        await store.ingest(native('a1', text: 'more'));
        final capture = (await store.pending()).single;
        Future<String> run(String target) => convertCapture(
          database: env.db,
          attachments: env.service,
          store: store,
          capture: capture,
          accountId: env.accountId,
          target: AppendTo(target),
        );
        expect(await run('n1'), 'n1');
        expect(await run('n1'), 'n1');
        expect(
          (await env.db.note(env.accountId, 'n1'))!.content,
          'first\n\nmore',
        );
        expect(await run('gone'), 'a1');
        expect((await env.db.note(env.accountId, 'a1'))!.content, 'more');
      },
    );
  });
}

class _CheckingSource implements CaptureSource {
  _CheckingSource(this.inner, this.store, this.seen);
  final _FakeSource inner;
  final CaptureStore store;
  final List<String> seen;
  @override
  Future<List<NativeCapture>> list() => inner.list();
  @override
  Future<void> ack(String id) async {
    final stored = (await store.pending()).any((c) => c.id == id);
    seen.add('$id ${stored ? 'stored' : 'MISSING'} at ack');
    await inner.ack(id);
  }
}
