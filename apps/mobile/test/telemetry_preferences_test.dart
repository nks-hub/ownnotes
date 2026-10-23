import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/telemetry.dart';
import 'package:nextcloudnotes/core/telemetry_bootstrap.dart';
import 'package:nextcloudnotes/core/telemetry_preferences.dart';
import 'package:nextcloudnotes/core/telemetry_transport.dart';
import 'package:nextcloudnotes/features/settings/telemetry_controls.dart';
import 'package:nextcloudnotes/l10n/app_localizations.dart';
import 'package:rybbit_flutter_sdk/rybbit_flutter_sdk.dart';
// ignore: implementation_imports
import 'package:rybbit_flutter_sdk/src/services/http_client.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'settings_accounts_test.dart' show WriteFailsPrefs;

base class UnreadablePreferences extends InMemorySharedPreferencesAsync {
  UnreadablePreferences() : super.empty();

  @override
  Future<bool?> getBool(String key, SharedPreferencesOptions options) =>
      Future.error(StateError('preferences unavailable'));
}

class RecordingTransport implements RybbitTransport {
  int sent = 0;
  @override
  Future<bool> sendEvent(TrackPayload payload) async {
    sent++;
    return true;
  }

  @override
  Future<bool> sendIdentify(IdentifyPayload payload) async {
    sent++;
    return true;
  }

  @override
  Future<bool> hasSiteIcon(String siteId) async {
    sent++;
    return true;
  }

  @override
  Future<bool> uploadSiteIcon(String siteId, String base64Png) async {
    sent++;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'opt-out is persisted and discards queued analytics without a request',
    () async {
      final prefs = TelemetryPreferences();
      await prefs.load();
      final sender = RecordingTransport();
      final transport = ConsentTransport(sender, prefs);
      const event = TrackPayload(
        type: EventType.pageview,
        siteId: '1',
        pathname: '/note',
      );
      await transport.sendEvent(event);
      expect(sender.sent, 1);
      await prefs.save(false);
      expect(await transport.sendEvent(event), isTrue);
      expect(sender.sent, 1);
      final restarted = TelemetryPreferences();
      await restarted.load();
      expect(restarted.enabled, isFalse);
    },
  );

  test('failed preference write leaves the previous choice intact', () async {
    SharedPreferencesAsyncPlatform.instance = WriteFailsPrefs();
    final prefs = TelemetryPreferences();
    await prefs.load();
    await expectLater(prefs.save(false), throwsStateError);
    expect(prefs.enabled, isTrue);
  });

  test('unreadable preferences disable collection', () async {
    SharedPreferencesAsyncPlatform.instance = UnreadablePreferences();
    final prefs = TelemetryPreferences();
    await prefs.load();
    expect(prefs.enabled, isFalse);
    expect(prefs.loaded, isFalse);
  });

  testWidgets(
    'settings switch persists opt-out and explains restart for opt-in',
    (tester) async {
      await telemetryPreferences.load();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: TelemetryControls(
              config: TelemetryConfig(
                sentryDsn: 'https://key@sentry.example.invalid/1',
                rybbitHost: '',
                rybbitSiteId: '',
                environment: 'test',
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(telemetryPreferences.enabled, isFalse);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(telemetryPreferences.enabled, isTrue);
      expect(
        find.text('Diagnostics will start the next time you open the app.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('an unconfigured build opens without SDK initialization', (
    tester,
  ) async {
    await runWithTelemetry(
      config: const TelemetryConfig(
        sentryDsn: '',
        rybbitHost: '',
        rybbitSiteId: '',
        environment: 'test',
      ),
      appBuilder: (observers) {
        expect(observers, isEmpty);
        return const MaterialApp(home: Text('Notes'));
      },
    );
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);
    expect(Rybbit.isInitialized, isFalse);
  });

  testWidgets('opted-out configured build opens without contacting SDKs', (
    tester,
  ) async {
    await telemetryPreferences.save(false);
    await runWithTelemetry(
      config: const TelemetryConfig(
        sentryDsn: 'https://key@sentry.example.invalid/1',
        rybbitHost: 'https://rybbit.example.invalid',
        rybbitSiteId: '1',
        environment: 'test',
      ),
      appBuilder: (observers) {
        expect(observers, isEmpty);
        return const MaterialApp(home: Text('Notes'));
      },
    );
    await tester.pump();
    expect(find.text('Notes'), findsOneWidget);
    expect(Rybbit.isInitialized, isFalse);
  });
}
