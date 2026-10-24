import 'dart:async';
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/login.dart';
import 'package:nextcloudnotes/features/qr_login.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:notes_store/notes_store.dart';

import 'app_test.dart' show Vault;

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late AppRuntime runtime;
  late int polls;

  Future<void> open(
    WidgetTester tester,
    http.Client transport, {
    Future<QrLoginPayload?> Function(BuildContext)? scan,
    bool connect = true,
    bool reauth = false,
    Future<bool> Function(Uri)? browser,
  }) async {
    // The branded entry is taller than the default 800x600 test surface.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), Vault()),
    ))!;
    addTearDown(runtime.close);
    Account? existing;
    if (reauth) {
      existing = await tester.runAsync(() async {
        final id = await runtime.accounts.add(
          LoginCredentials(
            server: ServerBase.parse('https://cloud.test'),
            loginName: 'user',
            appPassword: 'old',
          ),
        );
        return (await runtime.database.account(id))!;
      });
    }
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
                    transport: transport,
                    openBrowser: browser ?? (_) async => true,
                    scan: scan,
                    reauthenticate: existing,
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
    await tester.pumpAndSettle();
    if (connect) {
      await tester.enterText(find.byType(TextField), 'https://cloud.test');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
    }
  }

  Future<void> advance(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(seconds: 1));
    }
  }

  MockClient server({required bool grant}) {
    polls = 0;
    return MockClient((r) async {
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
        return json({
          'login': 'https://cloud.test/index.php/login/v2/flow/x',
          'poll': {
            'token': 't',
            'endpoint': 'https://cloud.test/index.php/login/v2/poll',
          },
        });
      }
      if (r.url.path == '/index.php/apps/notes/api/v1/notes') {
        return http.Response(
          '[]',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      polls++;
      // The first poll fails like a backgrounded Android app's request.
      if (polls == 1) throw Exception('network blocked');
      if (!grant || polls == 2) return http.Response('', 404);
      return json({
        'server': 'https://cloud.test',
        'loginName': 'user',
        'appPassword': 'secret',
      });
    });
  }

  for (final oneTime in [false, true]) {
    testWidgets(
      'scanned credentials finish without browser flow, oneTime=$oneTime',
      (tester) async {
        final requests = <String>[];
        final transport = MockClient((r) async {
          requests.add('${r.method} ${r.url.path}');
          if (r.url.path == '/status.php') {
            return json({
              'installed': true,
              'maintenance': false,
              'needsDbUpgrade': false,
            });
          }
          if (r.url.path.endsWith('getapppassword-onetime')) {
            return json({
              'ocs': {
                'data': {'apppassword': 'exchanged'},
              },
            });
          }
          if (r.url.path.endsWith('/cloud/user')) {
            return json({
              'ocs': {
                'data': {'displayname': 'Test user'},
              },
            });
          }
          if (r.url.path.endsWith('/notes')) return json([]);
          throw StateError('unexpected request');
        });
        await open(
          tester,
          transport,
          connect: false,
          scan: (_) async => QrLoginCredentials(
            server: ServerBase.parse('https://cloud.test'),
            loginName: 'user',
            secret: 'scanned',
            isOneTime: oneTime,
          ),
        );
        await tester.ensureVisible(find.text('Scan a login code'));
        await tester.tap(find.text('Scan a login code'));
        await advance(tester, 4);
        final accounts = await tester.runAsync(
          () => runtime.database.watchAccounts().first,
        );
        expect(accounts!.single.loginName, 'user');
        expect(
          await runtime.vault.read(accounts.single.credentialRef),
          oneTime ? 'exchanged' : 'scanned',
        );
        expect(requests.any((r) => r.contains('/login/v2')), isFalse);
        expect(
          requests.where((r) => r.contains('getapppassword-onetime')).length,
          oneTime ? 1 : 0,
        );
      },
    );
  }

  for (final hasSecret in [false, true]) {
    testWidgets(
      'foreign QR does not change a frozen account or contact its server: $hasSecret',
      (tester) async {
        var requests = 0;
        final transport = MockClient((_) async {
          requests++;
          throw StateError('No request expected');
        });
        final other = ServerBase.parse('https://other.example.com');
        await open(
          tester,
          transport,
          connect: false,
          reauth: true,
          scan: (_) async => hasSecret
              ? QrLoginCredentials(
                  server: other,
                  loginName: 'other',
                  secret: 'unused',
                  isOneTime: true,
                )
              : QrLoginServerOnly(other),
        );
        await tester.ensureVisible(find.text('Scan a login code'));
        await tester.tap(find.text('Scan a login code'));
        await advance(tester, 2);
        expect(requests, 0);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'https://cloud.test',
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        expect(
          find.text(
            'Sign in with the same account. The stored account was not changed.',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'the validation error remains an independently announced accessibility node',
    (tester) async {
      await open(
        tester,
        MockClient((_) async => throw StateError('No request expected')),
        connect: false,
      );
      await tester.enterText(find.byType(TextField), 'http://cloud.test');
      await tester.ensureVisible(find.text('Continue'));
      await tester.tap(find.text('Continue'));
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a valid HTTPS Nextcloud address.'),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel('Enter a valid HTTPS Nextcloud address.'),
          findsOneWidget,
        );
        expect(find.text('Server address'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    },
  );

  testWidgets('maintenance prevents browser initialization', (tester) async {
    final paths = <String>[];
    await open(
      tester,
      MockClient((r) async {
        paths.add(r.url.path);
        return json({
          'installed': true,
          'maintenance': true,
          'needsDbUpgrade': false,
        });
      }),
    );
    await advance(tester, 2);
    expect(paths, ['/status.php']);
    expect(
      find.text('This server is currently in maintenance mode.'),
      findsOneWidget,
    );
  });

  testWidgets('leaving during readiness check never opens a late browser', (
    tester,
  ) async {
    final status = Completer<http.Response>();
    var opened = false;
    await open(
      tester,
      MockClient((_) => status.future),
      browser: (_) async {
        opened = true;
        return true;
      },
    );
    await tester.pump();
    await tester.binding.handlePopRoute();
    status.complete(
      json({'installed': true, 'maintenance': false, 'needsDbUpgrade': false}),
    );
    await advance(tester, 2);
    expect(opened, isFalse);
    expect(
      await tester.runAsync(() => runtime.database.watchAccounts().first),
      isEmpty,
    );
  });

  testWidgets('a failed poll is retried and the login completes', (
    tester,
  ) async {
    await open(tester, server(grant: true));
    await advance(tester, 6);
    expect(polls, 3);
    final accounts = await tester.runAsync(
      () => runtime.database.watchAccounts().first,
    );
    expect(accounts!.single.loginName, 'user');
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('cancel stops waiting without an error', (tester) async {
    await open(tester, server(grant: false));
    await advance(tester, 3);
    await tester.tap(find.text('Cancel'));
    await advance(tester, 3);
    final pollsAfterCancel = polls;
    await advance(tester, 3);
    expect(polls, pollsAfterCancel);
    expect(find.textContaining('Login failed'), findsNothing);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
