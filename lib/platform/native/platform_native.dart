import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../platform_stub.dart';

/// Mobile implementation (Android, iOS) using audioplayers and file_picker.
class MobileTonePlayer implements PlatformTonePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    if (frequency <= 0) return;
    
    try {
      final wavData = _generateWav(frequency, durationMs);
      await _player.play(BytesSource(wavData));
    } catch (e) {
      // Audio is best-effort
    }
  }

  Uint8List _generateWav(double frequency, int durationMs) {
    const sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).toInt();
    final dataSize = numSamples * 2;
    final fileSize = 44 + dataSize;
    final bytes = ByteData(fileSize);

    // RIFF header
    bytes.setUint8(0, 0x52); bytes.setUint8(1, 0x49); bytes.setUint8(2, 0x46); bytes.setUint8(3, 0x46);
    bytes.setUint32(4, fileSize - 8, Endian.little);
    bytes.setUint8(8, 0x57); bytes.setUint8(9, 0x41); bytes.setUint8(10, 0x56); bytes.setUint8(11, 0x45);

    // fmt chunk
    bytes.setUint8(12, 0x66); bytes.setUint8(13, 0x6D); bytes.setUint8(14, 0x74); bytes.setUint8(15, 0x20);
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);

    // data chunk
    bytes.setUint8(36, 0x64); bytes.setUint8(37, 0x61); bytes.setUint8(38, 0x74); bytes.setUint8(39, 0x61);
    bytes.setUint32(40, dataSize, Endian.little);

    const fadeSamples = 441;
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      // Triangle wave is louder than sine wave for the same peak amplitude.
      double tNorm = (t * frequency) % 1.0;
      double amplitude = (tNorm < 0.25)
          ? 4 * tNorm
          : (tNorm < 0.75)
              ? 2 - 4 * tNorm
              : 4 * tNorm - 4;

      if (i < fadeSamples) {
        amplitude *= i / fadeSamples;
      } else if (i > numSamples - fadeSamples) {
        amplitude *= (numSamples - i) / fadeSamples;
      }
      bytes.setInt16(44 + i * 2, (amplitude * 32767).toInt(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  @override
  void startTone(double frequency) {
    // For now, play a reasonably long tone on mobile
    playTone(frequency, 1000);
  }

  @override
  void stopTone(double frequency) {
    _player.stop();
  }

  @override
  void dispose() => _player.dispose();
}

PlatformTonePlayer createPlatformPlayer() => MobileTonePlayer();

/// Native implementation for saving a file.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final fileName = '${title.replaceAll(' ', '_')}.musicxml';

  await FilePicker.saveFile(
    fileName: fileName,
    bytes: bytes,
    type: FileType.custom,
    allowedExtensions: ['musicxml', 'xml'],
  );
}

/// Opens a native database connection (SQLite).
QueryExecutor openDatabaseConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'db.sqlite'));
    return NativeDatabase(file);
  });
}
