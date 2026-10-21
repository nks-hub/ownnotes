import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notes_protocol/notes_protocol.dart';
import 'package:notes_store/notes_store.dart';
import '../data/runtime.dart';
import '../l10n/app_localizations.dart';

/// Comparison workspace for a note that waits for a decision: Device, Server
/// and an editable Result. Nothing is lost by looking: both versions are
/// stored as recovery copies as soon as the server version is known.
class RecoveryScreen extends ConsumerStatefulWidget {
  const RecoveryScreen({required this.note, super.key});
  final LocalNote note;
  @override
  ConsumerState<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends ConsumerState<RecoveryScreen> {
  final _result = TextEditingController();
  RemoteNote? _server;
  String? _reason;
  List<ChangedBlock> _blocks = const [];
  int _current = 0;
  bool _busy = true;
  bool _failed = false;
  bool _readFailed = false;
  bool _gone = false;
  bool _lost = false;
  bool _stale = false;
  bool _done = false;
  final _deviceKeys = <int, GlobalKey>{};
  final _serverKeys = <int, GlobalKey>{};

  LocalNote get _note => widget.note;
  NoteRecovery get _recovery =>
      NoteRecovery(ref.read(runtimeProvider).database);

  @override
  void initState() {
    super.initState();
    _result.text = _note.content;
    unawaited(_open());
  }

  late ScaffoldMessengerState _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _messenger.hideCurrentSnackBar();
    _result.dispose();
    super.dispose();
  }

  Future<void> _open() async {
    final saved = await _recovery.savedResult(_note);
    final reason = await _recovery.reason(_note);
    if (!mounted) return;
    setState(() {
      if (saved != null) _result.text = saved;
      _reason = reason;
    });
    if (_note.remoteId == null) {
      setState(() => _busy = false);
    } else {
      await _load();
    }
  }

