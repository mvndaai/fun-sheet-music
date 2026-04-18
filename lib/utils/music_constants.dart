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
    if (frequency <= 0) return '';
    final midiFloat = 12 * (math.log(frequency / 440.0) / math.log(2)) + 69;
    final midi = midiFloat.round();
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
}
