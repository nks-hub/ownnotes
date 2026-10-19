import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nextcloudnotes/core/telemetry.dart';

void main() {
  group('TelemetryConfig', () {
    test('a build without configuration reports nothing', () {
      // The default for anyone building this client for their own Nextcloud.
      const config = TelemetryConfig(
        sentryDsn: '',
        rybbitHost: '',
        rybbitSiteId: '',
        environment: 'development',
      );
      expect(config.crashReportingEnabled, isFalse);
      expect(config.analyticsEnabled, isFalse);
      expect(config.releaseGateEnabled, isFalse);
    });

    test('a malformed DSN disables crash reporting instead of guessing', () {
      for (final dsn in const ['not-a-url', 'https://', '://nowhere', ' ']) {
        final config = TelemetryConfig(
          sentryDsn: dsn,
          rybbitHost: '',
          rybbitSiteId: '',
          environment: 'production',
        );
        expect(
          config.crashReportingEnabled,
          isFalse,
          reason: 'DSN "$dsn" must not switch reporting on',
        );
      }
    });

    test('analytics needs both the host and the site', () {
      const host = 'https://rybbit.example.invalid';
      expect(
        const TelemetryConfig(
          sentryDsn: '',
          rybbitHost: host,
          rybbitSiteId: '',
          environment: 'production',
        ).analyticsEnabled,
        isFalse,
      );
      expect(
        const TelemetryConfig(
          sentryDsn: '',
          rybbitHost: '',
          rybbitSiteId: '7',
          environment: 'production',
        ).analyticsEnabled,
        isFalse,
      );
      expect(
        const TelemetryConfig(
          sentryDsn: '',
          rybbitHost: host,
          rybbitSiteId: '7',
          environment: 'production',
        ).analyticsEnabled,
        isTrue,
      );
    });

    test('a configured build reports', () {
      const config = TelemetryConfig(
        sentryDsn: 'https://key@sentry.example.invalid/1',
        rybbitHost: 'https://rybbit.example.invalid',
        rybbitSiteId: '7',
        environment: 'production',
      );
      expect(config.crashReportingEnabled, isTrue);
      expect(config.analyticsEnabled, isTrue);
    });

    test('release gate is explicit and off by default', () {
      const enabled = TelemetryConfig(
        sentryDsn: 'https://key@sentry.example.invalid/1',
        rybbitHost: '',
        rybbitSiteId: '',
        environment: 'production',
        releaseGateEnabled: true,
      );
      expect(enabled.releaseGateEnabled, isTrue);
      expect(
        const TelemetryConfig(
          sentryDsn: '',
          rybbitHost: '',
          rybbitSiteId: '',
          environment: 'development',
        ).releaseGateEnabled,
        isFalse,
      );
    });
  });

  group('TelemetryScrubber', () {
    const scrubber = TelemetryScrubber();

    test('a Notes URL loses both the server and the note id', () {
      const message =
          'failed PUT https://cloud.example.invalid/index.php/apps/notes/api/v1/notes/4711';
      final scrubbed = scrubber.scrub(message);
      expect(scrubbed, isNot(contains('cloud.example.invalid')));
      expect(scrubbed, isNot(contains('4711')));
      expect(scrubbed, contains('https://<host>'));
    });

    test('a server path never leaves the device', () {
      final scrubbed = scrubber.scrub(
        'https://cloud.example.invalid/nextcloud/index.php/login/v2/poll',
      );
      expect(scrubbed, isNot(contains('nextcloud')));
      expect(scrubbed, isNot(contains('login')));
    });

    test('credentials are removed', () {
      for (final secret in const [
        'Authorization: Basic c2VjcmV0OnZhbHVl',
        'bearer abcdef123456',
      ]) {
        expect(scrubber.scrub(secret), contains('<redacted>'));
        expect(scrubber.scrub(secret), isNot(contains('abcdef123456')));
        expect(scrubber.scrub(secret), isNot(contains('c2VjcmV0OnZhbHVl')));
      }
    });

    test('ordinary text is left alone', () {
      const plain = 'RangeError: index 5 out of range';
      expect(scrubber.scrub(plain), plain);
      expect(scrubber.scrub(''), isEmpty);
    });
  });

  group('InstallationId', () {
    test('is random, opaque and not derived from anything', () {
      final first = InstallationId.generate(Random(1));
      final second = InstallationId.generate(Random(2));
      expect(first.isValid, isTrue);
      expect(second.isValid, isTrue);
      expect(first.value, isNot(second.value));
    });

    test('rejects a stored value that is not one of ours', () {
      const notHex = 'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz';
      for (final value in const ['', 'abc', notHex]) {
        expect(InstallationId(value).isValid, isFalse);
      }
    });
  });
}
