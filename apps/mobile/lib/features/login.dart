import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart' show Account;
import 'package:url_launcher/url_launcher.dart';
import '../data/account_api.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';
import 'qr_login.dart';
import 'server_address.dart';

Future<bool> _openBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

enum _Phase { entry, checking, waiting, saving }

enum _Problem {
  empty,
  insecure,
  invalid,
  noLogin,
  unreachable,
  browser,
  expired,
  scanRejected,
  tls,
  timeout,
  notesMissing,
  identityMismatch,
  failed,
}

class _Mismatch implements Exception {
  const _Mismatch();
}

/// Branded entry: server address, Login Flow v2 in the browser, or a scanned
/// `nc://login/` code. Pops once the account is stored.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.transport,
    this.openBrowser,
    this.scan,
    this.reauthenticate,
  });

  /// Test seams; production uses a fresh HTTP client, the system browser and
  /// the camera scanner.
  final http.Client? transport;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<QrLoginPayload?> Function(BuildContext)? scan;

  /// When set, signs this account in again in place (same server and user
  /// required) instead of adding a new one.
  final Account? reauthenticate;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  late final _url = TextEditingController(
    text: widget.reauthenticate?.server ?? 'https://',
  );
  final _focus = FocusNode();
  late final _transport = widget.transport ?? http.Client();
  LoginSession? _session;
  _Phase _phase = _Phase.entry;
  _Problem? _problem;
  // Bumped by every new attempt and by cancel, so a result that arrives for an
  // older attempt is dropped instead of opening a browser or saving anything.
  int _attempt = 0;
  bool _scanning = false;
  ServerBase? _server;

  bool get _busy => _phase != _Phase.entry;
  bool get _canScan =>
      widget.reauthenticate == null &&
      (widget.scan != null ||
          (!kIsWeb &&
              (defaultTargetPlatform == TargetPlatform.android ||
                  defaultTargetPlatform == TargetPlatform.iOS)));

  /// Lets the user start over when the browser side broke (for example an
  /// expired server session) instead of waiting for the flow to expire.
  void _cancel() {
    _attempt++;
    _session?.cancel();
    _back();
  }

  @override
  void dispose() {
    _session?.cancel();
    if (widget.transport == null) _transport.close();
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _back({_Problem? problem}) {
    if (!mounted) return;
    setState(() {
      _phase = _Phase.entry;
      _problem = problem;
    });
  }

  _Problem _problemFor(Object error) => switch (error) {
    LoginException(:final code) => switch (code) {
      'transport_failed' => _Problem.unreachable,
      'timeout' => _Problem.timeout,
      'tls_failed' => _Problem.tls,
      'browser_unavailable' => _Problem.browser,
      'start_rejected' ||
      'invalid_response' ||
      'invalid_content_type' ||
      'response_too_large' ||
      'untrusted_endpoint' => _Problem.noLogin,
      'flow_closed' => _Problem.expired,
      _ => _Problem.failed,
    },
    AccountApiException(:final code) => switch (code) {
      'network' => _Problem.unreachable,
      'rejected' => _Problem.scanRejected,
      _ => _Problem.failed,
    },
    _Mismatch() => _Problem.identityMismatch,
    NotesHttpException(:final statusCode) => switch (statusCode) {
      404 => _Problem.notesMissing,
      401 || 403 => _Problem.scanRejected,
      _ => _Problem.failed,
    },
    NotesTransportException() => _Problem.unreachable,
    _ => _Problem.failed,
  };

  Future<void> _connect([String? address]) async {
    if (_busy) return;
    _focus.unfocus();
    if (address != null) _url.text = address;
    final ServerBase server;
    try {
      server = parseServerAddress(_url.text);
    } on ServerAddressException catch (e) {
      setState(() {
        _problem = switch (e.problem) {
          ServerAddressProblem.empty => _Problem.empty,
          ServerAddressProblem.insecure => _Problem.insecure,
          ServerAddressProblem.invalid => _Problem.invalid,
        };
      });
      return;
    }
    _url.text = _shown(server);
    final attempt = ++_attempt;
    bool stale() => attempt != _attempt;
    setState(() {
      _phase = _Phase.checking;
      _problem = null;
      _server = server;
    });
    try {
      final session = await LoginClient(
        base: server,
        transport: _transport,
      ).start();
      if (stale() || !mounted) {
        session.cancel();
        return;
      }
      _session = session;
      final opened = await (widget.openBrowser ?? _openBrowser)(
        session.loginUri,
      );
      if (stale() || !mounted) {
        session.cancel();
        return;
      }
      if (!opened) throw const LoginException('browser_unavailable');
      setState(() => _phase = _Phase.waiting);
      while (!stale() && mounted && !session.isClosed) {
        final LoginCredentials? credentials;
        try {
          credentials = await session.poll();
        } on LoginException catch (e) {
          // Expected while the browser is in front; the session expires itself.
          if (e.code != 'transport_failed' && e.code != 'timeout') rethrow;
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (stale()) return;
        if (credentials != null) {
          // Once received, persist even if the screen is closing.
          if (mounted) setState(() => _phase = _Phase.saving);
          await _store(credentials, revokeOnFailure: true);
          if (mounted) Navigator.of(context).pop();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (!stale()) _back(problem: _Problem.expired);
    } catch (e) {
      _session?.cancel();
      if (!stale()) _back(problem: _problemFor(e));
    }
  }

  /// Checks identity and the Notes app, then saves or replaces the account. A
  /// password the login flow just issued is revoked again when it is refused.
  Future<void> _store(
    LoginCredentials credentials, {
    required bool revokeOnFailure,
  }) async {
    final runtime = ref.read(runtimeProvider);
    final existing = widget.reauthenticate;
    try {
      if (existing != null &&
          (existing.server != credentials.server.uri.toString() ||
              existing.loginName != credentials.loginName)) {
        throw const _Mismatch();
      }
      // The Notes app may be missing or disabled on a server that has a login.
      await NotesClient(
        base: credentials.server,
        transport: _transport,
        loginName: credentials.loginName,
        appPassword: credentials.appPassword,
      ).list(chunkSize: 1);
      // Adding an account that is already here signs that one in again, so
      // the same server and user never appear twice.
      final target =
          existing ??
          (await runtime.database.watchAccounts().first)
              .where(
                (a) =>
                    a.server == credentials.server.uri.toString() &&
                    a.loginName == credentials.loginName,
              )
              .firstOrNull;
      if (target == null) {
        await runtime.accounts.add(credentials);
      } else {
        await runtime.accounts.reauthenticate(target.id, credentials);
      }
    } catch (_) {
      if (revokeOnFailure) {
        try {
          await AccountApi(_transport).revoke(
            credentials.server,
            credentials.loginName,
            credentials.appPassword,
          );
        } catch (_) {
          // The user can still revoke it in the Nextcloud security settings.
        }
      }
      rethrow;
    }
  }

  Future<void> _scan() async {
    if (_busy || _scanning) return;
    _focus.unfocus();
    // A double tap would push two scanners that both open the camera.
    _scanning = true;
    final QrLoginPayload? payload;
    try {
      payload = await (widget.scan ?? QrLoginScannerScreen.push)(context);
    } finally {
      _scanning = false;
    }
    if (payload == null || !mounted) return;
    switch (payload) {
      case QrLoginServerOnly(:final server):
        // Nothing secret was scanned: an address the user did not have to type.
        await _connect(_shown(server));
      case QrLoginCredentials():
        await _commitScanned(payload);
    }
  }

  Future<void> _commitScanned(QrLoginCredentials payload) async {
    final attempt = ++_attempt;
    setState(() {
      _phase = _Phase.saving;
      _problem = null;
    });
    final api = AccountApi(_transport);
    try {
      final password = payload.isOneTime
          ? await api.exchangeOneTime(
              payload.server,
              payload.loginName,
              payload.secret,
            )
          : payload.secret;
      await api.signIn(payload.server, payload.loginName, password);
      await _store(
        LoginCredentials(
          server: payload.server,
          loginName: payload.loginName,
          appPassword: password,
        ),
        revokeOnFailure: payload.isOneTime,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (attempt == _attempt) _back(problem: _problemFor(e));
    }
  }

  static String _shown(ServerBase server) {
    final text = server.uri.toString();
    return text.endsWith('/') ? text.substring(0, text.length - 1) : text;
  }

  String? _message(AppLocalizations l) => switch (_problem) {
    null => null,
    _Problem.empty => l.serverEmpty,
    _Problem.insecure => l.serverInsecure,
    _Problem.invalid => l.serverInvalid,
    _Problem.noLogin => l.serverNoLogin,
    _Problem.unreachable => l.serverUnreachable,
    _Problem.browser => l.browserUnavailable,
    _Problem.expired => l.loginExpired,
    _Problem.scanRejected => l.scannedLoginRejected,
    _Problem.tls => l.serverCertificate,
    _Problem.timeout => l.serverTimeout,
    _Problem.notesMissing => l.notesAppMissing,
    _Problem.identityMismatch => l.reauthMismatch,
    _Problem.failed => l.loginFailed,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: _phase != _Phase.saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.reauthenticate == null ? l.addAccount : l.signInAgain,
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _phase == _Phase.waiting || _phase == _Phase.saving
                ? _Waiting(
                    key: const ValueKey('waiting'),
                    host: _server?.uri.host ?? '',
                    saving: _phase == _Phase.saving,
                    onCancel: _cancel,
                  )
                : _Entry(
                    key: const ValueKey('entry'),
                    controller: _url,
                    focus: _focus,
                    busy: _busy,
                    locked: widget.reauthenticate != null,
                    message: _message(l),
                    onCancel: _cancel,
                    onConnect: _connect,
                    onScan: _canScan ? _scan : null,
                  ),
          ),
        ),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    super.key,
    required this.controller,
    required this.focus,
    required this.busy,
    required this.locked,
    required this.message,
    required this.onCancel,
    required this.onConnect,
    required this.onScan,
  });
  final TextEditingController controller;
  final FocusNode focus;
  final bool busy;
  final bool locked;
  final String? message;
  final VoidCallback onCancel;
  final VoidCallback onConnect;
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(alignment: Alignment.centerLeft, child: BrandMark()),
              const SizedBox(height: 20),
              Text(l.onboardingTitle, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                l.onboardingBody,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _FeatureLine(
                icon: Icons.hub_outlined,
                title: l.multiAccountTitle,
                body: l.multiAccountBody,
              ),
              const SizedBox(height: 14),
              _FeatureLine(
                icon: Icons.shield_outlined,
                title: l.secureLoginTitle,
                body: l.secureLoginBody,
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: controller,
                        focusNode: focus,
                        enabled: !busy && !locked,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: (_) => onConnect(),
                        autofillHints: const [AutofillHints.url],
                        autocorrect: false,
                        enableSuggestions: false,
                        decoration: InputDecoration(
                          labelText: l.serverUrl,
                          hintText: 'https://cloud.example.com',
                          prefixIcon: const Icon(Icons.language_rounded),
                        ),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: 14),
                        Semantics(
                          liveRegion: true,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  color: scheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    message!,
                                    style: TextStyle(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: busy ? null : onConnect,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Text(busy ? l.checkingServer : l.connect),
                      ),
                      if (busy) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: onCancel,
                          icon: const Icon(Icons.close_rounded),
                          label: Text(l.cancel),
                        ),
                      ] else if (onScan != null) ...[
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: onScan,
                          icon: const Icon(Icons.qr_code_scanner_rounded),
                          label: Text(l.scanLoginCode),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({
    super.key,
    required this.host,
    required this.saving,
    required this.onCancel,
  });
  final String host;
  final bool saving;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  const BrandMark(size: 64),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 24),
                  Text(
                    saving ? l.savingAccount : l.waitingForLogin,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  if (!saving) ...[
                    const SizedBox(height: 10),
                    Text(
                      l.waitingForLoginBody,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      host,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(Icons.close_rounded),
                      label: Text(l.cancel),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: scheme.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The app icon, shown on the login screen.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'OwnNotes',
    image: true,
    child: ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(
          'assets/brand/play-store-icon.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}
