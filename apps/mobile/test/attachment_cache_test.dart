import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/attachment_cache.dart';

void main() {
  late Directory directory;
  late AttachmentCache cache;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('attachment-cache-');
    cache = AttachmentCache(directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'preview and thumbnail share a download and one persisted result',
    () async {
      var requests = 0;
      final started = Completer<void>();
      final response = Completer<List<int>>();
      Future<List<int>> fetch() {
        requests++;
        if (!started.isCompleted) started.complete();
        return response.future;
      }

      final preview = cache.load('a', 7, 'image.png', fetch);
      final thumbnail = cache.load('a', 7, 'image.png', fetch);
      await started.future;
      response.complete([1, 2, 3]);
      final values = await Future.wait([preview, thumbnail]);
      expect(requests, 1);
      expect(values, [
        [1, 2, 3],
        [1, 2, 3],
      ]);
      expect(await cache.read('a', 7, 'image.png'), [1, 2, 3]);
      expect(() => values.first[0] = 9, throwsUnsupportedError);
      expect(values.last, [1, 2, 3]);
    },
  );

  test('concurrent failure is shared but the next request can retry', () async {
    var requests = 0;
    final started = Completer<void>();
    final response = Completer<List<int>>();
    Future<List<int>> fetch() {
      requests++;
      if (!started.isCompleted) started.complete();
      return response.future;
    }

    final both = Future.wait([
      cache.load('a', 7, 'image.png', fetch),
      cache.load('a', 7, 'image.png', fetch),
    ]);
    final failed = expectLater(both, throwsStateError);
    await started.future;
    response.completeError(StateError('offline'));
    await failed;
    expect(requests, 1);
    expect(await cache.contains('a', 7, 'image.png'), isFalse);
    expect(await cache.load('a', 7, 'image.png', () async => [4]), [4]);
  });

  test('download identity includes account, note and path', () async {
    final keys = [
      ('a', 7, 'one'),
      ('b', 7, 'one'),
      ('a', 8, 'one'),
      ('a', 7, 'two'),
    ];
    final entered = [for (final _ in keys) Completer<void>()];
    final release = Completer<void>();
    final requests = [
      for (var i = 0; i < keys.length; i++)
        cache.load(keys[i].$1, keys[i].$2, keys[i].$3, () async {
          entered[i].complete();
          await release.future;
          return [i];
        }),
    ];
    await Future.wait(entered.map((e) => e.future));
    release.complete();
    expect(await Future.wait(requests), [
      [0],
      [1],
      [2],
      [3],
    ]);
  });

  test(
    'forget fences a late download without detaching its replacement',
    () async {
      final entered = Completer<void>();
      final oldResponse = Completer<List<int>>();
      final old = cache.load('a', 7, 'image.png', () {
        entered.complete();
        return oldResponse.future;
      });
      await entered.future;
      await cache.forget('a', 7, 'image.png');
      final replacementEntered = Completer<void>();
      final newResponse = Completer<List<int>>();
      final replacement = cache.load('a', 7, 'image.png', () {
        replacementEntered.complete();
        return newResponse.future;
      });
      await replacementEntered.future;
      oldResponse.complete([1]);
      expect(await old, [1]);
      expect(await cache.contains('a', 7, 'image.png'), isFalse);
      final joined = cache.load(
        'a',
        7,
        'image.png',
        () => throw StateError('duplicate fetch'),
      );
      newResponse.complete([2]);
      expect(await replacement, [2]);
      expect(await joined, [2]);
      expect(await cache.read('a', 7, 'image.png'), [2]);
    },
  );

  test('clearing one account fences its pending downloads only', () async {
    final entered = [Completer<void>(), Completer<void>()];
    final response = Completer<List<int>>();
    final loads = [
      for (var i = 0; i < 2; i++)
        cache.load(i == 0 ? 'a' : 'b', 7, 'image.png', () {
          entered[i].complete();
          return response.future;
        }),
    ];
    await Future.wait(entered.map((e) => e.future));
    await cache.clearAccount('a');
    response.complete([1]);
    await Future.wait(loads);
    expect(await cache.contains('a', 7, 'image.png'), isFalse);
    expect(await cache.read('b', 7, 'image.png'), [1]);
  });

  test('uploaded bytes are not overwritten by an older download', () async {
    final entered = Completer<void>();
    final response = Completer<List<int>>();
    final old = cache.load('a', 7, 'image.png', () {
      entered.complete();
      return response.future;
    });
    await entered.future;
    await cache.write('a', 7, 'image.png', [2]);
    response.complete([1]);
    expect(await old, [1]);
    expect(await cache.read('a', 7, 'image.png'), [2]);
  });

  test(
    'independent cache instances never share a temporary write file',
    () async {
      final other = AttachmentCache(directory);
      final one = List.filled(131072, 1);
      final two = List.filled(262144, 2);
      expect(
        await Future.wait([
          cache.write('a', 7, 'image.png', one),
          other.write('a', 7, 'image.png', two),
        ]),
        [true, true],
      );
      final bytes = (await cache.read('a', 7, 'image.png'))!;
      expect(bytes, anyOf(equals(one), equals(two)));
      final leftovers = await directory
          .list(recursive: true)
          .where((f) => f.path.endsWith('.tmp'))
          .toList();
      expect(leftovers, isEmpty);
    },
  );
}
