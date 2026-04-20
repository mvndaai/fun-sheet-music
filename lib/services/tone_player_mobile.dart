import 'package:audioplayers/audioplayers.dart';
import 'tone_player_stub.dart';

/// Mobile implementation using audioplayers
class MobileTonePlayer implements PlatformTonePlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playTone(double frequency, int durationMs) async {
    try {
      // audioplayers is better for actual audio files,
      // but we'll use it to play a short notification sound or similar if needed.
      // For now, let's just ensure it doesn't crash the build.
      await _player.play(AssetSource('sample_songs/beep.mp3'));
    } catch (e) {
      // Ignore errors - audio is best-effort
    }
  }

  @override
  void dispose() {
    _player.dispose();
  }
}

PlatformTonePlayer createPlatformPlayer() => MobileTonePlayer();
