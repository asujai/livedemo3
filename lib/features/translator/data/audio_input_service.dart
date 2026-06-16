import 'dart:async';
import 'dart:typed_data';

import 'package:record/record.dart';

/// Captures microphone audio as 16 kHz mono PCM16, emitted in ~100 ms chunks.
abstract class AudioInputService {
  /// Whether microphone permission has been granted.
  Future<bool> hasPermission();

  /// Request microphone permission; returns the resulting grant state.
  Future<bool> requestPermission();

  /// Start capturing. Emits raw PCM16 chunks (16 kHz, mono, little-endian).
  Stream<List<int>> start();

  /// Stop capturing.
  Future<void> stop();
}

/// Real implementation backed by the `record` package.
class RecordAudioInputService implements AudioInputService {
  RecordAudioInputService();

  static const int sampleRate = 16000;

  // 100 ms of 16 kHz mono PCM16 = 16000 * 0.1 * 2 bytes = 3200 bytes.
  static const int _chunkBytes = 3200;

  final AudioRecorder _recorder = AudioRecorder();
  final BytesBuilder _buffer = BytesBuilder(copy: false);

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  // `record` requests the permission as part of hasPermission().
  @override
  Future<bool> requestPermission() => _recorder.hasPermission();

  @override
  Stream<List<int>> start() async* {
    const config = RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    );
    final raw = await _recorder.startStream(config);

    await for (final data in raw) {
      _buffer.add(data);
      // Re-chunk into ~100 ms frames for a steady stream to Gemini.
      while (_buffer.length >= _chunkBytes) {
        final all = _buffer.toBytes();
        final frame = Uint8List.sublistView(all, 0, _chunkBytes);
        _buffer
          ..clear()
          ..add(Uint8List.sublistView(all, _chunkBytes));
        yield frame;
      }
    }
    // Flush any tail when the stream ends.
    if (_buffer.length > 0) {
      yield _buffer.toBytes();
      _buffer.clear();
    }
  }

  @override
  Future<void> stop() async {
    await _recorder.stop();
    _buffer.clear();
  }
}
