import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nextcloudnotes/data/runtime.dart';
import 'package:nextcloudnotes/features/login.dart';
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

  Future<void> open(WidgetTester tester, http.Client transport) async {
    // The branded entry is taller than the default 800x600 test surface.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    runtime = (await tester.runAsync(
      () async => AppRuntime(NotesDatabase(NativeDatabase.memory()), Vault()),
    ))!;
    addTearDown(runtime.close);
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
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://cloud.test');
    await tester.tap(find.text('Connect'));
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
