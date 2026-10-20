import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/design.dart';
import '../../l10n/app_localizations.dart';
import 'voice_engine.dart';

enum _Phase { idle, recording, paused, stopped }

/// Records a voice note. Pops with the path of the finished recording when
/// the owner taps Attach, and with null otherwise. A recording that is not
/// attached or discarded stays on disk and is offered again the next time
/// this screen opens.
class VoiceRecordingScreen extends ConsumerStatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  ConsumerState<VoiceRecordingScreen> createState() => _VoiceState();
}

class _VoiceState extends ConsumerState<VoiceRecordingScreen>
    with WidgetsBindingObserver {
  late final VoiceEngine _engine;
  late final VoicePlayer _player;
  final _clock = Stopwatch();
  Timer? _ticker;
  StreamSubscription<void>? _completed;
  _Phase _phase = _Phase.idle;
  String? _path;
  bool _playing = false;
  bool _interrupted = false;
  bool _recovered = false;
  bool _denied = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _engine = ref.read(voiceEngineFactoryProvider)();
    _player = ref.read(voicePlayerFactoryProvider)();
    _completed = _player.completed.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
    _recover();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _completed?.cancel();
    _player.dispose();
    _engine.dispose();
    super.dispose();
  }

  Future<File> _newFile() async {
    final dir = await ref.read(voiceDirectoryProvider.future);
    await dir.create(recursive: true);
    return File(
      '${dir.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a',
    );
  }

  /// An earlier recording the app never got to attach or discard.
  Future<void> _recover() async {
    final dir = await ref.read(voiceDirectoryProvider.future);
    if (!await dir.exists()) return;
    File? newest;
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.m4a')) continue;
      if (await e.length() < 1024) {
        await e.delete();
        continue;
      }
      if (newest == null ||
          (await e.lastModified()).isAfter(await newest.lastModified())) {
        newest = e;
      }
    }
    if (newest == null || !mounted || _phase != _Phase.idle) return;
    setState(() {
      _phase = _Phase.stopped;
      _path = newest!.path;
      _recovered = true;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A call or another app took the microphone: pause, so the file stays
    // valid and the owner decides when to go on.
    if (state == AppLifecycleState.paused && _phase == _Phase.recording) {
      _pause(interrupted: true);
    }
  }

  void _tick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _start() async {
    setState(() {
      _denied = false;
      _failed = false;
    });
    try {
      if (!await _engine.requestPermission()) {
        if (mounted) setState(() => _denied = true);
        return;
      }
      final file = await _newFile();
      await _engine.start(file.path);
      _clock
        ..reset()
        ..start();
      _tick();
      if (mounted) {
        setState(() {
          _phase = _Phase.recording;
          _path = file.path;
          _recovered = false;
          _interrupted = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _pause({bool interrupted = false}) async {
    try {
      await _engine.pause();
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    _clock.stop();
    _ticker?.cancel();
    if (mounted) {
      setState(() {
        _phase = _Phase.paused;
        _interrupted = interrupted;
      });
    }
  }

  Future<void> _resume() async {
    try {
      await _engine.resume();
    } on Object {
      if (mounted) setState(() => _failed = true);
      return;
    }
    _clock.start();
    _tick();
    if (mounted) {
      setState(() {
        _phase = _Phase.recording;
        _interrupted = false;
      });
    }
  }

  Future<void> _stop() async {
    String? path;
    try {
      path = await _engine.stop();
    } on Object {
      path = _path;
    }
    _clock.stop();
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _phase = _Phase.stopped;
      _path = path ?? _path;
    });
  }

  Future<void> _listen() async {
    final path = _path;
    if (path == null) return;
    if (_playing) {
      await _player.stop();
      if (mounted) setState(() => _playing = false);
      return;
    }
    setState(() => _playing = true);
    try {
      await _player.play(path);
    } on Object {
      if (mounted) setState(() => _playing = false);
    }
  }

  Future<void> _discard() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.voiceDiscardTitle),
        content: Text(l.voiceDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.voiceDiscard),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (_phase == _Phase.recording || _phase == _Phase.paused) {
      await _stop();
    }
    final path = _path;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (mounted) Navigator.pop(context);
  }

  /// Leaving keeps the recording; only Discard deletes it.
  Future<void> _leave() async {
    if (_phase == _Phase.recording || _phase == _Phase.paused) await _stop();
    if (mounted) Navigator.pop(context);
  }

  String get _time {
    final s = _clock.elapsed.inSeconds;
    final m = (s ~/ 60).toString().padLeft(2, '0');
    return '$m:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final label = switch (_phase) {
      _Phase.idle => l.voiceReady,
      _Phase.recording => l.voiceRecording,
      _Phase.paused => l.voicePaused,
      _Phase.stopped => l.voiceStopped,
    };
    final notice = _denied
        ? l.voiceMicDenied
        : _failed
        ? l.voiceFailed
        : _interrupted
        ? l.voiceInterrupted
        : _recovered
        ? l.voiceRecovered
        : null;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.voiceTitle)),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(OwnSpace.l),
            children: [
              if (notice != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: OwnSpace.l),
                  child: Semantics(
                    liveRegion: true,
                    child: Material(
                      color: _denied || _failed
                          ? scheme.errorContainer
                          : scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(
                        OwnShape.compactRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(OwnSpace.m),
                        child: Text(notice),
                      ),
                    ),
                  ),
                ),
              Semantics(
                label: l.voiceElapsed(_time),
                excludeSemantics: true,
                child: Text(
                  _time,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displayMedium,
                ),
              ),
              const SizedBox(height: OwnSpace.s),
              Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: OwnSpace.xl),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: OwnSpace.m,
                runSpacing: OwnSpace.m,
                children: [
                  if (_phase == _Phase.idle)
                    OwnButton.primary(
                      label: l.voiceStart,
                      icon: Icons.mic_none,
                      onPressed: _start,
                    ),
                  if (_phase == _Phase.recording)
                    OwnButton.secondary(
                      label: l.voicePause,
                      icon: Icons.pause,
                      onPressed: _pause,
                    ),
                  if (_phase == _Phase.paused)
                    OwnButton.secondary(
                      label: l.voiceResume,
                      icon: Icons.mic_none,
                      onPressed: _resume,
                    ),
                  if (_phase == _Phase.recording || _phase == _Phase.paused)
                    OwnButton.primary(
                      label: l.voiceStop,
                      icon: Icons.stop,
                      onPressed: _stop,
                    ),
                  if (_phase == _Phase.stopped) ...[
                    OwnButton.secondary(
                      label: _playing ? l.voiceStopListening : l.voiceListen,
                      icon: _playing ? Icons.stop : Icons.play_arrow,
                      onPressed: _listen,
                    ),
                    OwnButton.primary(
                      label: l.voiceAttach,
                      icon: Icons.attach_file,
                      onPressed: () => Navigator.pop(context, _path),
                    ),
                  ],
                  if (_phase != _Phase.idle)
                    OwnButton.destructive(
                      label: l.voiceDiscard,
                      icon: Icons.delete_outline,
                      onPressed: _discard,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
