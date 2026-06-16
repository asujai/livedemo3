import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';

/// Ordered FIFO byte queue for PCM playback. Pure (no plugin) → unit-testable.
///
/// Guarantees order and prevents overlap by handing out bytes sequentially.
class AudioChunkQueue {
  final BytesBuilder _builder = BytesBuilder(copy: false);
  int _length = 0;

  int get length => _length;
  bool get isEmpty => _length == 0;
  bool get isNotEmpty => _length != 0;

  void add(List<int> bytes) {
    if (bytes.isEmpty) return;
    _builder.add(bytes is Uint8List ? bytes : Uint8List.fromList(bytes));
    _length += bytes.length;
  }

  /// Remove and return up to [maxBytes] bytes from the front (order preserved).
  Uint8List take(int maxBytes) {
    if (_length == 0 || maxBytes <= 0) return Uint8List(0);
    final all = _builder.toBytes();
    final n = maxBytes >= all.length ? all.length : maxBytes;
    final head = Uint8List.sublistView(all, 0, n);
    _builder
      ..clear()
      ..add(Uint8List.sublistView(all, n));
    _length = all.length - n;
    return head;
  }

  void clear() {
    _builder.clear();
    _length = 0;
  }
}

/// Plays 24 kHz mono PCM16 chunks received from Gemini, in order, no overlap.
abstract class AudioOutputService {
  /// Enqueue a 24 kHz mono PCM16 chunk for playback.
  void enqueue(List<int> pcm16);

  /// Clear the queue (e.g. when a new utterance begins).
  Future<void> clear();

  /// Stop and release resources.
  Future<void> dispose();
}

/// Real implementation backed by `flutter_pcm_sound` (feed-on-demand model).
class PcmAudioOutputService implements AudioOutputService {
  PcmAudioOutputService();

  static const int sampleRate = 24000;
  // Feed in ~120 ms frames; ask for more when the device buffer runs low.
  static const int _feedBytes = 24000 * 2 ~/ 8; // 6000 bytes ≈ 125 ms
  static const int _feedThresholdFrames = 3000;

  final AudioChunkQueue _queue = AudioChunkQueue();
  bool _setup = false;

  Future<void> _ensureSetup() async {
    if (_setup) return;
    await FlutterPcmSound.setup(sampleRate: sampleRate, channelCount: 1);
    FlutterPcmSound.setFeedThreshold(_feedThresholdFrames);
    FlutterPcmSound.setFeedCallback(_onFeed);
    _setup = true;
  }

  @override
  void enqueue(List<int> pcm16) {
    _queue.add(pcm16);
    _ensureSetup().then((_) => _feed()).catchError((Object e) {
      debugPrint('PCM playback error: ${e.runtimeType}');
    });
  }

  void _onFeed(int remainingFrames) => _feed();

  void _feed() {
    if (!_setup) return;
    final bytes = _queue.take(_feedBytes);
    if (bytes.isEmpty) return; // nothing to play right now
    // Interpret little-endian bytes as Int16 samples.
    final samples = bytes.buffer.asInt16List(bytes.offsetInBytes, bytes.lengthInBytes ~/ 2);
    FlutterPcmSound.feed(PcmArrayInt16.fromList(samples));
  }

  @override
  Future<void> clear() async => _queue.clear();

  @override
  Future<void> dispose() async {
    _queue.clear();
    if (_setup) {
      await FlutterPcmSound.release();
      _setup = false;
    }
  }
}
