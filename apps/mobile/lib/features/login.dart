import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart' show Account;

import '../data/account_api.dart';
import '../data/runtime.dart';
import '../design/login_theme.dart';
import '../l10n/app_localizations.dart';
import 'accounts.dart';
import 'certificate_prompt.dart';
import 'login_browser.dart';
import 'login_view.dart';
import 'qr_login.dart';
import 'server_address.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    this.transport,
    this.openBrowser,
    this.scan,
    this.reauthenticate,
  });
  final http.Client? transport;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<QrLoginPayload?> Function(BuildContext)? scan;
  final Account? reauthenticate;
  @override
  Widget build(BuildContext context) => LoginTheme.scope(
    context,
    (_) => _LoginContent(
      transport: transport,
      openBrowser: openBrowser,
      scan: scan,
      reauthenticate: reauthenticate,
    ),
  );
}

class _LoginContent extends ConsumerStatefulWidget {
  const _LoginContent({
    this.transport,
    this.openBrowser,
    this.scan,
    this.reauthenticate,
  });
  final http.Client? transport;
  final Future<bool> Function(Uri)? openBrowser;
  final Future<QrLoginPayload?> Function(BuildContext)? scan;
  final Account? reauthenticate;
  @override
  ConsumerState<_LoginContent> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<_LoginContent> {
  late final _url = TextEditingController(
    text: widget.reauthenticate?.server ?? 'https://',
  );
  final _focus = FocusNode();
  http.Client? _transport;
  LoginSession? _session;
  LoginPhase _phase = LoginPhase.entry;
  String? _problem;
  int _attempt = 0;
  bool _scanning = false;
  ServerBase? _server;
  String? _usedPin;
  String? _confirmedPin;
  String? _confirmedOrigin;
  Completer<void> _cancelled = Completer<void>();
  bool _browserOpen = false;

  bool get _busy => _phase != LoginPhase.entry;
  bool get _canScan =>
      widget.scan != null ||
      !kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _url.selection = TextSelection.collapsed(offset: _url.text.length);
  }

