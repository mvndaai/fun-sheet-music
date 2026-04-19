import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';
import '../utils/music_constants.dart';

/// Listens to the microphone and emits detected note names in real time.
class AudioService {
  StreamSubscription<Uint8List>? _audioSub;
  StreamController<String>? _noteController;
  bool _isListening = false;
  final AudioRecorder _recorder = AudioRecorder();

  static const int _sampleRate = 44100;
  static const int _chunkSize = 4096; // ~93ms at 44100 Hz

  bool get isListening => _isListening;

  /// Returns a stream of detected note names (e.g. "C5", "G4").
  /// Emits an empty string when no clear pitch is detected.
  Stream<String> get noteStream =>
      _noteController?.stream ?? const Stream.empty();

  /// Requests microphone permission and starts listening.
  Future<bool> startListening() async {
    if (_isListening) return true;

    // Check and request permission
    if (!await _recorder.hasPermission()) {
      debugPrint('Microphone permission denied');
      return false;
    }

    _noteController = StreamController<String>.broadcast();
    _isListening = true;

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: _sampleRate,
          numChannels: 1,
        ),
      );

      final buffer = <int>[];
      _audioSub = stream.listen((data) {
        buffer.addAll(data);
        while (buffer.length >= _chunkSize * 2) {
          // 2 bytes per PCM16 sample
          final chunk = buffer.sublist(0, _chunkSize * 2);
          buffer.removeRange(0, _chunkSize * 2);
          final note = _detectPitch(chunk);
          _noteController?.add(note);
        }
      });
    } catch (e) {
      debugPrint('AudioService error: $e');
      _isListening = false;
      return false;
    }
    return true;
  }

  /// Stops microphone listening.
  Future<void> stopListening() async {
    _isListening = false;
    await _audioSub?.cancel();
    _audioSub = null;
    await _recorder.stop();
    await _noteController?.close();
    _noteController = null;
  }

  /// Detects the dominant pitch in raw PCM16 bytes and returns note name.
  String _detectPitch(List<int> pcmBytes) {
    // Convert PCM16 bytes to float samples [-1.0, 1.0]
    final samples = Float64List(_chunkSize);
    for (int i = 0; i < _chunkSize && (i * 2 + 1) < pcmBytes.length; i++) {
      final lo = pcmBytes[i * 2] & 0xFF;
      final hi = pcmBytes[i * 2 + 1];
      // Signed 16-bit little-endian
      int val = (hi << 8) | lo;
      if (val >= 0x8000) val -= 0x10000;
      samples[i] = val / 32768.0;
    }

    // Apply Hann window
    for (int i = 0; i < _chunkSize; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (_chunkSize - 1)));
      samples[i] *= w;
    }

    // FFT
    final fft = FFT(_chunkSize);
    final freq = fft.realFft(samples);

    // Find the peak frequency bin
    double maxMag = 0;
    int maxBin = 0;
    // Only look in the range corresponding to human voice / instrument (80-2000 Hz)
    final minBin = (80.0 * _chunkSize / _sampleRate).round();
    final maxBinRange = (2000.0 * _chunkSize / _sampleRate).round();
    for (int i = minBin; i < maxBinRange && i < freq.length; i++) {
      final re = freq[i].x;
      final im = freq[i].y;
      final mag = re * re + im * im;
      if (mag > maxMag) {
        maxMag = mag;
        maxBin = i;
      }
    }

    if (maxBin == 0) return '';

    // Parabolic interpolation for better frequency estimation
    double refinedBin = maxBin.toDouble();
    if (maxBin > 0 && maxBin < freq.length - 1) {
      final prev = _mag(freq[maxBin - 1]);
      final cur = _mag(freq[maxBin]);
      final next = _mag(freq[maxBin + 1]);
      final denom = 2 * cur - prev - next;
      if (denom != 0) {
        refinedBin = maxBin + 0.5 * (next - prev) / denom;
      }
    }

    final frequency = refinedBin * _sampleRate / _chunkSize;
    if (frequency < 40) return '';

    return MusicConstants.frequencyToNoteName(frequency);
  }

  double _mag(Float64x2 complex) {
    return complex.x * complex.x + complex.y * complex.y;
  }

  void dispose() {
    stopListening();
  }
}