  /// The server version as it is now; null when the note is gone.
  Future<RemoteNote?> _fetch() async {
    final runtime = ref.read(runtimeProvider);
    try {
      if (_note.kind == 'shared') return await runtime.sync.readShared(_note);
      final account = await runtime.database.account(_note.accountId);
      if (account == null) throw StateError('account_missing');
      final read = await (await runtime.clientFor(
        account,
      )).get(_note.remoteId!);
      if (read is! RemoteNote) throw StateError('remote_unavailable');
      return read;
    } on NotesHttpException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _readFailed = false;
    });
    try {
      final remote = await _fetch();
      if (remote == null) {
        if (mounted) setState(() => _gone = true);
      } else {
        await _recovery.retainOriginals(_note, remote);
        if (mounted) _show(remote);
      }
    } catch (_) {
      if (mounted) setState(() => _readFailed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(RemoteNote remote) {
    setState(() {
      _server = remote;
      _lost = remote.readonly;
      _blocks = compareBlocks(_note.content, remote.content);
      _current = 0;
      _deviceKeys.clear();
      _serverKeys.clear();
    });
  }

  Future<void> _resolve(ConflictChoice choice) async {
    final server = _server;
    if (server == null) return;
    setState(() {
      _busy = true;
      _failed = false;
      _stale = false;
    });
    try {
      final outcome = await _recovery.resolve(
        expected: _note,
        inspected: server,
        readServer: _fetch,
        choice: choice,
        content: _result.text,
        // A category change with attachments is refused; follow the server.
        category: _reason == 'move_integrity_required' ? server.category : null,
      );
      if (!mounted) return;
      switch (outcome.status) {
        case ConflictStatus.applied:
          _done = true;
          Navigator.of(context).pop();
        case ConflictStatus.serverChanged:
          _show(outcome.server!);
          setState(() => _stale = true);
        case ConflictStatus.serverDeleted:
          setState(() => _gone = true);
        case ConflictStatus.permissionLost:
          _show(outcome.server!);
          setState(() => _lost = true);
      }
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
      await action(_recovery);
      _done = true;
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _separate() async {
    final l = AppLocalizations.of(context)!;
    // Without a server note there is nothing to duplicate.
    final confirmed =
        _gone ||
        _lost ||
        await showDialog<bool>(
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
            ) ==
            true;
    if (!mounted || !confirmed) return;
    final text = _result.text;
    await _apply((r) async {
      await r.copyAsNew(_note, content: text == _note.content ? null : text);
    });
  }

  void _fill(String text) {
    final l = AppLocalizations.of(context)!;
    final before = _result.text;
    if (before == text) return;
    setState(() => _result.text = text);
    _messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.recResultReplaced),
          action: SnackBarAction(
            label: l.recUndo,
            onPressed: () => setState(() => _result.text = before),
          ),
        ),
      );
  }

  void _go(int delta) {
    if (_blocks.isEmpty) return;
    setState(() => _current = (_current + delta) % _blocks.length);
    for (final key in [_deviceKeys[_current], _serverKeys[_current]]) {
      final context = key?.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          alignment: 0.1,
          duration: const Duration(milliseconds: 160),
        );
      }
    }
  }

  String _reasonText(AppLocalizations l) {
    if (_gone) return l.remoteDeleted;
    if (_lost) return l.recReasonReadonly;
    return switch (_reason) {
      'remote_conflict' => l.recReasonConflict,
      'remote_deleted' => l.remoteDeleted,
      'remote_readonly' => l.recReasonReadonly,
      'move_integrity_required' => l.recReasonMove,
      'write_outcome_unknown' ||
      'interrupted_write' ||
      'receipt_differs_from_intent' => l.recReasonUnknown,
      _ => l.recReasonGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final wide =
        MediaQuery.sizeOf(context).width >= 840 &&
        MediaQuery.textScalerOf(context).scale(16) <= 24;
    final server = _server;
    final device = _pane(l.recTabDevice, _note.content, [
      for (final b in _blocks) (b.deviceStart, b.deviceEnd),
    ], _deviceKeys);
    final serverPane = server == null
        ? Center(child: Text(_gone ? l.remoteDeleted : l.recReadFailed))
        : _pane(l.recTabServer, server.content, [
            for (final b in _blocks) (b.serverStart, b.serverEnd),
          ], _serverKeys);
    final result = _resultPane(l);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Leaving keeps the unfinished Result for the next visit.
        if (didPop && !_done) {
          unawaited(_recovery.saveResult(_note, _result.text));
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.recTitle)),
        body: SafeArea(
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.25,
                ),
                child: SingleChildScrollView(child: _banner(l)),
              ),
              if (server != null && !_lost) _changeBar(l),
              Expanded(
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _titled(l.recTabDevice, device)),
                          const VerticalDivider(width: 1),
                          Expanded(child: _titled(l.recTabServer, serverPane)),
                          const VerticalDivider(width: 1),
                          Expanded(child: _titled(l.recTabResult, result)),
                        ],
                      )
                    : DefaultTabController(
                        length: 3,
                        child: Column(
                          children: [
                            TabBar(
                              tabs: [
                                Tab(text: l.recTabDevice),
                                Tab(text: l.recTabServer),
                                Tab(text: l.recTabResult),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [device, serverPane, result],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              _actions(l),
            ],
          ),
        ),
      ),
    );
  }

  Widget _titled(String title, Widget body) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      Expanded(child: body),
    ],
  );

  Widget _banner(AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    Widget line(String text, {bool error = false}) => Container(
      width: double.infinity,
      color: error ? scheme.errorContainer : scheme.tertiaryContainer,
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        style: TextStyle(
          color: error ? scheme.onErrorContainer : scheme.onTertiaryContainer,
        ),
      ),
    );
    return Column(
      children: [
        line(_reasonText(l)),
        if (_stale) line(l.recServerChanged),
        if (_failed) line(l.decisionFailed, error: true),
        if (_readFailed) line(l.recReadFailed, error: true),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(l.recKept, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _changeBar(AppLocalizations l) {
    final label = _blocks.isEmpty
        ? l.recNoChanges
        : l.recChangeCounter(_current + 1, _blocks.length);
    return Row(
      children: [
        IconButton(
          tooltip: l.recPrevChange,
          onPressed: _blocks.length > 1 ? () => _go(-1) : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: l.recNextChange,
          onPressed: _blocks.length > 1 ? () => _go(1) : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        Expanded(
          child: Semantics(
            liveRegion: true,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
        ),
      ],
    );
  }

  /// One side of the comparison: its lines, the changed runs marked.
  Widget _pane(
    String name,
    String text,
    List<(int, int)> ranges,
    Map<int, GlobalKey> keys,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final lines = text.split('\n');
    final children = <Widget>[];
    var at = 0;
    void plain(int to) {
      if (to > at) {
        children.add(SelectableText(lines.sublist(at, to).join('\n')));
      }
      at = to > at ? to : at;
    }

    for (var i = 0; i < ranges.length; i++) {
      final (start, end) = ranges[i];
      plain(start);
      final selected = i == _current;
      children.add(
        Semantics(
          label: '$name ${i + 1}',
          child: Container(
            key: keys.putIfAbsent(i, GlobalKey.new),
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer,
              border: Border(
                left: BorderSide(
                  color: scheme.tertiary,
                  width: selected ? 6 : 3,
                ),
              ),
            ),
            child: SelectableText(
              end > start ? lines.sublist(start, end).join('\n') : ' ',
              style: TextStyle(color: scheme.onTertiaryContainer),
            ),
          ),
        ),
      );
      at = end;
    }
    plain(lines.length);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _resultPane(AppLocalizations l) {
    final server = _server;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _fill(_note.content),
                child: Text(l.recFillDevice),
              ),
              if (server != null) ...[
                OutlinedButton(
                  onPressed: () => _fill(server.content),
                  child: Text(l.recFillServer),
                ),
                OutlinedButton(
                  onPressed: () =>
                      _fill(mergeVersions(_note.content, server.content)),
                  child: Text(l.recFillBoth),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _result,
              expands: true,
              maxLines: null,
              minLines: null,
              textAlignVertical: TextAlignVertical.top,
              keyboardType: TextInputType.multiline,
              decoration: InputDecoration(
                labelText: l.recTabResult,
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _actions(AppLocalizations l) {
    final server = _server;
    final copy = OutlinedButton(
      onPressed: () => Clipboard.setData(ClipboardData(text: _result.text)),
      child: Text(l.copyMarkdown),
    );
    final leave = TextButton(
      onPressed: _busy ? null : () => Navigator.of(context).pop(),
      child: Text(_gone ? l.recKeepRecovery : l.recLeave),
    );
    final List<Widget> buttons;
    if (_gone) {
      buttons = [
        FilledButton(
          onPressed: _busy ? null : _separate,
          child: Text(l.recSaveAsNew),
        ),
        copy,
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => _apply(
                  (r) => r.database.markDeleted(_note.accountId, _note.id),
                ),
          child: Text(l.deleteHere),
        ),
        leave,
      ];
    } else if (_lost) {
      buttons = [
        FilledButton(
          onPressed: _busy ? null : _separate,
          child: Text(l.recSaveAsNew),
        ),
        copy,
        if (server != null)
          OutlinedButton(
            onPressed: _busy ? null : () => _resolve(ConflictChoice.server),
            child: Text(l.recUseServer),
          ),
        leave,
      ];
    } else if (server == null) {
      buttons = [
        if (_note.remoteId != null)
          OutlinedButton(onPressed: _busy ? null : _load, child: Text(l.retry)),
        FilledButton(
          onPressed: _busy ? null : _separate,
          child: Text(l.recKeepSeparate),
        ),
        copy,
        leave,
      ];
    } else {
      buttons = [
        FilledButton(
          onPressed: _busy || server.readonly
              ? null
              : () => _resolve(ConflictChoice.result),
          child: Text(
            _reason == 'move_integrity_required'
                ? l.recKeepCategory
                : l.recUseResult,
          ),
        ),
        OutlinedButton(
          onPressed: _busy ? null : _separate,
          child: Text(l.recKeepSeparate),
        ),
        OutlinedButton(
          onPressed: _busy ? null : () => _resolve(ConflictChoice.server),
          child: Text(l.recUseServer),
        ),
        leave,
      ];
    }
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.35,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: buttons,
        ),
      ),
    );
  }
}
