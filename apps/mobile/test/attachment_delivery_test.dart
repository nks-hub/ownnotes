import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/attachment_insertion.dart';
import 'package:nextcloudnotes/data/attachments/attachment_service.dart';
import 'package:nextcloudnotes/features/editor/attachment_actions.dart';
import 'package:nextcloudnotes/features/editor/format_dock.dart';

import 'support/transfer_fixtures.dart';

void main() {
  late TransferEnv env;
  setUp(() async {
    env = await TransferEnv.create();
    await env.addNote();
  });
  tearDown(() => env.dispose());

  test('closing waits for the picker and prevents a new insertion', () async {
    final delivery = EditorAttachmentDelivery();
    addTearDown(delivery.dispose);
    final picker = Completer<AttachmentInsertion?>();
    final insertion = delivery.insert(
      AttachKind.file,
      (_) => picker.future,
      editable: () => true,
      apply: (_) => fail('cancelled picker must not insert'),
      save: () async => fail('cancelled picker must not save'),
    );
    expect(delivery.beginClosing(), isFalse);
    picker.complete(null);
    await insertion;
    expect(delivery.beginClosing(), isTrue);
    await delivery.insert(
      AttachKind.file,
      (_) => fail('closing editor must not open a picker'),
      editable: () => true,
      apply: (_) => fail('closing editor must not insert'),
      save: () async => fail('closing editor must not save'),
    );
    delivery.cancelClosing();
    expect(delivery.beginClosing(), isTrue);
  });

  Future<AttachmentInsertion> upload(String name) async {
    final item = await env.service.stage(
      accountId: env.accountId,
      noteId: 'n1',
      source: await env.file(name),
      name: name,
      holdForEditor: true,
    );
    final outcome = await env.service.upload(item.id) as Uploaded;
    return AttachmentInsertion(
      markdown: outcome.markdown,
      service: env.service,
      ids: [item.id],
    );
  }

  Future<void> save(String content) async {
    final note = (await env.db.note(env.accountId, 'n1'))!;
    await env.db.saveDraft(
      accountId: env.accountId,
      id: note.id,
      revision: note.revision,
      title: note.title,
      content: content,
      category: note.category,
      favorite: note.favorite,
    );
  }

  test(
    'flush leaves files held by the editor alone before and after upload',
    () async {
      final item = await env.service.stage(
        accountId: env.accountId,
        noteId: 'n1',
        source: await env.file('held.pdf'),
        name: 'held.pdf',
        holdForEditor: true,
      );
      expect(await env.service.flush(env.accountId), 0);
      expect(env.server.uploads, isEmpty);
      expect(await env.service.upload(item.id), isA<Uploaded>());
      expect(await env.service.flush(env.accountId), 0);
      expect((await env.db.note(env.accountId, 'n1'))!.content, 'body');
      expect(await env.service.pending(env.accountId, 'n1'), hasLength(1));
    },
  );

  test(
    'restart after upload recovers the link without another upload',
    () async {
      final insertion = await upload('recovered.png');
      final restarted = env.restarted();
      expect(await restarted.flush(env.accountId), 1);
      expect(
        (await env.db.note(env.accountId, 'n1'))!.content,
        'body\n\n${insertion.markdown}',
      );
      expect(env.server.uploads, ['recovered.png']);
      expect(await restarted.pending(env.accountId, 'n1'), isEmpty);
      expect(await restarted.flush(env.accountId), 0);
    },
  );

  test(
    'restart after commit but before acknowledgment does not insert twice',
    () async {
      final insertion = await upload('saved.pdf');
      final body = '${insertion.markdown}\nbody';
      await save(body);
      final revision = (await env.db.note(env.accountId, 'n1'))!.revision;
      final restarted = env.restarted();
      expect(await restarted.flush(env.accountId), 1);
      final note = (await env.db.note(env.accountId, 'n1'))!;
      expect(note.content, body);
      expect(note.revision, revision);
      expect(env.server.uploads, ['saved.pdf']);
      expect(await restarted.pending(env.accountId, 'n1'), isEmpty);
    },
  );

  test(
    'a completed older write cannot acknowledge a newer insertion',
    () async {
      final delivery = EditorAttachmentDelivery();
      addTearDown(delivery.dispose);
      final first = await upload('first.pdf');
      var body = 'body';
      Future<void> insert(AttachmentInsertion value) => delivery.insert(
        AttachKind.file,
        (_) => value,
        editable: () => true,
        apply: (markdown) => body = '$body\n$markdown',
        save: () async {},
      );
      await insert(first);
      final olderWrite = delivery.snapshot();
      final olderBody = body;
      final second = await upload('second.pdf');
      await insert(second);
      await save(olderBody);
      await delivery.saved(olderWrite);
      expect(
        (await env.service.pending(env.accountId, 'n1')).single.name,
        'second.pdf',
      );
      expect(await env.service.flush(env.accountId), 0);
      await save(body);
      await delivery.saved(delivery.snapshot());
      expect(await env.service.pending(env.accountId, 'n1'), isEmpty);
      expect((await env.db.note(env.accountId, 'n1'))!.content, body);
    },
  );

  test(
    'failed saving keeps the receipt until retry or editor disposal',
    () async {
      final delivery = EditorAttachmentDelivery();
      final insertion = await upload('unsaved.pdf');
      await expectLater(
        delivery.insert(
          AttachKind.file,
          (_) => insertion,
          editable: () => true,
          apply: (_) {},
          save: () async => throw StateError('disk full'),
        ),
        throwsStateError,
      );
      expect(await env.service.pending(env.accountId, 'n1'), hasLength(1));
      expect(await env.service.flush(env.accountId), 0);
      delivery.dispose();
      expect(await env.service.flush(env.accountId), 1);
      expect(
        (await env.db.note(env.accountId, 'n1'))!.content,
        'body\n\n${insertion.markdown}',
      );
      expect(env.server.uploads, ['unsaved.pdf']);
    },
  );
}
