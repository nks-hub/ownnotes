import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/telemetry.dart';
import 'core/telemetry_bootstrap.dart';
import 'data/background.dart';
import 'data/runtime.dart';
import 'data/settings.dart';
import 'design/design.dart';
import 'features/home.dart';
import 'features/lock.dart';
import 'l10n/app_localizations.dart';

Future<void> main() {
  registerFontLicenses();
  return runWithTelemetry(
    config: TelemetryConfig.fromEnvironment(),
    appBuilder: (observers) => Startup(observers: observers),
  );
}

class Startup extends StatefulWidget {
  const Startup({super.key, this.observers = const []});
  final List<NavigatorObserver> observers;
  @override
  State<Startup> createState() => _StartupState();
}

class _StartupState extends State<Startup> {
  AppRuntime? _runtime;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() => _failed = false);
    final runtime = AppRuntime.production();
    try {
      await runtime.initialize();
      if (!mounted) {
        await runtime.close();
        return;
      }
      setState(() => _runtime = runtime);
      scheduleBackgroundSync().catchError((Object _) {});
    } catch (_) {
      await runtime.close();
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = _runtime;
    if (runtime != null) {
      return ProviderScope(
        overrides: [runtimeProvider.overrideWithValue(runtime)],
        child: OwnNotesApp(observers: widget.observers),
      );
    }
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      localeListResolutionCallback: resolveLocale,
      theme: OwnTheme.light(),
      darkTheme: OwnTheme.dark(),
      home: Builder(
        builder: (context) {
          final l = AppLocalizations.of(context)!;
          return Scaffold(
            body: Center(
              child: _failed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.startupFailed),
                        FilledButton(onPressed: _open, child: Text(l.retry)),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          );
        },
      ),
    );
  }
}

/// Picks the first preferred language the app ships, otherwise English.
/// A language added to the ARB files is matched without changes here.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final s in supported) {
      if (s.languageCode == locale.languageCode) return s;
    }
  }
  return const Locale('en');
}

class OwnNotesApp extends ConsumerWidget {
  const OwnNotesApp({super.key, this.observers = const []});

  /// Route names only, never note ids or titles; see lib/core/telemetry.dart.
  final List<NavigatorObserver> observers;
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'OwnNotes',
    navigatorObservers: observers,
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeListResolutionCallback: resolveLocale,
    locale: ref.watch(localeProvider),
    themeMode: ref.watch(themeModeProvider),
    theme: OwnTheme.light(),
    darkTheme: OwnTheme.dark(),
    builder: (context, child) => AppLock(child: child!),
    home: const HomeScreen(),
  );
}
