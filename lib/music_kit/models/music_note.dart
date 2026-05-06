import 'dart:math' as math;

enum NoteLabelMode {
  letters,
  solfege,
  none,
}

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
  final String? beam; // 'begin', 'continue', 'end' or null (level 1)
  final String? beam2; // 'begin', 'continue', 'end' or null (level 2)
  final bool isTied; // whether this note is tied to the next
  final bool isTiedToPrevious; // whether this note is tied from the previous
  final bool isPlaceholder; // whether this note was auto-generated to fill a measure
  final Map<int, String> lyrics; // verse number -> lyric text

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
    this.beam2,
    this.isTied = false,
    this.isTiedToPrevious = false,
    this.isPlaceholder = false,
    this.lyrics = const {},
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

  /// Returns a display label for the note based on the given mode.
  String labelFor(NoteLabelMode mode) {
    if (isRest) return '';
    return switch (mode) {
      NoteLabelMode.letters => letterName.replaceAll(RegExp(r'\d'), ''),
      NoteLabelMode.solfege => solfegeName,
      NoteLabelMode.none => '',
    };
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
  String toString() => 'MusicNote($letterName, $type, lyrics: $lyrics)';

  /// Returns the resolved lyric for a given verse, handling variables and last-verse logic.
  String getResolvedLyric(int verse, Map<String, List<String>> variables, {bool isLastVerse = false, List<Map<String, String>>? variableSets}) {
    String? lyric = lyrics[verse];
    
    // Last verse override (convention: use high verse number like 99 for "last")
    if (isLastVerse && lyrics.containsKey(99)) {
      lyric = lyrics[99];
    }

    // Fallback to verse 1 if current verse is missing and verse 1 exists
    // (Common for variable-based lyrics where only verse 1 is defined as a template)
    if ((lyric == null || lyric.isEmpty) && verse > 1 && lyrics.containsKey(1)) {
      lyric = lyrics[1];
    }

    if (lyric == null || lyric.isEmpty) return '';

    // Resolve variables: {{varName}}
    String resolved = lyric;

    // 1. Check new structure (Variable Sets)
    if (variableSets != null && variableSets.isNotEmpty) {
      final setIndex = verse - 1;
      final set = setIndex < variableSets.length ? variableSets[setIndex] : variableSets.last;
      set.forEach((name, value) {
        resolved = resolved.replaceAll('{{$name}}', value);
      });
    }

    // 2. Check legacy structure (Map of Lists)
    variables.forEach((name, values) {
      final placeholder = '{{$name}}';
      if (resolved.contains(placeholder)) {
        final val = (verse - 1) < values.length ? values[verse - 1] : (values.isNotEmpty ? values.last : '');
        resolved = resolved.replaceAll(placeholder, val);
      }
    });

    return resolved;
  }

  MusicNote copyWith({
    String? step,
    int? octave,
    double? alter,
    double? duration,
    String? type,
    bool? isRest,
    bool? isChordContinuation,
    int? dot,
    String? beam,
    String? beam2,
    bool? isTied,
    bool? isTiedToPrevious,
    bool? isPlaceholder,
    Map<int, String>? lyrics,
  }) {
    return MusicNote(
      step: step ?? this.step,
      octave: octave ?? this.octave,
      alter: alter ?? this.alter,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      isRest: isRest ?? this.isRest,
      isChordContinuation: isChordContinuation ?? this.isChordContinuation,
      dot: dot ?? this.dot,
      beam: beam ?? this.beam,
      beam2: beam2 ?? this.beam2,
      isTied: isTied ?? this.isTied,
      isTiedToPrevious: isTiedToPrevious ?? this.isTiedToPrevious,
      isPlaceholder: isPlaceholder ?? this.isPlaceholder,
      lyrics: lyrics ?? this.lyrics,
    );
  }
}
