import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'tone_player_stub.dart';

/// Mobile implementation using audioplayers and in-memory WAV generation.
/// This provides a basic synthesizer for Android and iOS without extra dependencies.
class MobileTonePlayer implements PlatformTonePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    if (frequency <= 0) return;
    
    try {
      final wavData = _generateWav(frequency, durationMs);
      // Using BytesSource to play generated PCM data
      await _player.play(BytesSource(wavData));
    } catch (e) {
      // Audio is best-effort
    }
  }

  /// Generates a simple 16-bit Mono WAV file in memory.
  Uint8List _generateWav(double frequency, int durationMs) {
    const sampleRate = 22050; // Standard low-quality sample rate
    final numSamples = (sampleRate * durationMs / 1000).toInt();
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 44 + dataSize;

    final bytes = ByteData(fileSize);

    // RIFF header
    bytes.setUint8(0, 0x52); // R
    bytes.setUint8(1, 0x49); // I
    bytes.setUint8(2, 0x46); // F
    bytes.setUint8(3, 0x46); // F
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); // W
    bytes.setUint8(9, 0x41); // A
    bytes.setUint8(10, 0x56); // V
    bytes.setUint8(11, 0x45); // E

    // fmt chunk
    bytes.setUint8(12, 0x66); // f
    bytes.setUint8(13, 0x6D); // m
    bytes.setUint8(14, 0x74); // t
    bytes.setUint8(15, 0x20); // ' '
    bytes.setUint32(16, 16, Endian.little); // Chunk size
    bytes.setUint16(20, 1, Endian.little);  // PCM format
    bytes.setUint16(22, 1, Endian.little);  // Mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    bytes.setUint16(32, 2, Endian.little);  // Block align
    bytes.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    bytes.setUint8(36, 0x64); // d
    bytes.setUint8(37, 0x61); // a
    bytes.setUint8(38, 0x74); // t
    bytes.setUint8(39, 0x61); // a
    bytes.setUint32(40, dataSize, Endian.little);

    // Generate sine wave samples with a small fade in/out to avoid pops
    const fadeSamples = 441; // ~20ms at 22050Hz
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double amplitude = math.sin(2 * math.pi * frequency * t);
      
      // Apply envelope
      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }

      // Convert to 16-bit signed integer
      final sample = (amplitude * 32767).toInt();
      bytes.setInt16(44 + i * 2, sample, Endian.little);
    }

    return bytes.buffer.asUint8List();
  }

  @override
  void dispose() {
    _player.dispose();
  }
}

PlatformTonePlayer createPlatformPlayer() => MobileTonePlayer();
