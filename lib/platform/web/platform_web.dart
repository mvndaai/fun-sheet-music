import 'dart:convert';
import 'dart:js_interop';
import 'dart:developer' as developer;
import 'package:web/web.dart' as web;
import 'package:drift/drift.dart';
import 'package:drift/web.dart';
import '../platform_stub.dart';

/// Web implementation using Web Audio API and package:web.
class WebTonePlayer implements PlatformTonePlayer {
  web.AudioContext? _audioContext;
  final Map<double, (web.OscillatorNode, web.GainNode)> _activeNotes = {};

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
    // On web, path would likely be a blob URL. 
    // This is a minimal implementation.
    try {
      final audio = web.HTMLAudioElement()..src = path;
      audio.play();
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
    // Not easily implemented without tracking the AudioElement
  }

  @override
  void dispose() {
    try {
      for (final note in _activeNotes.values) {
        note.$1.stop();
      }
      _activeNotes.clear();
      _audioContext?.close();
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
  anchor.setAttribute('download', '${title.replaceAll(' ', '_')}.musicxml');
  
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
