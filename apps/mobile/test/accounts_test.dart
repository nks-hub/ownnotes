import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/accounts.dart';
import 'package:nextcloudnotes/features/login.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';

import 'app_test.dart' show Vault;

LoginCredentials creds(String server, String user, String password) =>
    LoginCredentials(
      server: ServerBase.parse(server),
      loginName: user,
      appPassword: password,
    );

http.Response ocs(Object data) => http.Response(
  jsonEncode({
    'ocs': {'data': data},
  }),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  late AppRuntime runtime;
  late Vault vault;
  late List<http.BaseRequest> requests;
  late bool serverDown;

  Future<void> open(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    vault = Vault();
    requests = [];
    serverDown = false;
    runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), vault),
    ))!;
    addTearDown(runtime.close);
    await tester.runAsync(() async {
      await runtime.accounts.add(creds('https://one.test', 'anna', 'pw1'));
      await runtime.accounts.add(creds('https://two.test', 'bob', 'pw2'));
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          runtimeProvider.overrideWithValue(runtime),
          accountTransportProvider.overrideWithValue(
            () => MockClient((r) async {
              requests.add(r);
              if (serverDown) throw Exception('offline');
              if (r.method == 'DELETE') return ocs({});
              return ocs(
                r.url.host == 'one.test' ? {'displayname': 'Anna Novak'} : {},
              );
            }),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await settle(tester);
  }

  testWidgets('lists accounts with initials, name and host', (tester) async {
    await open(tester, const AccountsScreen());
    expect(find.text('Anna Novak'), findsWidgets);
    expect(find.text('AN'), findsWidgets);
    expect(find.text('bob'), findsOneWidget);
    expect(find.text('anna · one.test'), findsOneWidget);
    expect(find.text('bob · two.test'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    await close(tester);
  });

  testWidgets('tapping another account switches to it', (tester) async {
    await open(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => openAccounts(context),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await settle(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AccountsScreen)),
    );
    expect(container.read(selectedAccountIdProvider), isNull);
    await tester.tap(find.text('bob'));
    await settle(tester);
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(
      container.read(selectedAccountIdProvider),
      accounts!.firstWhere((a) => a.loginName == 'bob').id,
    );
    expect(find.byType(AccountsScreen), findsNothing);
    await close(tester);
  });

  testWidgets('remove revokes on the server, then wipes local data', (
    tester,
  ) async {
    await open(tester, const AccountsScreen());
    await tester.tap(find.byType(PopupMenuButton<int>).last);
    await settle(tester);
    await tester.tap(find.text('Remove from this device').last);
    await settle(tester);
    await tester.tap(find.text('Remove from this device').last);
    await settle(tester);
    final revoke = requests.singleWhere((r) => r.method == 'DELETE');
    expect(revoke.url.toString(), startsWith('https://two.test/ocs/v2.php'));
    expect(revoke.url.path, endsWith('/core/apppassword'));
    expect(
      revoke.headers['Authorization'],
      'Basic ${base64Encode(utf8.encode('bob:pw2'))}',
    );
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(accounts!.map((a) => a.loginName), ['anna']);
    expect(vault.entries.values, ['pw1']);
    expect(find.textContaining('revoked on the server'), findsOneWidget);
    await close(tester);
  });

  testWidgets('remove still wipes locally when the server is unreachable', (
    tester,
  ) async {
    await open(tester, const AccountsScreen());
    serverDown = true;
    await tester.tap(find.byType(PopupMenuButton<int>).first);
    await settle(tester);
    await tester.tap(find.text('Remove from this device').last);
    await settle(tester);
    await tester.tap(find.text('Remove from this device').last);
    await settle(tester);
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(accounts!.map((a) => a.loginName), ['bob']);
    expect(find.textContaining('did not confirm'), findsOneWidget);
    await close(tester);
  });

  test('reauthenticate keeps id and notes, refuses another identity', () async {
    final vault = Vault();
    final runtime = AppRuntime(NotesDatabase(NativeDatabase.memory()), vault);
    addTearDown(runtime.close);
    final id = await runtime.accounts.add(
      creds('https://one.test', 'anna', 'old'),
    );
    await runtime.database.createDraft(id, title: 't', content: 'draft');
    await expectLater(
      runtime.accounts.reauthenticate(
        id,
        creds('https://one.test', 'eve', 'x'),
      ),
      throwsStateError,
    );
    await expectLater(
      runtime.accounts.reauthenticate(
        id,
        creds('https://other.test', 'anna', 'x'),
      ),
      throwsStateError,
    );
    expect(vault.entries.values, ['old']);
    await runtime.accounts.reauthenticate(
      id,
      creds('https://one.test', 'anna', 'new'),
    );
    expect(vault.entries.values, ['new']);
    final accounts = await runtime.database.watchAccounts().first;
    expect(accounts.single.id, id);
    expect(
      (await runtime.database.watchNotes(id).first).single.content,
      'draft',
    );
  });

  testWidgets('adding an existing server and user keeps one account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    vault = Vault();
    runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), vault),
    ))!;
    addTearDown(runtime.close);
    final id = (await tester.runAsync(
      () => runtime.accounts.add(creds('https://one.test', 'anna', 'old')),
    ))!;
    http.Response js(Object o) => http.Response(
      jsonEncode(o),
      200,
      headers: {'content-type': 'application/json'},
    );
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
        return js({
          'login': 'https://one.test/index.php/login/v2/flow/x',
          'poll': {
            'token': 't',
            'endpoint': 'https://one.test/index.php/login/v2/poll',
          },
        });
      }
      if (r.url.path == '/index.php/apps/notes/api/v1/notes') return js([]);
      return js({
        'server': 'https://one.test',
        'loginName': 'anna',
        'appPassword': 'fresh',
      });
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    transport: server,
                    openBrowser: (_) async => true,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'one.test');
    await tester.tap(find.text('Continue'));
    await settle(tester, seconds: 4);
    expect(find.byType(LoginScreen), findsNothing);
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(accounts!.map((a) => a.id), [id]);
    expect(vault.entries.values, ['fresh']);
    await close(tester);
  });

  testWidgets('sign in again replaces the password of the same account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    vault = Vault();
    late final MockClient server;
    runtime = (await tester.runAsync(
      () async => AppRuntime(
        NotesDatabase(NativeDatabase.memory()),
        vault,
        transport: () => server,
      ),
    ))!;
    addTearDown(runtime.close);
    final id = (await tester.runAsync(
      () => runtime.accounts.add(creds('https://one.test', 'anna', 'old')),
    ))!;
    final account = (await tester.runAsync(
      () => runtime.database.account(id),
    ))!;
    await tester.runAsync(
      () => runtime.database.recordSyncResult(
        id,
        completed: false,
        problem: 'auth',
      ),
    );
    var user = 'anna';
    server = MockClient((r) async {
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
            'login': 'https://one.test/index.php/login/v2/flow/x',
            'poll': {
              'token': 't',
              'endpoint': 'https://one.test/index.php/login/v2/poll',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.url.path == '/index.php/apps/notes/api/v1/notes') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      if (r.method == 'DELETE') return ocs({});
      return http.Response(
        jsonEncode({
          'server': 'https://one.test',
          'loginName': user,
          'appPassword': 'fresh',
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => LoginScreen(
                    transport: server,
                    openBrowser: (_) async => true,
                    reauthenticate: account,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await settle(tester);
    expect(find.text('Sign in again'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    user = 'mallory';
    await tester.tap(find.text('Sign in again'));
    await settle(tester, seconds: 4);
    expect(find.textContaining('same account'), findsOneWidget);
    expect(vault.entries.values, ['old']);
    user = 'anna';
    await tester.tap(find.text('Sign in again'));
    await settle(tester, seconds: 4);
    expect(find.byType(LoginScreen), findsNothing);
    expect(vault.entries.values, ['fresh']);
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(accounts!.single.id, id);
    // A new pass runs at once, so the old password problem goes away.
    final problems = await tester.runAsync(
      () => runtime.database.storedProblems(),
    );
    expect(problems, isNot(contains(id)));
    await close(tester);
  });
}

Future<void> settle(WidgetTester tester, {int seconds = 1}) async {
  for (var i = 0; i < seconds * 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Unmounts the tree and lets drift's stream cleanup timers run.
Future<void> close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 10));
}
