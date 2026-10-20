import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:local_auth/local_auth.dart';
import 'package:notes_store/notes_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/runtime.dart';
import '../../data/widgets/widget_model.dart';
import '../../data/widgets/widget_publisher.dart';
import '../../data/widgets/widget_snapshots.dart';
import '../../data/widgets/widget_storage.dart';
import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import '../../main.dart' show resolveLocale;
import 'widget_config_screen.dart';

/// Entry point of the widget configuration activity (`WidgetConfigActivity`),
/// a second Flutter engine that only shows [WidgetConfigScreen]. The launcher
/// opens it when a widget is placed or reconfigured.
@pragma('vm:entry-point')
void widgetConfigMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WidgetConfigApp());
}

class WidgetConfigApp extends StatefulWidget {
  const WidgetConfigApp({super.key});
  @override
  State<WidgetConfigApp> createState() => _WidgetConfigAppState();
}

class _WidgetConfigAppState extends State<WidgetConfigApp> {
  final _runtime = AppRuntime.production();
  late final Future<_Setup?> _setup;
  ThemeMode _mode = ThemeMode.system;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _setup = _prepare();
  }

  /// Reads the stored settings, asks for the device unlock when the app lock
  /// is on, and returns what the screen needs; null cancels the configuration.
  Future<_Setup?> _prepare() async {
    const storage = HomeWidgetStorage();
    final id = await HomeWidget.initiallyLaunchedFromHomeWidgetConfigure();
    if (id == null) return null;
    final prefs = SharedPreferencesAsync();
    final language = await prefs.getString('language');
    final theme = await prefs.getString('theme');
    final locale = language == null
        ? resolveLocale(
            WidgetsBinding.instance.platformDispatcher.locales,
            AppLocalizations.supportedLocales,
          )
        : Locale(language);
    if (mounted) {
      setState(() {
        _mode = ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system;
        _locale = locale;
      });
    }
    if (await prefs.getBool('lock') ?? false) {
      try {
        final reason = (await AppLocalizations.delegate.load(locale)).unlockReason;
        final granted = await LocalAuthentication().authenticate(
          localizedReason: reason,
        );
        if (!granted) return null;
      } catch (_) {
        return null;
      }
    }
    final db = _runtime.database;
    final accounts = await db.select(db.accounts).get();
    final stored = await storage.read(WidgetKeys.config(id));
    WidgetConfig? initial;
    try {
      if (stored != null) initial = WidgetConfig.decode(stored);
    } catch (_) {
      // A damaged configuration is replaced.
    }
    return _Setup(id, accounts, initial);
  }

  @override
  void dispose() {
    _runtime.close();
    super.dispose();
  }

  Future<void> _save(
    BuildContext context,
    _Setup setup,
    WidgetConfig config,
  ) async {
    const storage = HomeWidgetStorage();
    final l = AppLocalizations.of(context)!;
    final account = setup.accounts.firstWhere((a) => a.id == config.accountId);
    final notes = await _runtime.database.watchNotes(account.id).first;
    final snapshot = buildWidgetSnapshot(
      config,
      notes,
      locked: false,
      untitled: l.untitled,
      now: DateTime.now().millisecondsSinceEpoch,
      accountLabel: widgetAccountLabel(account),
    );
    await storage.write(WidgetKeys.config(config.instanceId), config.encode());
    await storage.write(WidgetKeys.snapshot(config.instanceId), snapshot.encode());
    await storage.write(WidgetKeys.untitled, l.untitled);
    await HomeWidget.finishHomeWidgetConfigure();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    localeListResolutionCallback: resolveLocale,
    locale: _locale,
    themeMode: _mode,
    theme: OwnTheme.light(),
    darkTheme: OwnTheme.dark(),
    home: FutureBuilder<_Setup?>(
      future: _setup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final setup = snapshot.data;
        if (setup == null) {
          // Cancelled or locked: closing without a result drops a new widget.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => SystemNavigator.pop(),
          );
          return const Scaffold();
        }
        return WidgetConfigScreen(
          instanceId: setup.instanceId,
          initial: setup.initial,
          accounts: [
            for (final a in setup.accounts)
              WidgetAccountChoice(a.id, widgetAccountLabel(a)),
          ],
          notesOf: (id) => _runtime.database.watchNotes(id).first,
          onSave: (config) => _save(context, setup, config),
          onCancel: SystemNavigator.pop,
        );
      },
    ),
  );
}

class _Setup {
  const _Setup(this.instanceId, this.accounts, this.initial);
  final String instanceId;
  final List<Account> accounts;
  final WidgetConfig? initial;
}
