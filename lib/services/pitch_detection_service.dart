import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';
import '../music_kit/utils/music_constants.dart';

/// Listens to the microphone and emits detected note names in real time.
/// Uses Harmonic Product Spectrum (HPS) and advanced filtering to ignore voices and focus on instruments.
class PitchDetectionService {
  StreamSubscription<Uint8List>? _audioSub;
  StreamController<String>? _noteController;
  bool _isListening = false;
  final AudioRecorder _recorder = AudioRecorder();

  static const int _sampleRate = 44100;
  static const int _chunkSize = 4096; // ~93ms at 44100 Hz
  static const double _volumeThreshold = 0.002; // Lowered for better sensitivity

  // State for stable note detection
  String _currentStableNote = '';
  String _candidateNote = '';
  int _candidateCount = 0;
  int _silenceCount = 0;
  
  static const int _requiredStability = 1; // Reduced to improve responsiveness
  static const int _maxSilence = 3; // Clear faster when sound stops

  bool get isListening => _isListening;

  /// Returns a stream of detected note names (e.g. "C5", "G4").
  /// Emits an empty string when no clear pitch is detected.
  Stream<String> get noteStream =>
      _noteController?.stream ?? const Stream.empty();

  /// Requests microphone permission and starts listening.
  Future<bool> startListening() async {
    if (_isListening) return true;

    if (!await _recorder.hasPermission()) {
      debugPrint('Microphone permission denied');
      return false;
    }

    _noteController = StreamController<String>.broadcast();
    _isListening = true;
    _currentStableNote = '';
    _candidateNote = '';
    _candidateCount = 0;
    _silenceCount = 0;

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
        if (!_isListening) return;
        buffer.addAll(data);
        while (buffer.length >= _chunkSize * 2 && _isListening) {
          final chunk = buffer.sublist(0, _chunkSize * 2);
          buffer.removeRange(0, _chunkSize * 2);
          final note = _detectPitchHPS(chunk);
          
          if (note.isEmpty) {
            _silenceCount++;
            if (_silenceCount >= _maxSilence) {
              if (_currentStableNote.isNotEmpty) {
                _currentStableNote = '';
                if (_isListening) _noteController?.add('');
              }
              _candidateNote = '';
              _candidateCount = 0;
            }
          } else {
            _silenceCount = 0;
            if (note == _currentStableNote) {
              _candidateNote = '';
              _candidateCount = 0;
              if (_isListening) _noteController?.add(_currentStableNote);
            } else if (note == _candidateNote) {
              _candidateCount++;
              if (_candidateCount >= _requiredStability) {
                _currentStableNote = note;
                _candidateNote = '';
                _candidateCount = 0;
                if (_isListening) _noteController?.add(_currentStableNote);
              }
            } else {
              _candidateNote = note;
              _candidateCount = 1;
            }
          }
        }
      });
    } catch (e) {
      debugPrint('PitchDetectionService error: $e');
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

  /// Detects pitch using Harmonic Product Spectrum (HPS).
  /// HPS is excellent at ignoring voices because it multiplies the frequency spectrum by its 
  /// decimated versions, emphasizing the fundamental frequency of harmonic instruments 
  /// while suppressing the non-harmonic noise typical of speech.
  String _detectPitchHPS(List<int> pcmBytes) {
    // 1. Convert PCM16 to Float samples
    final samples = Float64List(_chunkSize);
    double sumSq = 0;
    for (int i = 0; i < _chunkSize && (i * 2 + 1) < pcmBytes.length; i++) {
      final lo = pcmBytes[i * 2] & 0xFF;
      final hi = pcmBytes[i * 2 + 1];
      int val = (hi << 8) | lo;
      if (val >= 0x8000) val -= 0x10000;
      final s = val / 32768.0;
      samples[i] = s;
      sumSq += s * s;
    }

    // Volume threshold check
    final rms = math.sqrt(sumSq / _chunkSize);
    if (rms < _volumeThreshold) return '';

    // 2. Apply Hann Window to reduce spectral leakage
    for (int i = 0; i < _chunkSize; i++) {
      final w = 0.5 * (1 - math.cos(2 * math.pi * i / (_chunkSize - 1)));
      samples[i] *= w;
    }

    // 3. Perform FFT
    final fft = FFT(_chunkSize);
    final freq = fft.realFft(samples);
    final magnitudes = Float64List(freq.length);
    for (int i = 0; i < freq.length; i++) {
      magnitudes[i] = math.sqrt(freq[i].x * freq[i].x + freq[i].y * freq[i].y);
    }

    // 4. Harmonic Product Spectrum (HPS)
    // We multiply the spectrum by its downsampled versions.
    // Using 2 harmonics (1x and 2x) is often more robust for a variety of instruments.
    final hpsSize = magnitudes.length ~/ 2;
    final hps = Float64List(hpsSize);
    for (int i = 0; i < hpsSize; i++) {
      hps[i] = magnitudes[i] * magnitudes[i * 2];
    }

    // 5. Find Peak in HPS
    double maxMag = 0;
    int maxBin = 0;
    // Human voice/Instrument range: ~80Hz to ~2000Hz
    final minBin = (80.0 * _chunkSize / _sampleRate).round();
    for (int i = minBin; i < hpsSize; i++) {
      if (hps[i] > maxMag) {
        maxMag = hps[i];
        maxBin = i;
      }
    }

    // If the peak is too weak, ignore it
    if (maxBin == 0 || maxMag < 1e-10) return '';

    final frequency = maxBin * _sampleRate / _chunkSize;
    if (frequency < 50) return '';

    return MusicConstants.frequencyToNoteName(frequency);
  }

  void dispose() {
    stopListening();
  }
}
