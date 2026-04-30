import 'dart:convert';
import 'dart:js_interop';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:web/web.dart' as web;
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import 'package:record/record.dart';
import '../platform_stub.dart';
import 'audio_storage.dart';

export '../platform_stub.dart';

/// Web implementation using Web Audio API and package:web.
class WebTonePlayer implements PlatformTonePlayer {
  web.AudioContext? _audioContext;
  final Map<double, (web.OscillatorNode, web.GainNode)> _activeNotes = {};
  final Map<String, web.HTMLAudioElement> _activeSamples = {};
  final AudioStorage _audioStorage = AudioStorage();

  web.AudioContext get _context {
    _audioContext ??= web.AudioContext();
    return _audioContext!;
  }

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    try {
      final context = _context;
      final oscillator = context.createOscillator();
      final gainNode = context.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);

      oscillator.frequency.value = frequency;
      oscillator.type = 'triangle';

      // Set volume with envelope to avoid clicks
      final now = context.currentTime;
      final duration = durationMs / 1000.0;
      const fadeTime = 0.01; // 10ms fade

      final gain = gainNode.gain;
      gain.setValueAtTime(0, now);
      gain.linearRampToValueAtTime(0.5, now + fadeTime);
      gain.setValueAtTime(0.5, now + duration - fadeTime);
      gain.linearRampToValueAtTime(0, now + duration);

      oscillator.start(now);
      oscillator.stop(now + duration);
    } catch (e) {
      // Ignore errors - audio is best-effort
      developer.log('Web audio error', error: e, name: 'WebTonePlayer');
    }
  }

  @override
  void startTone(double frequency) {
    try {
      final context = _context;
      final oscillator = context.createOscillator();
      final gainNode = context.createGain();

      oscillator.connect(gainNode);
      gainNode.connect(context.destination);

      oscillator.frequency.value = frequency;
      oscillator.type = 'triangle';

      final now = context.currentTime;
      const fadeTime = 0.01;
      gainNode.gain.setValueAtTime(0, now);
      gainNode.gain.linearRampToValueAtTime(0.5, now + fadeTime);

      oscillator.start();
      _activeNotes[frequency] = (oscillator, gainNode);
    } catch (e) {
      developer.log('Web audio start error', error: e, name: 'WebTonePlayer');
    }
  }

  @override
  void stopTone(double frequency) {
    try {
      final note = _activeNotes.remove(frequency);
      if (note == null) return;

      final (oscillator, gainNode) = note;
      final context = _context;
      final now = context.currentTime;
      const fadeTime = 0.02;

      gainNode.gain.setValueAtTime(gainNode.gain.value, now);
      gainNode.gain.linearRampToValueAtTime(0, now + fadeTime);
      oscillator.stop(now + fadeTime);
    } catch (e) {
      developer.log('Web audio stop error', error: e, name: 'WebTonePlayer');
    }
  }

  @override
  Future<void> playSample(String path) async {
    try {
      String audioSrc;
      
      // Check if this is an IndexedDB key (format: "instrumentId:noteName")
      if (path.contains(':') && !path.startsWith('http') && !path.startsWith('blob:')) {
        // Load from IndexedDB
        final blobUrl = await _audioStorage.createBlobUrl(path);
        if (blobUrl == null) {
          developer.log('Audio not found in IndexedDB: $path', name: 'WebTonePlayer');
          return;
        }
        audioSrc = blobUrl;
      } else {
        // Regular URL or blob URL
        audioSrc = path;
      }
      
      final audio = web.HTMLAudioElement()..src = audioSrc;
      await audio.play().toDart;
      
      // Clean up blob URL after playback if we created it
      if (audioSrc.startsWith('blob:') && audioSrc != path) {
        // Wait a bit for playback to start, then revoke
        Future.delayed(const Duration(seconds: 5), () {
          web.URL.revokeObjectURL(audioSrc);
        });
      }
    } catch (e) {
      developer.log('Web audio sample error', error: e, name: 'WebTonePlayer');
    }
  }

  @override
  void startSample(String path) {
    playSample(path);
  }

  @override
  void stopSample(String path) {
    // Stop any active sample with this path
    final sample = _activeSamples.remove(path);
    sample?.pause();
  }

  @override
  void dispose() {
    try {
      for (final note in _activeNotes.values) {
        note.$1.stop();
      }
      _activeNotes.clear();
      
      for (final sample in _activeSamples.values) {
        sample.pause();
      }
      _activeSamples.clear();
      
      _audioContext?.close();
      _audioStorage.dispose();
    } catch (e) {
      // Ignore
    }
    _audioContext = null;
  }
}

PlatformTonePlayer createPlatformPlayer() => WebTonePlayer();

/// Web implementation for downloading a file using package:web.
Future<void> saveFile({required String title, required String content}) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'application/xml'),
  );
  
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.setAttribute('download', '${title.replaceAll(' ', '_')}.xml');
  
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  
  web.URL.revokeObjectURL(url);
}

/// Opens a web-based database connection.
QueryExecutor openDatabaseConnection() {
  return WebDatabase('app_db', logStatements: false);
}

/// Web doesn't support file system access for audio samples.
/// Returns null to indicate that sample recording is not available.
Future<String?> getSamplesDirectory(String instrumentId) async {
  return null; // File system not available on web
}

/// Web audio recorder with 3-second hard limit and IndexedDB storage.
class WebAudioRecorder implements PlatformAudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioStorage _storage = AudioStorage();
  Timer? _recordingTimer;
  String? _instrumentId;
  String? _noteName;
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

    _instrumentId = instrumentId;
    _noteName = noteName;
    _isRecording = true;

    // Start recording with explicit config to avoid "adjusted" log messages
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 48000,
      ),
      path: 'temp_recording.wav',
    );

    // Set 3-second hard limit
    _recordingTimer = Timer(const Duration(seconds: 3), () async {
      if (_isRecording) {
        await stopRecording();
      }
    });
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    _recordingTimer?.cancel();
    _recordingTimer = null;
    _isRecording = false;

    try {
      final blobUrl = await _recorder.stop();
      if (blobUrl == null || _instrumentId == null || _noteName == null) {
        return null;
      }

      // Fetch the blob from the URL
      final response = await web.window.fetch(blobUrl.toJS).toDart;
      final blob = await response.blob().toDart;

      // Save to IndexedDB
      final key = await _storage.saveAudioBlob(
        instrumentId: _instrumentId!,
        noteName: _noteName!,
        blob: blob,
      );

      // Revoke the blob URL to free memory
      web.URL.revokeObjectURL(blobUrl);

      return key;
    } catch (e) {
      developer.log('Failed to save recording', error: e, name: 'WebAudioRecorder');
      return null;
    }
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorder.dispose();
    _storage.dispose();
  }
}

PlatformAudioRecorder createAudioRecorder() => WebAudioRecorder();
