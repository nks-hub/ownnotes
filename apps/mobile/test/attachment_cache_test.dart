import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/data/attachments/attachment_cache.dart';

Future<bool> _writeFromIsolate(String path, int marker) => AttachmentCache(
  Directory(path),
).write('a', 7, 'image.png', List.filled(131072 * marker, marker));

void main() {
  late Directory directory;
  late AttachmentCache cache;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('attachment-cache-');
    cache = AttachmentCache(directory);
  });
  tearDown(() => directory.delete(recursive: true));

  test(
    'trimming removes only abandoned temporary files of this cache',
    () async {
      final folder = await Directory(
        '${directory.path}/a/7',
      ).create(recursive: true);
      const suffix = '0123456789abcdef0123456789abcdef';
      const oldName = '0123456789abcdef.$suffix.tmp';
      final old = File('${folder.path}/$oldName');
      await old.writeAsString('unfinished');
      await old.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final preserved = [
        File('${folder.path}/fedcba9876543210.$suffix.tmp'),
        File('${folder.path}/0123456789abcdef.tmp'),
        File('${folder.path}/foreign-$oldName'),
        File('${folder.path}/foreign.tmp'),
      ];
      for (var i = 0; i < preserved.length; i++) {
        await preserved[i].writeAsString('keep');
        await preserved[i].setLastModified(
          DateTime.now().subtract(
            i == 0 ? const Duration(hours: 23) : const Duration(days: 2),
          ),
        );
      }
      expect(await cache.write('a', 7, 'image.png', [1, 2, 3]), isTrue);
      expect(await old.exists(), isFalse);
      for (final file in preserved) {
        expect(await file.readAsString(), 'keep');
      }
      expect(await cache.read('a', 7, 'image.png'), [1, 2, 3]);
    },
  );

  test(
    'a locked abandoned temp does not fail a successful cache write',
    () async {
      final folder = await Directory(
        '${directory.path}/a/7',
      ).create(recursive: true);
      final old = File(
        '${folder.path}/0123456789abcdef.0123456789abcdef0123456789abcdef.tmp',
      );
      await old.writeAsString('unfinished');
      await old.setLastModified(
        DateTime.now().subtract(const Duration(days: 2)),
      );
      final held = await old.open();
      try {
        expect(await cache.write('a', 7, 'image.png', [1]), isTrue);
        expect(await old.exists(), isTrue);
        expect(await cache.read('a', 7, 'image.png'), [1]);
      } finally {
        await held.close();
      }
      await cache.write('a', 7, 'other.png', [2]);
      expect(await old.exists(), isFalse);
    },
    skip: !Platform.isWindows,
  );

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

  test(
    'isolates sharing a new cache directory publish complete files',
    () async {
      final path = '${directory.path}/shared';
      final results = await Future.wait([
        for (final marker in [1, 2, 3])
          Isolate.run(() => _writeFromIsolate(path, marker)),
      ]);
      expect(results, everyElement(isTrue));
      final shared = AttachmentCache(Directory(path));
      final bytes = (await shared.read('a', 7, 'image.png'))!;
      expect(bytes.first, isIn([1, 2, 3]));
      expect(bytes.length, 131072 * bytes.first);
      expect(bytes, everyElement(bytes.first));
      expect(await shared.sizeBytes(), bytes.length);
      expect(
        await Directory(
          path,
        ).list(recursive: true).where((f) => f.path.endsWith('.tmp')).toList(),
        isEmpty,
      );
    },
  );

  test('trimming a shared cache keeps its coordination usable', () async {
    final limited = AttachmentCache(directory, maxTotalBytes: 8);
    final other = AttachmentCache(directory, maxTotalBytes: 8);
    expect(await limited.write('a', 7, 'first.png', List.filled(8, 1)), isTrue);
    expect(await other.write('a', 7, 'second.png', List.filled(8, 2)), isTrue);
    expect(await limited.sizeBytes(), lessThanOrEqualTo(8));
    expect(await limited.write('a', 7, 'third.png', List.filled(8, 3)), isTrue);
    expect(await other.read('a', 7, 'third.png'), List.filled(8, 3));
  });

  test(
    'unavailable cache storage does not hide a successful download',
    () async {
      final blocked = File('${directory.path}/not-a-directory');
      await blocked.writeAsString('keep');
      final unavailable = AttachmentCache(Directory(blocked.path));
      expect(await unavailable.contains('a', 7, 'image.png'), isFalse);
      expect(await unavailable.read('a', 7, 'image.png'), isNull);
      expect(
        await unavailable.load('a', 7, 'image.png', () async => [1, 2, 3]),
        [1, 2, 3],
      );
      expect(await blocked.readAsString(), 'keep');
    },
  );
}
