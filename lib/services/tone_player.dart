import 'dart:async';
// Conditional imports for web vs mobile
import 'tone_player_stub.dart'
    if (dart.library.html) 'tone_player_web.dart'
    if (dart.library.io) 'tone_player_mobile.dart' as platform;

/// Service for playing musical tones and metronome clicks.
class TonePlayer {
  Timer? _metronomeTimer;
  bool _isMetronomeRunning = false;
  final _platformPlayer = platform.createPlatformPlayer();
  
  // Track the next expected beat time for more accurate scheduling
  DateTime? _nextBeatTime;
  double _currentBpm = 120;

  bool get isMetronomeRunning => _isMetronomeRunning;

  /// Plays a musical note at the given frequency.
  Future<void> playNote(double frequency) async {
    if (frequency <= 0) return;
    await _platformPlayer.playTone(frequency, 300);
  }

  /// Starts the metronome at the given tempo (BPM).
  void startMetronome(double bpm, {String sound = 'tick', void Function()? onBeat}) {
    stopMetronome();

    _currentBpm = bpm;
    final intervalMs = (60000.0 / bpm).round();
    _isMetronomeRunning = true;

    // Play click immediately
    _playMetronomeClick(sound);
    onBeat?.call();

    _nextBeatTime = DateTime.now().add(Duration(milliseconds: intervalMs));
    _scheduleNextBeat(sound, onBeat);
  }

  void _scheduleNextBeat(String sound, void Function()? onBeat) {
    if (!_isMetronomeRunning || _nextBeatTime == null) return;

    final now = DateTime.now();
    final delay = _nextBeatTime!.difference(now);
    
    // If we're late, play immediately and catch up
    if (delay.inMilliseconds <= 0) {
      _tick(sound, onBeat);
      return;
    }

    _metronomeTimer = Timer(delay, () => _tick(sound, onBeat));
  }

  void _tick(String sound, void Function()? onBeat) {
    if (!_isMetronomeRunning) return;

    _playMetronomeClick(sound);
    onBeat?.call();

    // Calculate next beat time based on the previous expected time, not the actual time
    // This prevents drift from accumulating.
    final intervalMs = (60000.0 / _currentBpm).round();
    _nextBeatTime = _nextBeatTime!.add(Duration(milliseconds: intervalMs));
    
    _scheduleNextBeat(sound, onBeat);
  }

  /// Stops the metronome.
  void stopMetronome() {
    _metronomeTimer?.cancel();
    _metronomeTimer = null;
    _isMetronomeRunning = false;
    _nextBeatTime = null;
  }

  /// Plays a metronome click sound.
  Future<void> _playMetronomeClick(String sound) async {
    if (sound == 'beep') {
      await _platformPlayer.playTone(1000.0, 100);
    } else {
      // Default 'tick' - shorter and higher pitch for a "tick" sound
      await _platformPlayer.playTone(2000.0, 20);
    }
  }

  /// Disposes of resources.
  void dispose() {
    stopMetronome();
    _platformPlayer.dispose();
  }
}
