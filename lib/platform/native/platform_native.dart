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
import 'package:record/record.dart';
import '../platform_stub.dart';

import '../../music_kit/models/sound_profile.dart' show WaveformType;

export '../platform_stub.dart';

/// Mobile implementation (Android, iOS) using audioplayers and file_picker.
class MobileTonePlayer implements PlatformTonePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playTone(double frequency, int durationMs, {WaveformType waveform = WaveformType.triangle}) async {
    if (frequency <= 0) return;
    
    try {
      final wavData = _generateWav(frequency, durationMs, waveform);
      await _player.play(BytesSource(wavData));
    } catch (e) {
      // Audio is best-effort
    }
  }

  Uint8List _generateWav(double frequency, int durationMs, WaveformType waveform) {
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

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double amplitude = 0;

      switch (waveform) {
        case WaveformType.sine:
          // Piano-like: Fundamental + 2nd harmonic + exponential decay
          final envelope = math.exp(-3.0 * t); // Decays over time
          amplitude = (math.sin(2 * math.pi * t * frequency) +
                       0.5 * math.sin(2 * math.pi * t * frequency * 2) +
                       0.2 * math.sin(2 * math.pi * t * frequency * 3)) * envelope;
          amplitude *= 0.6; // Scale down for multi-oscillator
          break;
        case WaveformType.square:
          // Xylophone-like: Fast decay, high non-harmonic transient
          final envelope = math.exp(-15.0 * t); 
          double tNorm = (t * frequency) % 1.0;
          amplitude = (tNorm < 0.5 ? 1.0 : -1.0) * envelope;
          // Add a high-pitch "clack" at the very beginning
          if (t < 0.02) {
             amplitude += 0.3 * math.sin(2 * math.pi * t * 3000) * (1 - t/0.02);
          }
          break;
        case WaveformType.sawtooth:
          // Flute-like: Smooth attack, bit of noise, slight vibrato
          final attack = (t < 0.05) ? (t / 0.05) : 1.0;
          final release = (t > (durationMs/1000.0) - 0.05) ? ((durationMs/1000.0 - t) / 0.05) : 1.0;
          final vibrato = 1.0 + 0.005 * math.sin(2 * math.pi * t * 5); // 5Hz vibrato
          amplitude = math.sin(2 * math.pi * t * frequency * vibrato) * attack * release;
          // Add subtle breath noise
          amplitude += 0.05 * (math.Random().nextDouble() * 2 - 1) * attack;
          break;
        case WaveformType.triangle:
          // Classic synth
          double tNorm = (t * frequency) % 1.0;
          amplitude = (tNorm < 0.25)
              ? 4 * tNorm
              : (tNorm < 0.75)
                  ? 2 - 4 * tNorm
                  : 4 * tNorm - 4;
          // Simple fade
          const fadeTime = 0.02;
          if (t < fadeTime) amplitude *= t / fadeTime;
          if (t > (durationMs/1000.0) - fadeTime) amplitude *= ((durationMs/1000.0) - t) / fadeTime;
          break;
      }

      bytes.setInt16(44 + i * 2, (amplitude.clamp(-1.0, 1.0) * 32767).toInt(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  @override
  void startTone(double frequency, {WaveformType waveform = WaveformType.triangle}) {
    // For now, play a reasonably long tone on mobile
    playTone(frequency, 1000, waveform: waveform);
  }

  @override
  void stopTone(double frequency) {
    _player.stop();
  }

  @override
  Future<void> playSample(String path) async {
    try {
      await _player.play(DeviceFileSource(path));
    } catch (e) {
      // Audio is best-effort
    }
  }

  @override
  void startSample(String path) {
    playSample(path);
  }

  @override
  void stopSample(String path) {
    _player.stop();
  }

  @override
  void stopAllTones() {
    _player.stop();
  }

  @override
  void dispose() => _player.dispose();
}

PlatformTonePlayer createPlatformPlayer() => MobileTonePlayer();

/// Native implementation for saving a file.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final fileName = '${title.replaceAll(' ', '_')}.xml';

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

/// Gets the directory for storing audio samples on native platforms.
Future<String?> getSamplesDirectory(String instrumentId) async {
  final appDir = await getApplicationDocumentsDirectory();
  final folder = Directory(p.join(appDir.path, 'samples', instrumentId));
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }
  return folder.path;
}

/// Native audio recorder that saves to file system.
class NativeAudioRecorder implements PlatformAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _filePath;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording(String instrumentId, String noteName) async {
    if (_isRecording) return;

    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      throw Exception('Microphone permission not granted');
    }

    final samplesDir = await getSamplesDirectory(instrumentId);
    if (samplesDir == null) {
      throw Exception('Storage not available');
    }

    _filePath = p.join(samplesDir, '$noteName.m4a');
    _isRecording = true;

    // Start recording with explicit config to avoid "adjusted" log messages
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        numChannels: 1,
        sampleRate: 48000,
      ),
      path: _filePath!,
    );
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _isRecording = false;
    await _recorder.stop();
    return _filePath;
  }

  @override
  void dispose() {
    _recorder.dispose();
  }
}

PlatformAudioRecorder createAudioRecorder() => NativeAudioRecorder();
