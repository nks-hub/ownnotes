import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// The microphone behind one interface, so tests can drive the screen.
abstract interface class VoiceEngine {
  /// Asks for the microphone when first needed; false when refused.
  Future<bool> requestPermission();
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();

  /// Finishes the file and returns its path.
  Future<String?> stop();
  Future<void> dispose();
}

abstract interface class VoicePlayer {
  Future<void> play(String path);
  Future<void> stop();
  Stream<void> get completed;
  Future<void> dispose();
}

final class RecordVoiceEngine implements VoiceEngine {
  final _recorder = AudioRecorder();

  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Future<void> start(String path) => _recorder.start(
    const RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 64000,
      sampleRate: 44100,
      numChannels: 1,
    ),
    path: path,
  );

  @override
  Future<void> pause() => _recorder.pause();

  @override
  Future<void> resume() => _recorder.resume();

  @override
  Future<String?> stop() => _recorder.stop();

  @override
  Future<void> dispose() => _recorder.dispose();
}

final class AudioVoicePlayer implements VoicePlayer {
  final _player = AudioPlayer();

  @override
  Future<void> play(String path) => _player.play(DeviceFileSource(path));

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<void> dispose() => _player.dispose();
}

final voiceEngineFactoryProvider = Provider<VoiceEngine Function()>(
  (ref) => RecordVoiceEngine.new,
);

final voicePlayerFactoryProvider = Provider<VoicePlayer Function()>(
  (ref) => AudioVoicePlayer.new,
);

/// Where recordings are written. Not the cache folder: an interrupted
/// recording must still be there at the next start.
final voiceDirectoryProvider = FutureProvider<Directory>((ref) async {
  final support = await getApplicationSupportDirectory();
  return Directory('${support.path}/voice');
});
