import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:notes_protocol/notes_protocol.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _url = TextEditingController();
  final _transport = http.Client();
  LoginSession? _session;
  bool _busy = false;
  bool _failed = false;
  bool _saving = false;
  @override
  void dispose() {
    _session?.cancel();
    _transport.close();
    _url.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _failed = false;
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
      if (!await launchUrl(
        session.loginUri,
        mode: LaunchMode.externalApplication,
      )) {
        throw const LoginException('browser_unavailable');
      }
      while (mounted && !session.isClosed) {
        final credentials = await session.poll();
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
      if (mounted) setState(() => _failed = true);
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
