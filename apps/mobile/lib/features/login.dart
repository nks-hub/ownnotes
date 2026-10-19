import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';

Future<bool> _openBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.transport, this.openBrowser});

  /// Test seams; production uses a fresh HTTP client and the system browser.
  final http.Client? transport;
  final Future<bool> Function(Uri)? openBrowser;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _url = TextEditingController();
  late final _transport = widget.transport ?? http.Client();
  LoginSession? _session;
  bool _busy = false;
  bool _failed = false;
  bool _cancelled = false;
  bool _saving = false;

  /// Lets the user start over when the browser side broke (for example an
  /// expired server session) instead of waiting for the flow to expire.
  void _cancel() {
    _cancelled = true;
    _session?.cancel();
  }

  @override
  void dispose() {
    _session?.cancel();
    if (widget.transport == null) _transport.close();
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _failed = false;
      _cancelled = false;
    });
    final runtime = ref.read(runtimeProvider);
    try {
      final client = LoginClient(
        base: ServerBase.parse(_url.text),
        transport: _transport,
      );
      final session = await client.start();
      if (!mounted) {
        session.cancel();
        return;
      }
      _session = session;
      if (!await (widget.openBrowser ?? _openBrowser)(session.loginUri)) {
        throw const LoginException('browser_unavailable');
      }
      while (mounted && !session.isClosed) {
        final LoginCredentials? credentials;
        try {
          credentials = await session.poll();
        } on LoginException catch (e) {
          // Expected while the browser is in front; the session expires itself.
          if (e.code != 'transport_failed') rethrow;
          await Future<void>.delayed(const Duration(seconds: 2));
          continue;
        }
        if (credentials != null) {
          // Once received, persist even if the screen is closing.
          if (mounted) setState(() => _saving = true);
          await runtime.accounts.add(credentials);
          if (mounted) Navigator.of(context).pop();
          return;
        }
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    } catch (_) {
      _session?.cancel();
      if (mounted) setState(() => _failed = !_cancelled);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: Text(l.addAccount)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _url,
                    enabled: !_busy,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.go,
                    onSubmitted: (_) => _busy ? null : _connect(),
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l.serverUrl,
                      hintText: 'https://cloud.example.com',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_busy) ...[
                    const LinearProgressIndicator(),
                    Text(l.waitingLogin),
                    if (!_saving)
                      TextButton(onPressed: _cancel, child: Text(l.cancel)),
                  ],
                  if (_failed)
                    Text(
                      l.loginFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  FilledButton(
                    onPressed: _busy ? null : _connect,
                    child: Text(l.connect),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
