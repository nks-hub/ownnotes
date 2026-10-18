import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data/runtime.dart';
import 'features/home.dart';
import 'l10n/app_localizations.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Startup());
}

class Startup extends StatefulWidget {
  const Startup({super.key});
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
        child: const OwnNotesApp(),
      );
    }
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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

class OwnNotesApp extends StatelessWidget {
  const OwnNotesApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OwnNotes',
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff315b77)),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff7caccb),
        brightness: Brightness.dark,
      ),
    ),
    home: const HomeScreen(),
  );
}
