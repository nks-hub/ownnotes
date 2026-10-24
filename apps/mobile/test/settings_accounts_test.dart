import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/about.dart';
import 'package:nextcloudnotes/data/settings.dart';
import 'package:nextcloudnotes/features/accounts.dart';
import 'package:nextcloudnotes/features/lock.dart';
import 'package:nextcloudnotes/features/login.dart';
import 'package:nextcloudnotes/features/settings.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'app_test.dart' show Vault;
import 'lock_test.dart' show FakeAuth;

LoginCredentials creds(String server, String user, String password) =>
    LoginCredentials(
      server: ServerBase.parse(server),
      loginName: user,
      appPassword: password,
    );

/// Reads fine, refuses every write.
base class WriteFailsPrefs extends InMemorySharedPreferencesAsync {
  WriteFailsPrefs() : super.empty();
  @override
  Future<bool> setBool(
    String key,
    bool value,
    SharedPreferencesOptions options,
  ) => Future.error(StateError('disk full'));
  @override
  Future<bool> setString(
    String key,
    String value,
    SharedPreferencesOptions options,
  ) => Future.error(StateError('disk full'));
  @override
  Future<bool> setDouble(
    String key,
    double value,
    SharedPreferencesOptions options,
  ) => Future.error(StateError('disk full'));
}