  @override
  void dispose() {
    _stopAttempt();
    _url.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _stopAttempt() {
    _attempt++;
    if (!_cancelled.isCompleted) _cancelled.complete();
    _session?.cancel();
    _closeBrowser();
    if (widget.transport == null) _transport?.close();
  }

  void _closeBrowser() {
    if (!_browserOpen) return;
    _browserOpen = false;
    unawaited(closeLoginBrowser());
  }

  void _cancel() {
    if (_phase == LoginPhase.saving) return;
    _stopAttempt();
    _back();
  }

  void _back({String? problem}) {
    if (mounted) {
      setState(() {
        _phase = LoginPhase.entry;
        _problem = problem;
      });
    }
  }

  String _problemFor(Object error) => switch (error) {
    LoginException(:final code) => code,
    AccountApiException(code: 'network') => 'transport_failed',
    AccountApiException(code: 'rejected') => 'scanned_rejected',
    NotesHttpException(statusCode: 404) => 'notes_missing',
    NotesHttpException(statusCode: 401 || 403) => 'scanned_rejected',
    NotesTransportException() => 'transport_failed',
    StateError(message: 'identity_mismatch') => 'identity_mismatch',
    StateError(message: 'certificate_changed') => 'certificate_changed',
    _ => 'unexpected',
  };

  Future<http.Client> _client(
    ServerBase server,
    int attempt, {
    String? user,
  }) async {
    if (widget.transport != null) return _transport = widget.transport!;
    final runtime = ref.read(runtimeProvider);
    final accounts = await runtime.database.watchAccounts().first;
    if (_stale(attempt)) throw const LoginException('cancelled');
    final existing = widget.reauthenticate;
    final pins = accounts
        .where(
          (a) =>
              a.server == server.uri.toString() &&
              (existing == null
                  ? user == null || a.loginName == user
                  : a.id == existing.id),
        )
        .map((a) => a.certificateFingerprint)
        .whereType<String>()
        .toSet();
    if (pins.length > 1) throw StateError('certificate_changed');
    _usedPin =
        pins.firstOrNull ??
        (_confirmedOrigin == server.uri.origin ? _confirmedPin : null);
    _transport?.close();
    return _transport = CertificateHttpClient(
      server: server.uri,
      fingerprint: _usedPin,
    );
  }

  Future<void> _failed(
    Object error,
    int attempt,
    Future<void> Function() retry,
  ) async {
    if (!mounted || attempt != _attempt) return;
    final encounter = (_transport is CertificateHttpClient)
        ? (_transport as CertificateHttpClient).lastEncounter
        : null;
    _back(problem: encounter == null ? _problemFor(error) : null);
    if (encounter == null) return;
    final approved = await confirmServerCertificate(context, encounter);
    if (!mounted ||
        attempt != _attempt ||
        !approved ||
        encounter.outcome.decision != CertificateTrustDecision.ask) {
      return;
    }
    _confirmedOrigin = _server!.uri.origin;
    _confirmedPin = encounter.fingerprint;
    await retry();
  }

  int _begin(ServerBase server) {
    _focus.unfocus();
    final attempt = ++_attempt;
    _cancelled = Completer<void>();
    setState(() {
      _phase = LoginPhase.checking;
      _problem = null;
      _server = server;
    });
    return attempt;
  }

  bool _stale(int attempt) => !mounted || attempt != _attempt;

  Future<void> _connect([String? address]) async {
    if (_busy) return;
    _focus.unfocus();
    final ServerBase server;
    try {
      server = parseServerAddress(address ?? _url.text);
    } on ServerAddressException {
      _back(problem: 'invalid_server');
      return;
    }
    final existing = widget.reauthenticate;
    if (existing != null && existing.server != server.uri.toString()) {
      _back(problem: 'identity_mismatch');
      return;
    }
    if (address != null) _url.text = address;
    final attempt = _begin(server);
    try {
      final transport = await _client(server, attempt);
      if (_stale(attempt)) return;
      final login = LoginClient(base: server, transport: transport);
      await login.checkServer();
      if (_stale(attempt)) return;
      final session = await login.start();
      if (_stale(attempt)) {
        session.cancel();
        return;
      }
      _session = session;
      setState(() => _phase = LoginPhase.openingLogin);
      final custom = widget.openBrowser;
      final opened =
          await (custom?.call(session.loginUri) ??
              openLoginBrowser(session.loginUri, _cancelled.future));
      _browserOpen = opened && custom == null;
      if (_stale(attempt)) {
        session.cancel();
        _closeBrowser();
        return;
      }
      if (!opened) throw const LoginException('browser_unavailable');
      setState(() => _phase = LoginPhase.waiting);
      final deadline = DateTime.now().add(const Duration(minutes: 15));
      while (!_stale(attempt) &&
          !session.isClosed &&
          DateTime.now().isBefore(deadline)) {
        LoginCredentials? credentials;
        try {
          credentials = await session.poll();
        } on LoginException catch (error) {
          if (error.code != 'transport_failed' && error.code != 'timeout') {
            rethrow;
          }
          final encounter = transport is CertificateHttpClient
              ? transport.lastEncounter
              : null;
          if (encounter != null) rethrow;
        }
        if (_stale(attempt)) return;
        if (credentials != null) {
          _closeBrowser();
          await _store(credentials, transport, attempt, revokeOnFailure: true);
          if (mounted && !_stale(attempt)) Navigator.of(context).pop();
          return;
        }
        await Future.any([
          Future<void>.delayed(const Duration(seconds: 2)),
          _cancelled.future,
        ]);
      }
      if (!_stale(attempt)) throw const LoginException('flow_closed');
    } catch (error) {
      _session?.cancel();
      _closeBrowser();
      await _failed(error, attempt, _connect);
    }
  }

  Future<void> _store(
    LoginCredentials credentials,
    http.Client transport,
    int attempt, {
    required bool revokeOnFailure,
  }) async {
    final runtime = ref.read(runtimeProvider);
    final existing = widget.reauthenticate;
    try {
      if (existing != null &&
          (existing.server != credentials.server.uri.toString() ||
              existing.loginName != credentials.loginName)) {
        throw StateError('identity_mismatch');
      }
      await NotesClient(
        base: credentials.server,
        transport: transport,
        loginName: credentials.loginName,
        appPassword: credentials.appPassword,
      ).list(chunkSize: 1);
      if (_stale(attempt)) throw const LoginException('cancelled');
      final target =
          existing ??
          (await runtime.database.watchAccounts().first)
              .where(
                (a) =>
                    a.server == credentials.server.uri.toString() &&
                    a.loginName == credentials.loginName,
              )
              .firstOrNull;
      if (_stale(attempt)) throw const LoginException('cancelled');
      setState(() => _phase = LoginPhase.saving);
      try {
        if (target == null) {
          await runtime.accounts.add(
            credentials,
            certificateFingerprint: _usedPin,
            canCommit: () => !_stale(attempt),
          );
        } else {
          await runtime.accounts.reauthenticate(
            target.id,
            credentials,
            certificateFingerprint: _usedPin,
            canCommit: () => !_stale(attempt),
          );
          unawaited(runtime.sync.sync(target.id).catchError((Object _) {}));
          if (mounted) ref.invalidate(accountDisplayNameProvider);
        }
      } catch (_) {
        throw const LoginException('local_persistence');
      }
    } catch (_) {
      if (revokeOnFailure) {
        try {
          await AccountApi(transport).revoke(
            credentials.server,
            credentials.loginName,
            credentials.appPassword,
          );
        } catch (_) {
          /* The user can revoke an unreachable grant in server settings. */
        }
      }
      rethrow;
    }
  }

  Future<void> _scan() async {
    if (_busy || _scanning) return;
    _focus.unfocus();
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
        await _connect(server.uri.toString());
      case QrLoginCredentials():
        await _commitScanned(payload);
    }
  }

