import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/background.dart';
import 'package:nextcloudnotes/data/background_policy.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/settings/background_sync_controls.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:workmanager/workmanager.dart';

import 'app_test.dart' show Vault;
import 'settings_accounts_test.dart' show WriteFailsPrefs;
import 'transfers_ui_test.dart' show until;

void platformTest(String name, WidgetTesterCallback body) =>
    testWidgets(name, (tester) async {
      try {
        await body(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

class Schedule extends WorkmanagerPlatform {
  final intervals = <Duration?>[];
  final cancelled = <String>[];
  final policies = <ExistingPeriodicWorkPolicy?>[];
  int once = 0;
  bool fail = false;

  @override
  Future<void> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {}

  @override
  Future<void> cancelByUniqueName(String uniqueName) async =>
      cancelled.add(uniqueName);

  @override
  Future<void> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    Duration? frequency,
    Duration? flexInterval,
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingPeriodicWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    ForegroundServiceConfig? foregroundServiceConfig,
  }) async {
    if (fail) throw StateError('scheduler unavailable');
    expect(uniqueName, 'ownnotes-sync');
    expect(constraints?.networkType, NetworkType.connected);
    intervals.add(frequency);
    policies.add(existingWorkPolicy);
  }

  @override
  Future<void> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy? existingWorkPolicy,
    BackoffPolicy? backoffPolicy,
    Duration? backoffPolicyDelay,
    String? tag,
    OutOfQuotaPolicy? outOfQuotaPolicy,
    ForegroundServiceConfig? foregroundServiceConfig,
    bool expedited = false,
  }) async {
    expect(existingWorkPolicy, ExistingWorkPolicy.keep);
    expect(taskName, 'ownnotes-sync-once');
    once++;
  }
}

