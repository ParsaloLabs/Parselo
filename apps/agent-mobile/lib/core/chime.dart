import 'dart:math';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Two-tone offer chime: 880Hz → 660Hz sine wave with quick attack and
/// exponential decay. Bytes are generated once in memory; no asset shipped.
class OfferChime {
  static final OfferChime _instance = OfferChime._();
  factory OfferChime() => _instance;
  OfferChime._();

  final AudioPlayer _player = AudioPlayer(playerId: 'parsalo.offer-chime');
  Uint8List? _bytes;

  Future<void> play() async {
    HapticFeedback.mediumImpact();
    try {
      _bytes ??= _buildWav();
      await _player.stop();
      await _player.play(BytesSource(_bytes!), volume: 0.6);
    } catch (_) {
      // Audio is best-effort; haptic already fired.
    }
  }

  static Uint8List _buildWav() {
    const sampleRate = 22050;
    final tones = <_Tone>[
      const _Tone(freq: 880, durationMs: 180),
      const _Tone(freq: 660, durationMs: 250),
    ];
    final totalSamples = tones.fold<int>(
      0,
      (sum, t) => sum + (sampleRate * t.durationMs ~/ 1000),
    );
    final samples = Int16List(totalSamples);
    var write = 0;
    for (final tone in tones) {
      final n = sampleRate * tone.durationMs ~/ 1000;
      for (var i = 0; i < n; i++) {
        final t = i / sampleRate;
        final progress = i / n;
        // Linear 5% attack, then exponential decay across the rest.
        final env = progress < 0.05
            ? progress / 0.05
            : exp(-3.5 * (progress - 0.05));
        final s = sin(2 * pi * tone.freq * t) * 0.3 * env;
        samples[write++] = (s * 32767).toInt().clamp(-32768, 32767);
      }
    }
    return _wrapWav(samples, sampleRate);
  }

  static Uint8List _wrapWav(Int16List samples, int sampleRate) {
    final dataSize = samples.lengthInBytes;
    final builder = BytesBuilder();
    void writeStr(String s) => builder.add(s.codeUnits);
    void writeU32(int v) {
      final b = ByteData(4)..setUint32(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }
    void writeU16(int v) {
      final b = ByteData(2)..setUint16(0, v, Endian.little);
      builder.add(b.buffer.asUint8List());
    }

    writeStr('RIFF');
    writeU32(36 + dataSize);
    writeStr('WAVE');
    writeStr('fmt ');
    writeU32(16); // PCM chunk size
    writeU16(1); // PCM format
    writeU16(1); // mono
    writeU32(sampleRate);
    writeU32(sampleRate * 2); // byte rate (sampleRate * channels * bytesPerSample)
    writeU16(2); // block align
    writeU16(16); // bits per sample
    writeStr('data');
    writeU32(dataSize);
    builder.add(samples.buffer.asUint8List());
    return builder.takeBytes();
  }
}

class _Tone {
  final int freq;
  final int durationMs;
  const _Tone({required this.freq, required this.durationMs});
}
