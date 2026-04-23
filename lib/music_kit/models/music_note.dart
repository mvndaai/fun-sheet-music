import 'dart:math' as math;

/// Represents a musical note parsed from MusicXML.
class MusicNote {
  final String step; // C, D, E, F, G, A, B
  final int octave;
  final double alter; // semitone alteration: -1=flat, 0=natural, 1=sharp
  final double duration; // in divisions
  final String type; // whole, half, quarter, eighth, 16th, etc.
  final bool isRest;
  final bool isChordContinuation; // part of a chord (not the first note)
  final int dot; // number of dots
  final String? beam; // 'begin', 'continue', 'end' or null

  const MusicNote({
    required this.step,
    required this.octave,
    required this.duration,
    required this.type,
    this.alter = 0,
    this.isRest = false,
    this.isChordContinuation = false,
    this.dot = 0,
    this.beam,
  });

  bool get isDotted => dot > 0;

  /// Returns the note name in letter notation (e.g. "C#5")
  String get letterName {
    if (isRest) return 'Rest';
    final alterStr = alter == 1
        ? '#'
        : alter == -1
            ? 'b'
            : '';
    return '$step$alterStr$octave';
  }

  /// Returns the solfège name (Do, Re, Mi, ...) for the natural note step.
  String get solfegeName {
    if (isRest) return 'Rest';
    const solfege = {
      'C': 'Do',
      'D': 'Re',
      'E': 'Mi',
      'F': 'Fa',
      'G': 'Sol',
      'A': 'La',
      'B': 'Si',
    };
    final base = solfege[step] ?? step;
    if (alter == 1) return '$base#';
    if (alter == -1) return '${base}b';
    return base;
  }

  /// MIDI note number (C4 = 60).
  int get midiNumber {
    if (isRest) return -1;
    const stepSemitones = {
      'C': 0,
      'D': 2,
      'E': 4,
      'F': 5,
      'G': 7,
      'A': 9,
      'B': 11,
    };
    final base = stepSemitones[step] ?? 0;
    return 12 * (octave + 1) + base + alter.round();
  }

  /// Frequency in Hz using equal temperament (A4 = 440 Hz).
  double get frequency {
    if (isRest) return 0;
    return 440.0 * math.pow(2.0, (midiNumber - 69) / 12.0).toDouble();
  }

  @override
  String toString() => 'MusicNote($letterName, $type)';
}