base class DelayedPreferences extends InMemorySharedPreferencesAsync {
  DelayedPreferences() : super.empty();
  final written = Completer<void>();
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) async {
    await written.future;
    return super.setString(key, value, options);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The first construction registers the host platform and replaces any fake.
  Workmanager();
  late Schedule schedule;
  late WorkmanagerPlatform previous;
  var network = <String>['wifi'];
  const connectivity = MethodChannel('dev.fluttercommunity.plus/connectivity');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    previous = WorkmanagerPlatform.instance;
    schedule = Schedule();
    WorkmanagerPlatform.instance = schedule;
    network = ['wifi'];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (_) async => network);
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    WorkmanagerPlatform.instance = previous;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, null);
  });

  test(
    'an existing installation retains the 15-minute connected schedule',
    () async {
      await scheduleBackgroundSync();
      expect(schedule.intervals, [const Duration(minutes: 15)]);
      expect(schedule.policies, [ExistingPeriodicWorkPolicy.update]);
      expect(schedule.cancelled, isEmpty);
    },
  );

  test(
    'changing the interval updates existing work and disabling cancels both jobs',
    () async {
      await const BackgroundSyncPreferences(minutes: 60, wifiOnly: true).save();
      await scheduleBackgroundSync();
      await syncWhenOnline();
      expect(schedule.intervals.single, const Duration(hours: 1));
      expect(schedule.once, 1);
      await const BackgroundSyncPreferences(minutes: 0, wifiOnly: true).save();
      await scheduleBackgroundSync();
      await syncWhenOnline();
      expect(schedule.cancelled, ['ownnotes-sync-once', 'ownnotes-sync']);
      expect(schedule.once, 1);
      expect(await backgroundSyncAllowed(), isFalse);
    },
  );

  test('a scheduler failure does not prevent a later retry', () async {
    schedule.fail = true;
    await expectLater(scheduleBackgroundSync(), throwsStateError);
    schedule.fail = false;
    await scheduleBackgroundSync();
    expect(schedule.intervals, [const Duration(minutes: 15)]);
  });

  test(
    'Wi-Fi policy is reread before each request, including a later settings change',
    () async {
      var sent = 0;
      final client = BackgroundSyncClient(
        MockClient((_) async {
          sent++;
          return http.Response('ok', 200);
        }),
      );
      addTearDown(client.close);
      final url = Uri.parse('https://cloud.test/');
      await const BackgroundSyncPreferences(wifiOnly: true).save();
      await client.get(url);
      network = ['mobile'];
      await expectLater(client.get(url), throwsA(isA<http.ClientException>()));
      network = ['vpn'];
      await expectLater(client.get(url), throwsA(isA<http.ClientException>()));
      network = ['wifi', 'vpn'];
      await client.get(url);
      await const BackgroundSyncPreferences(minutes: 0).save();
      await expectLater(client.get(url), throwsA(isA<http.ClientException>()));
      expect(sent, 2);
    },
  );

  test(
    'all-network mode permits cellular without weakening foreground clients',
    () async {
      network = ['mobile'];
      expect(await backgroundSyncAllowed(), isTrue);
      await const BackgroundSyncPreferences(wifiOnly: true).save();
      final foreground = MockClient((_) async => http.Response('ok', 200));
      addTearDown(foreground.close);
      expect(
        (await foreground.get(Uri.parse('https://cloud.test/'))).statusCode,
        200,
      );
    },
  );

  test(
    'paused and Wi-Fi-blocked workers never open the database or network',
    () async {
      AppRuntime mustNotOpen() => throw StateError('worker opened');
      await const BackgroundSyncPreferences(minutes: 0).save();
      expect(await runBackgroundSync(openRuntime: mustNotOpen), isTrue);
      await const BackgroundSyncPreferences(wifiOnly: true).save();
      network = ['mobile'];
      expect(await runBackgroundSync(openRuntime: mustNotOpen), isTrue);
      expect(
        await runBackgroundSync(
          openRuntime: mustNotOpen,
          retryWhenBlocked: true,
        ),
        isFalse,
      );
      await SharedPreferencesAsync().setString('backgroundSync', 'broken');
      await expectLater(
        runBackgroundSync(openRuntime: mustNotOpen),
        throwsFormatException,
      );
    },
  );

  test('allowed worker stores server notes and closes its database', () async {
    final dir = await Directory.systemTemp.createTemp('background-sync-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/notes.sqlite');
    final vault = Vault();
    final runtime = AppRuntime(
      NotesDatabase(NativeDatabase(file)),
      vault,
      transport: () => BackgroundSyncClient(
        MockClient(
          (_) async => http.Response(
            jsonEncode([
              {
                'id': 5,
                'etag': 'a',
                'title': 'Server note',
                'content': 'Background text',
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
    await runtime.accounts.add(
      LoginCredentials(
        server: ServerBase.parse('https://cloud.test/'),
        loginName: 'user',
        appPassword: 'secret',
      ),
    );
    await const BackgroundSyncPreferences(wifiOnly: true).save();
    expect(await runBackgroundSync(openRuntime: () => runtime), isTrue);
    final reopened = NotesDatabase(NativeDatabase(file));
    try {
      expect(
        (await reopened.select(reopened.localNotes).getSingle()).content,
        'Background text',
      );
    } finally {
      await reopened.close();
    }
  });

  Widget screen({double scale = 1, Locale locale = const Locale('en')}) =>
      ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(child: BackgroundSyncControls()),
          ),
        ),
      );

  platformTest(
    'interval and Wi-Fi choices persist and are reapplied after reopening',
    (tester) async {
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('background-sync-interval')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every hour'));
      await tester.pumpAndSettle();
      await until(
        tester,
        () =>
            find.byType(SwitchListTile).evaluate().isNotEmpty &&
            tester
                    .widget<SwitchListTile>(find.byType(SwitchListTile))
                    .onChanged !=
                null,
      );
      await tester.tap(find.byKey(const Key('background-sync-wifi')));
      await tester.pumpAndSettle();
      expect((await BackgroundSyncPreferences.load()).minutes, 60);
      expect((await BackgroundSyncPreferences.load()).wifiOnly, isTrue);
      expect(schedule.intervals.last, const Duration(hours: 1));
      await until(
        tester,
        () =>
            tester
                .widget<SwitchListTile>(find.byType(SwitchListTile))
                .onChanged !=
            null,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.text('Every hour'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
    },
  );

  platformTest(
    'leaving settings during a write still applies the new schedule',
    (tester) async {
      final preferences = DelayedPreferences();
      SharedPreferencesAsyncPlatform.instance = preferences;
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('background-sync-wifi')));
      await tester.pumpWidget(const SizedBox());
      preferences.written.complete();
      await until(tester, () => schedule.intervals.isNotEmpty);
      expect((await BackgroundSyncPreferences.load()).wifiOnly, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  platformTest('failed persistence leaves the saved Wi-Fi switch off', (
    tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance = WriteFailsPrefs();
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-sync-wifi')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(find.text('Could not save or apply sync settings.'), findsOneWidget);
    expect(schedule.intervals, isEmpty);
  });

  platformTest('Czech controls fit a 360 dp phone with 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(scale: 2, locale: const Locale('cs')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('background-sync-interval')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Každou hodinu'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Každou hodinu'), findsOneWidget);
    await until(
      tester,
      () =>
          tester
              .widget<SwitchListTile>(find.byType(SwitchListTile))
              .onChanged !=
          null,
    );
  });

  platformTest('Android-only controls are absent on iOS', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsNothing);
    expect(schedule.intervals, isEmpty);
  });
}