  Future<void> _commitScanned(QrLoginCredentials payload) async {
    final existing = widget.reauthenticate;
    if (existing != null &&
        (existing.server != payload.server.uri.toString() ||
            existing.loginName != payload.loginName)) {
      _back(problem: 'identity_mismatch');
      return;
    }
    final attempt = _begin(payload.server);
    try {
      final transport = await _client(
        payload.server,
        attempt,
        user: payload.loginName,
      );
      if (_stale(attempt)) return;
      await LoginClient(
        base: payload.server,
        transport: transport,
      ).checkServer();
      if (_stale(attempt)) return;
      final api = AccountApi(transport);
      final password = payload.isOneTime
          ? await api.exchangeOneTime(
              payload.server,
              payload.loginName,
              payload.secret,
            )
          : payload.secret;
      if (_stale(attempt)) return;
      await api.signIn(payload.server, payload.loginName, password);
      if (_stale(attempt)) return;
      await _store(
        LoginCredentials(
          server: payload.server,
          loginName: payload.loginName,
          appPassword: password,
        ),
        transport,
        attempt,
        revokeOnFailure: payload.isOneTime,
      );
      if (mounted && !_stale(attempt)) Navigator.of(context).pop();
    } catch (error) {
      await _failed(error, attempt, () => _commitScanned(payload));
    }
  }

  String? _message(AppLocalizations l) => switch (_problem) {
    null || 'cancelled' => null,
    'invalid_server' || 'invalid_server_path' => l.invalidServer,
    'transport_failed' || 'timeout' => l.serverUnavailable,
    'server_maintenance' => l.serverMaintenance,
    'server_upgrade' => l.serverUpgrade,
    'server_not_installed' => l.serverNotInstalled,
    'browser_unavailable' => l.browserUnavailable,
    'flow_closed' => l.loginTimedOut,
    'scanned_rejected' => l.scannedLoginRejected,
    'notes_missing' => l.notesAppMissing,
    'identity_mismatch' => l.reauthenticateAccountMismatch,
    'certificate_changed' => l.certificateChangedTitle,
    'local_persistence' => l.localPersistenceFailed,
    'start_rejected' ||
    'invalid_response' ||
    'invalid_content_type' ||
    'response_too_large' ||
    'untrusted_endpoint' => l.invalidResponse,
    _ => l.unexpectedError,
  };

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _phase != LoginPhase.waiting && _phase != LoginPhase.saving,
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) {
        _stopAttempt();
      } else {
        _cancel();
      }
    },
    child: Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: _phase == LoginPhase.waiting || _phase == LoginPhase.saving
              ? LoginWaiting(
                  key: const ValueKey('waiting'),
                  host: _server?.uri.host ?? '',
                  saving: _phase == LoginPhase.saving,
                  onCancel: _cancel,
                )
              : LoginEntry(
                  key: const ValueKey('entry'),
                  serverController: _url,
                  serverFocus: _focus,
                  busy: _busy,
                  phase: _phase,
                  reauthentication: widget.reauthenticate != null,
                  errorMessage: _message(AppLocalizations.of(context)!),
                  onConnect: _connect,
                  onScan: _canScan ? _scan : null,
                ),
        ),
      ),
    ),
  );
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
