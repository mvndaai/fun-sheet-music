import 'dart:math' as math;

/// Musical constants and helper functions.
class MusicConstants {
  MusicConstants._();

  /// Maps note type names to their relative beat durations.
  static const Map<String, double> typeToDuration = {
    '1024th': 1 / 256,
    '512th': 1 / 128,
    '256th': 1 / 64,
    '128th': 1 / 32,
    '64th': 1 / 16,
    '32nd': 1 / 8,
    '16th': 1 / 4,
    'eighth': 1 / 2,
    'quarter': 1.0,
    'half': 2.0,
    'whole': 4.0,
    'breve': 8.0,
    'long': 16.0,
    'maxima': 32.0,
  };

  /// Maps MIDI semitone offsets (0–11) to note names.
  static const List<String> chromaticNotes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Maps note steps to their solfège syllables (fixed Do).
  static const Map<String, String> stepToSolfege = {
    'C': 'Do',
    'D': 'Re',
    'E': 'Mi',
    'F': 'Fa',
    'G': 'Sol',
    'A': 'La',
    'B': 'Si',
  };

  /// Frequency tolerance for pitch detection (in semitones).
  static const double pitchToleranceSemitones = 0.5;

  /// Returns the closest note name to a given frequency (Hz).
  static String frequencyToNoteName(double frequency) {
    return midiToNoteName(frequencyToMidi(frequency));
  }

  /// Returns the note name for a given MIDI number.
  static String midiToNoteName(int midi) {
    if (midi < 0 || midi > 127) return '';
    final semitone = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${chromaticNotes[semitone]}$octave';
  }

  /// Returns the MIDI number for a given frequency.
  static int frequencyToMidi(double frequency) {
    if (frequency <= 0) return -1;
    return (12 * math.log(frequency / 440.0) / math.log(2) + 69).round();
  }

  /// Returns the MIDI number for a given note name (e.g. "C5", "F#4").
  static int noteNameToMidi(String name) {
    if (name.isEmpty) return -1;
    // Parse e.g. "C5", "F#4", "Bb3"
    final match = RegExp(r'^([A-G])([#b])?(-?\d+)$').firstMatch(name);
    if (match == null) return -1;
    final step = match.group(1)!;
    final acc = match.group(2) ?? '';
    final octave = int.tryParse(match.group(3)!) ?? 4;
    const semitones = {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11
    };
    final base = semitones[step] ?? 0;
    final alter = acc == '#' ? 1 : acc == 'b' ? -1 : 0;
    return 12 * (octave + 1) + base + alter;
  }

  /// Returns the frequency (Hz) for a given MIDI number.
  static double midiToFrequency(int midi) {
    if (midi < 0) return 0;
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0).toDouble();
  }

  /// List of instrument emojis.

  static const List<String> instrumentEmojis = [
    '🎹', '🎸', '🎻', '🎷', '🎺', '🪕', '🥁', '🪘', '🪗', '🪈', '📯', '🔔', '🎵', '🎶', '🎼', '🎤', '🎧', '📻', '🎙️', '🎚️', '🎛️', '🔊', '🔉', '🔈', '🔇', '📣', '📢', '🔕', '🌈', '✨', '⭐', '🌟'
  ];

  /// The application name.
  static const String appName = 'Flutter Music';
}
