import 'package:flutter/widgets.dart';
import 'package:rybbit_flutter_sdk/rybbit_flutter_sdk.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// ignore: implementation_imports
import 'package:rybbit_flutter_sdk/src/services/http_client.dart';

import 'telemetry.dart';
import 'telemetry_preferences.dart';
import 'telemetry_transport.dart';

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

  await telemetryPreferences.load();
  if (!telemetryPreferences.enabled) {
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
        transport: ConsentTransport(
          RybbitHttpClient(host: config.rybbitHost),
          telemetryPreferences,
        ),
        anonymousId: installation?.value,
        // Errors belong to Sentry, which scrubs them first. Rybbit's own
        // handler would ship the raw message and claim FlutterError.onError
        // from under the Sentry integration.
        autoTrackErrors: false,
        globalProperties: {'environment': config.environment},
      );
      observers.add(TelemetryNavigatorObserver());
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
    ..enableAutoNativeBreadcrumbs = false
    ..enableUserInteractionBreadcrumbs = false
    ..enableUserInteractionTracing = false
    ..enableMemoryPressureBreadcrumbs = false
    // Everything below keeps note text, titles and server addresses on the
    // device: those are either off or scrubbed.
    ..sendDefaultPii = false
    ..attachScreenshot = false
    // Automatic tracing can expose server URLs.
    ..tracesSampleRate = 0
    ..beforeBreadcrumb = scrubSentryBreadcrumb
    ..beforeSend = (event, hint) =>
        telemetryPreferences.enabled ? scrubSentryEvent(event) : null;
}

Future<void> stopTelemetry() async {
  // The transport discards queued analytics before reset flushes the buffer.
  await Rybbit.reset();
  await Sentry.close();
}

/// Keeps crash types and stacks without arbitrary note or server text.
SentryEvent scrubSentryEvent(SentryEvent event) {
  event.request = null;
  event.message = null;
  // Older integrations can still populate this deprecated field.
  // ignore: deprecated_member_use
  event.extra = null;
  event.tags = null;
  event.contexts.removeWhere(
    (key, _) => !const {
      'device',
      'os',
      'app',
      'runtimes',
      'runtime',
      'flutter',
    }.contains(key),
  );
  event.serverName = null;
  event.transaction = telemetryRoutes.contains(event.transaction)
      ? event.transaction
      : null;
  final id = event.user?.id;
  event.user = id != null && InstallationId(id).isValid
      ? SentryUser(id: id)
      : null;
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    // Error text stays readable; credentials and server addresses are cut out.
    final value = exception.value;
    if (value != null) {
      exception.value = const TelemetryScrubber().scrub(value);
    }
  }
  event.breadcrumbs = event.breadcrumbs
      ?.map((crumb) => scrubSentryBreadcrumb(crumb, Hint()))
      .whereType<Breadcrumb>()
      .toList();
  return event;
}

Breadcrumb? scrubSentryBreadcrumb(Breadcrumb? breadcrumb, Hint hint) {
  if (breadcrumb == null || breadcrumb.category != 'navigation') {
    return null;
  }
  return Breadcrumb(
    category: 'navigation',
    timestamp: breadcrumb.timestamp,
    data: {
      for (final key in const ['from', 'to'])
        if (telemetryRoutes.contains(breadcrumb.data?[key]))
          key: breadcrumb.data![key],
    },
  );
}

const telemetryRoutes = {
  '/',
  '/note',
  '/login',
  '/login/qr',
  '/recovery',
  '/accounts',
  '/capture',
  '/checklist',
  '/templates',
  '/about',
  '/pane',
  '/settings',
};

class TelemetryNavigatorObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (telemetryPreferences.enabled &&
        telemetryRoutes.contains(name) &&
        Rybbit.isInitialized) {
      Rybbit.instance.screenView(name!, title: name);
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _track(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _track(newRoute);
}
