import 'package:flutter/widgets.dart';
import 'package:rybbit_flutter_sdk/rybbit_flutter_sdk.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'telemetry.dart';

/// Starts the app, with crash reporting and analytics attached only when the
/// build carries the corresponding configuration.
///
/// A build without a DSN or a Rybbit host never touches either SDK, so a
/// third-party build of this client reports nowhere. Neither SDK is allowed to
/// fail the launch: telemetry is diagnostics, not a feature the user asked for.
Future<void> runWithTelemetry({
  required TelemetryConfig config,
  required Widget Function(List<NavigatorObserver> observers) appBuilder,
  InstallationIdStore installationIds = const InstallationIdStore(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!config.crashReportingEnabled && !config.analyticsEnabled) {
    runApp(appBuilder(const []));
    return;
  }

  final installation = await installationIds.read();
  final observers = <NavigatorObserver>[];

  if (config.analyticsEnabled) {
    try {
      await Rybbit.init(
        host: config.rybbitHost,
        siteId: config.rybbitSiteId,
        anonymousId: installation?.value,
        // Errors belong to Sentry, which scrubs them first. Rybbit's own
        // handler would ship the raw message and claim FlutterError.onError
        // from under the Sentry integration.
        autoTrackErrors: false,
        globalProperties: {'environment': config.environment},
      );
      observers.add(RybbitNavigatorObserver());
    } on Object {
      // Analytics is never worth a failed launch.
    }
  }

  if (!config.crashReportingEnabled) {
    runApp(appBuilder(observers));
    return;
  }

  observers.add(SentryNavigatorObserver());
  await SentryFlutter.init((options) {
    configureSentryOptions(options, config: config);
  }, appRunner: () => runApp(appBuilder(observers)));

  if (installation != null) {
    await Sentry.configureScope(
      (scope) => scope.setUser(SentryUser(id: installation.value)),
    );
  }
  if (config.releaseGateEnabled) {
    // Explicit pre-release probe: proves that an event really arrives.
    await Sentry.captureException(
      const TelemetryReleaseGateError(),
      stackTrace: StackTrace.current,
    );
  }
}

final class TelemetryReleaseGateError implements Exception {
  const TelemetryReleaseGateError();

  @override
  String toString() => 'TelemetryReleaseGateError';
}

void configureSentryOptions(
  SentryFlutterOptions options, {
  required TelemetryConfig config,
}) {
  options
    ..dsn = config.sentryDsn
    ..environment = config.environment
    ..enableAppHangTracking = true
    ..enableAutoNativeBreadcrumbs = true
    ..enableMemoryPressureBreadcrumbs = false
    // Everything below keeps note text, titles and server addresses on the
    // device: those are either off or scrubbed.
    ..sendDefaultPii = false
    ..attachScreenshot = false
    // Automatic tracing can expose server URLs.
    ..tracesSampleRate = 0
    ..beforeBreadcrumb = scrubSentryBreadcrumb
    ..beforeSend = (event, hint) => scrubSentryEvent(event);
}

const _scrubber = TelemetryScrubber();

/// Removes URLs and credentials from everything an event carries as text.
///
/// [SentryEvent.request] goes entirely: a Notes request URL names the server
/// and the note id, and the failing call is already identifiable from the
/// stack.
SentryEvent scrubSentryEvent(SentryEvent event) {
  event.request = null;
  final message = event.message;
  if (message != null) {
    event.message = SentryMessage(_scrubber.scrub(message.formatted));
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    final value = exception.value;
    if (value != null) {
      exception.value = _scrubber.scrub(value);
    }
  }
  return event;
}

Breadcrumb? scrubSentryBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null) {
    return null;
  }
  final message = breadcrumb.message;
  if (message != null) {
    breadcrumb.message = _scrubber.scrub(message);
  }
  final data = breadcrumb.data;
  if (data != null) {
    for (final entry in data.entries.toList()) {
      final value = entry.value;
      if (value is String) {
        data[entry.key] = _scrubber.scrub(value);
      }
    }
  }
  return breadcrumb;
}
