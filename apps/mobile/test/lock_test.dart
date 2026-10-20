import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:nextcloudnotes/data/settings.dart';
import 'package:nextcloudnotes/features/lock.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:nextcloudnotes/main.dart' show resolveLocale;
import 'package:shared_preferences_platform_interface/types.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

class FakeAuth implements LocalAuthentication {
  FakeAuth({this.authenticateResult, this.supported});

  /// Null makes the call throw.
  bool? authenticateResult;
  bool? supported;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #authenticate:
        final r = authenticateResult;
        return r == null
            ? Future<bool>.error(StateError('auth down'))
            : Future.value(r);
      case #isDeviceSupported:
        final s = supported;
        return s == null
            ? Future<bool>.error(StateError('support down'))
            : Future.value(s);
    }
    return super.noSuchMethod(invocation);
  }
}

base class UnreadablePrefs extends InMemorySharedPreferencesAsync {
  UnreadablePrefs() : super.empty();
  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) =>
      Future.error(StateError('storage down'));
}

base class UnwritablePrefs extends InMemorySharedPreferencesAsync {
  UnwritablePrefs() : super.withData({'lock': false, 'secure': false});
  @override
  Future<bool> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) => Future.error(StateError('disk full'));
}

Future<void> pumpLock(
  WidgetTester tester,
  FakeAuth auth, {
  SharedPreferencesAsyncPlatform? prefs,
}) async {
  SharedPreferencesAsyncPlatform.instance =
      prefs ?? InMemorySharedPreferencesAsync.withData({'lock': true});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localAuthProvider.overrideWithValue(auth)],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppLock(child: Text('notes')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('successful authentication opens the app', (tester) async {
    await pumpLock(tester, FakeAuth(authenticateResult: true));
    expect(find.text('Unlock'), findsNothing);
    expect(find.text('notes'), findsOneWidget);
  });

  testWidgets('authentication and support check both failing stay locked', (
    tester,
  ) async {
    await pumpLock(tester, FakeAuth());
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(
      find.text('The lock could not be checked right now. Try again.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Turn off app lock and continue'), findsNothing);
  });

  testWidgets('a supported device whose authentication throws stays locked', (
    tester,
  ) async {
    await pumpLock(tester, FakeAuth(supported: true));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Turn off app lock and continue'), findsNothing);
  });

  testWidgets('a removed device lock needs an explicit choice', (tester) async {
    await pumpLock(tester, FakeAuth(supported: false));
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    await tester.tap(find.text('Turn off app lock and continue'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(await SharedPreferencesAsyncPlatform.instance!.getBool(
      'lock',
      const SharedPreferencesOptions(),
    ), isFalse);
  });

  testWidgets('unreadable preferences keep the app locked', (tester) async {
    await pumpLock(
      tester,
      FakeAuth(authenticateResult: true),
      prefs: UnreadablePrefs(),
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  test('a failed security write is reverted and reported', () async {
    SharedPreferencesAsyncPlatform.instance = UnwritablePrefs();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(settingsProvider.notifier);
    await controller.loaded;
    final failure = controller.saveFailures.first;
    await controller.update(container.read(settingsProvider).copyWith(lock: true));
    await failure;
    expect(container.read(settingsProvider).lock, isFalse);
  });

  test('locale falls back to English, matches by language code', () {
    const supported = [Locale('cs'), Locale('en')];
    expect(resolveLocale([const Locale('de', 'DE')], supported), const Locale('en'));
    expect(resolveLocale([const Locale('cs', 'CZ')], supported), const Locale('cs'));
    expect(
      resolveLocale([const Locale('de'), const Locale('cs')], supported),
      const Locale('cs'),
    );
    expect(resolveLocale(null, supported), const Locale('en'));
  });
}