Future<void> settle(WidgetTester tester, {int steps = 6}) async {
  for (var i = 0; i < steps; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// AppLock shows nothing until the stored settings are read.
Future<void> pumpApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await settle(tester);
}

Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  late AppRuntime runtime;

  Future<List<Account>> boot(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), Vault()),
    ))!;
    addTearDown(runtime.close);
    return (await tester.runAsync(() async {
      await runtime.accounts.add(creds('https://one.test', 'sam', 'pw1'));
      await runtime.accounts.add(creds('https://two.test', 'sam', 'pw2'));
      return runtime.database.watchAccounts().first;
    }))!;
  }

  Widget app(
    Widget home, {
    FakeAuth? auth,
    Locale? locale,
    double scale = 1,
    http.Client Function()? transport,
  }) => ProviderScope(
    overrides: [
      runtimeProvider.overrideWithValue(runtime),
      localAuthProvider.overrideWithValue(auth ?? FakeAuth(supported: true)),
      accountTransportProvider.overrideWithValue(
        transport ??
            () => MockClient((r) async => http.Response(jsonEncode({}), 404)),
      ),
    ],
    // The same wiring main.dart gets: preferences feed MaterialApp.
    child: Consumer(
      builder: (context, ref, _) => MaterialApp(
        locale: ref.watch(localeProvider) ?? locale ?? const Locale('en'),
        themeMode: ref.watch(themeModeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AppLock(child: child!),
        ),
        home: home,
      ),
    ),
  );

  group('account switcher', () {
    Widget opener(String currentId, Future<bool> Function()? before) => Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => showAccountSwitcher(
            context,
            currentId: currentId,
            beforeSwitch: before,
          ),
          child: const Text('open'),
        ),
      ),
    );

    testWidgets('phone sheet keeps same user names on two servers apart', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 900));
      await pumpApp(tester, app(opener(accounts.first.id, null)));
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('sam · one.test'), findsOneWidget);
      expect(find.text('sam · two.test'), findsOneWidget);
      expect(find.text('Manage accounts'), findsOneWidget);
      expect(find.text('Add account'), findsOneWidget);
      await close(tester);
    });

    testWidgets('wide windows get a popover instead of a sheet', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(1000, 800));
      await pumpApp(tester, app(opener(accounts.first.id, null)));
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Manage accounts'), findsOneWidget);
      await close(tester);
    });

    testWidgets('switching waits for the draft to be saved', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 900));
      var saved = true;
      var calls = 0;
      await pumpApp(
        tester,
        app(
          opener(accounts.first.id, () async {
            calls++;
            return saved;
          }),
        ),
      );
      final container = ProviderScope.containerOf(
        tester.element(find.text('open')),
      );

      saved = false;
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('sam · two.test'));
      await settle(tester);
      expect(calls, 1);
      expect(container.read(selectedAccountIdProvider), isNull);
      expect(
        find.text(
          'Could not save on this device, so the account was not switched.',
        ),
        findsOneWidget,
      );

      saved = true;
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('sam · two.test'));
      await settle(tester);
      expect(calls, 2);
      expect(container.read(selectedAccountIdProvider), accounts.last.id);
      await close(tester);
    });

    testWidgets('Manage accounts opens the accounts screen', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 900));
      await pumpApp(tester, app(opener(accounts.first.id, null)));
      await tester.tap(find.text('open'));
      await settle(tester);
      await tester.tap(find.text('Manage accounts'));
      await settle(tester);
      expect(find.byType(AccountsScreen), findsOneWidget);
      await close(tester);
    });
  });

  group('account removal', () {
    testWidgets('warns about unsent notes and offers to export them', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 900));
      await tester.runAsync(
        () => runtime.database.createDraft(
          accounts.first.id,
          title: 't',
          content: 'only here',
        ),
      );
      await pumpApp(tester, app(const AccountsScreen()));
      await settle(tester);
      await tester.tap(find.byType(PopupMenuButton<int>).first);
      await settle(tester);
      await tester.tap(find.text('Remove from this device').last);
      await settle(tester);
      expect(
        find.textContaining('1 note is not on the server yet'),
        findsOneWidget,
      );
      expect(find.text('Export unsent notes'), findsOneWidget);
      expect(
        find.textContaining('Notes on the server are not deleted'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(
        (await tester.runAsync(
          () => runtime.database.watchAccounts().first,
        ))!.length,
        2,
      );
      await close(tester);
    });

    testWidgets('details show user, server and status', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await boot(tester, const Size(411, 900));
      await pumpApp(tester, app(const AccountsScreen()));
      await settle(tester);
      await tester.tap(find.byType(PopupMenuButton<int>).first);
      await settle(tester);
      await tester.tap(find.text('Account details'));
      await settle(tester);
      expect(find.text('https://one.test'), findsOneWidget);
      expect(find.text('Signed in'), findsOneWidget);
      await close(tester);
    });
  });

  group('settings', () {
    testWidgets('theme and language are chosen and persisted', (tester) async {
      final prefs = InMemorySharedPreferencesAsync.empty();
      SharedPreferencesAsyncPlatform.instance = prefs;
      final accounts = await boot(tester, const Size(411, 1400));
      await pumpApp(tester, app(SettingsScreen(account: accounts.first)));
      await settle(tester);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      );
      expect(container.read(themeModeProvider), ThemeMode.system);
      expect(container.read(localeProvider), isNull);

      await tester.tap(find.text('Theme'));
      await settle(tester);
      await tester.tap(find.text('Dark'));
      await settle(tester);
      expect(container.read(themeModeProvider), ThemeMode.dark);

      await tester.tap(find.text('Language'));
      await settle(tester);
      await tester.tap(find.text('Čeština'));
      await settle(tester);
      expect(container.read(localeProvider), const Locale('cs'));
      expect(find.text('Jazyk'), findsOneWidget);

      expect(
        await tester.runAsync(
          () => prefs.getString('theme', const SharedPreferencesOptions()),
        ),
        'dark',
      );
      expect(
        await tester.runAsync(
          () => prefs.getString('language', const SharedPreferencesOptions()),
        ),
        'cs',
      );
      await close(tester);
    });

    test(
      'stored theme and language are read back, system clears them',
      () async {
        SharedPreferencesAsyncPlatform.instance =
            InMemorySharedPreferencesAsync.withData({
              'theme': 'light',
              'language': 'de',
            });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(settingsProvider.notifier);
        await controller.loaded;
        expect(container.read(themeModeProvider), ThemeMode.light);
        expect(container.read(localeProvider), const Locale('de'));
        await controller.update(
          container.read(settingsProvider).copyWith(systemLanguage: true),
        );
        expect(container.read(localeProvider), isNull);
        final again = ProviderContainer();
        addTearDown(again.dispose);
        await again.read(settingsProvider.notifier).loaded;
        expect(again.read(localeProvider), isNull);
      },
    );

    test(
      'a failed theme write reports it but keeps the choice for now',
      () async {
        SharedPreferencesAsyncPlatform.instance = WriteFailsPrefs();
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final controller = container.read(settingsProvider.notifier);
        await controller.loaded;
        final failure = controller.saveFailures.first;
        await controller.update(
          container.read(settingsProvider).copyWith(themeMode: ThemeMode.dark),
        );
        await failure;
        expect(container.read(themeModeProvider), ThemeMode.dark);
      },
    );

    testWidgets('a failed app lock write reverts the switch and says so', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance = WriteFailsPrefs();
      final accounts = await boot(tester, const Size(411, 1400));
      await pumpApp(tester, app(SettingsScreen(account: accounts.first)));
      await settle(tester);
      final lockSwitch = find.widgetWithText(SwitchListTile, 'App lock');
      await tester.ensureVisible(lockSwitch);
      await tester.tap(lockSwitch);
      await settle(tester);
      expect(tester.widget<SwitchListTile>(lockSwitch).value, isFalse);
      expect(
        find.text('Could not save the setting. It stays as it was.'),
        findsOneWidget,
      );
      await close(tester);
    });

    testWidgets('every settings row has a leading icon', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 3000));
      await pumpApp(tester, app(SettingsScreen(account: accounts.first)));
      final rows = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
      expect(rows.length, greaterThanOrEqualTo(9));
      for (final row in rows) {
        expect(row.leading, isNotNull, reason: '${row.title}');
        final leading = row.leading!;
        if (leading is Icon) expect(leading.size, anyOf(isNull, 24));
      }
      await close(tester);
    });

    testWidgets('groups and labels follow the specification', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 3000));
      await pumpApp(tester, app(SettingsScreen(account: accounts.first)));
      await settle(tester);
      for (final label in [
        'Appearance',
        'Writing',
        'Privacy',
        'Sync and storage',
        'Import and export',
        'Accounts',
        'About',
        'Export Markdown',
        'Home-screen widgets',
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await close(tester);
    });
  });

  group('login', () {
    Future<void> openLogin(
      WidgetTester tester,
      http.Client transport, {
      Account? reauth,
    }) async {
      await pumpApp(
        tester,
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    transport: transport,
                    openBrowser: (_) async => true,
                    reauthenticate: reauth,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await settle(tester);
    }

    testWidgets('an invalid address is explained in the family login banner', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await boot(tester, const Size(411, 900));
      await openLogin(tester, MockClient((r) async => http.Response('', 500)));
      await tester.enterText(find.byType(TextField), 'http://plain.test');
      await tester.tap(find.text('Continue'));
      await settle(tester);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.decoration!.errorText, isNull);
      expect(
        find.text('Enter a valid HTTPS Nextcloud address.'),
        findsOneWidget,
      );
      expect(field.controller!.text, 'http://plain.test');
      await close(tester);
    });

    testWidgets('an unreachable server gets a banner and keeps the text', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await boot(tester, const Size(411, 900));
      await openLogin(
        tester,
        MockClient((r) async => throw http.ClientException('down')),
      );
      await tester.enterText(find.byType(TextField), 'https://down.test');
      await tester.tap(find.text('Continue'));
      await settle(tester, steps: 8);
      expect(
        find.textContaining('The server could not be reached'),
        findsOneWidget,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'https://down.test',
      );
      await close(tester);
    });

    testWidgets('cancel returns to the form without an error notice', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await boot(tester, const Size(411, 900));
      final server = MockClient((r) async {
        if (r.url.path == '/status.php') {
          return http.Response(
            jsonEncode({
              'installed': true,
              'maintenance': false,
              'needsDbUpgrade': false,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (r.url.path == '/index.php/login/v2') {
          return http.Response(
            jsonEncode({
              'login': 'https://cloud.test/index.php/login/v2/flow/x',
              'poll': {
                'token': 't',
                'endpoint': 'https://cloud.test/index.php/login/v2/poll',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 404);
      });
      await openLogin(tester, server);
      await tester.enterText(find.byType(TextField), 'https://cloud.test');
      await tester.tap(find.text('Continue'));
      await settle(tester, steps: 4);
      expect(find.text('Finish signing in in your browser'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.text('Sign-in cancelled. Nothing was saved.'), findsNothing);
      expect(find.text('Continue'), findsOneWidget);
      await close(tester);
    });

    testWidgets('sign in again fixes the account and shows who it is', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 900));
      await openLogin(
        tester,
        MockClient((r) async => http.Response('', 500)),
        reauth: accounts.first,
      );
      expect(find.text('Sign in to this account again'), findsOneWidget);
      expect(find.text('Sign in again'), findsOneWidget);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(field.controller!.text, 'https://one.test');
      await close(tester);
    });

    testWidgets('the wide layout puts introduction and form side by side', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      await boot(tester, const Size(1100, 800));
      await openLogin(tester, MockClient((r) async => http.Response('', 500)));
      final title = tester.getTopLeft(find.text('Your notes, one app'));
      final field = tester.getTopLeft(find.byType(TextField));
      expect(field.dx, greaterThan(title.dx + 300));
      await close(tester);
    });
  });

  group('about', () {
    testWidgets('shows version, server versions and where to get help', (
      tester,
    ) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      PackageInfo.setMockInitialValues(
        appName: 'OwnNotes',
        packageName: 'com.nkshub.nextcloudnotes',
        version: '0.2.2',
        buildNumber: '5',
        buildSignature: '',
      );
      final accounts = await boot(tester, const Size(411, 1200));
      await pumpApp(
        tester,
        app(
          AboutScreen(account: accounts.first),
          transport: () => MockClient(
            (r) async => http.Response(
              jsonEncode({
                'ocs': {
                  'data': {
                    'version': {'string': '34.0.4'},
                    'capabilities': {
                      'notes': {'version': '6.1.0'},
                    },
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            ),
          ),
        ),
      );
      expect(find.text('Version 0.2.2 (5)'), findsOneWidget);
      expect(find.text('Server · one.test'), findsOneWidget);
      expect(find.text('Nextcloud 34.0.4 · Notes 6.1.0'), findsOneWidget);
      expect(find.text('Plain Markdown files'), findsOneWidget);
      expect(find.text('dev@nks-hub.cz'), findsOneWidget);
      expect(find.text('Open source licenses'), findsOneWidget);
      await close(tester);
    });

    testWidgets('an unreachable server is said plainly', (tester) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final accounts = await boot(tester, const Size(411, 1200));
      await pumpApp(tester, app(AboutScreen(account: accounts.first)));
      expect(
        find.text('The server did not report its version.'),
        findsOneWidget,
      );
      await close(tester);
    });
  });

  group('200% text on a 360 dp phone', () {
    Future<void> check(WidgetTester tester, Widget home, Locale locale) async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.withData({'lock': true});
      await pumpApp(
        tester,
        app(
          home,
          scale: 2,
          locale: locale,
          auth: FakeAuth(authenticateResult: false),
        ),
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    }

    for (final locale in [const Locale('cs'), const Locale('en')]) {
      testWidgets('login, accounts, settings, lock ($locale)', (tester) async {
        final accounts = await boot(tester, const Size(360, 740));
        await check(tester, const LoginScreen(), locale);
        await check(
          tester,
          LoginScreen(reauthenticate: accounts.first),
          locale,
        );
        await check(tester, const AccountsScreen(), locale);
        await check(tester, AboutScreen(account: accounts.first), locale);
        await check(tester, SettingsScreen(account: accounts.first), locale);
        await check(tester, const SizedBox(), locale);
      });
    }
  });
}
