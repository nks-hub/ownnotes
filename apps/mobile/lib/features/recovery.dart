import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';

class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({required this.note, super.key});
  final LocalNote note;
  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  RemoteNote? _remote;
  bool _busy = false;
  bool _failed = false;
  Future<void> _read() async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final runtime = ref.read(runtimeProvider);
      final account = await runtime.database.account(widget.note.accountId);
      if (account == null) throw StateError('account_missing');
      final client = await runtime.clientFor(account);
      final remote = await client.get(widget.note.remoteId!);
      if (remote is! RemoteNote) throw StateError('remote_unavailable');
      if (mounted) setState(() => _remote = remote);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _apply(Future<void> Function(NoteRecovery) action) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await action(NoteRecovery(ref.read(runtimeProvider).database));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    final l = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.newCopy),
        content: Text(l.copyWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.confirm),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    await _apply((recovery) async {
      await recovery.copyAsNew(widget.note);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final remote = _remote;
    return Scaffold(
      appBar: AppBar(title: Text(l.resolve)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_busy) const LinearProgressIndicator(),
            if (_failed) Text(l.decisionFailed),
            Text(l.localVersion, style: Theme.of(context).textTheme.titleLarge),
            SelectableText(
              '${widget.note.title}\n${widget.note.category}\n\n${widget.note.content}',
            ),
            TextButton(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: widget.note.content)),
              child: Text(l.copyMarkdown),
            ),
            if (widget.note.remoteId != null)
              OutlinedButton(
                onPressed: _busy ? null : _read,
                child: Text(l.readServer),
              ),
            if (remote != null) ...[
              Text(
                l.serverVersion,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              SelectableText(
                '${remote.title}\n${remote.category}\n\n${remote.content}',
              ),
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _apply(
                        (r) => r.useRemote(
                          expected: widget.note,
                          remote: remote,
                          keepLocal: false,
                        ),
                      ),
                child: Text(l.useServer),
              ),
              FilledButton(
                onPressed: _busy || remote.readonly
                    ? null
                    : () => _apply(
                        (r) => r.useRemote(
                          expected: widget.note,
                          remote: remote,
                          keepLocal: true,
                        ),
                      ),
                child: Text(l.keepLocal),
              ),
            ],
            OutlinedButton(
              onPressed: _busy ? null : _copy,
              child: Text(l.newCopy),
            ),
          ],
        ),
      ),
    );
  }
}
