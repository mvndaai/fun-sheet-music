import 'package:flutter/material.dart';

/// The canonical 12 chromatic note keys used as keys in a color scheme.
const List<String> kNoteKeys = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
];

/// Flat-to-sharp equivalents for enharmonic lookup.
const Map<String, String> kFlatToSharp = {
  'Db': 'C#',
  'Eb': 'D#',
  'Gb': 'F#',
  'Ab': 'G#',
  'Bb': 'A#',
};

/// A named mapping from each of the 12 chromatic notes to a display [Color].
///
/// Optionally, [octaveOverrides] can hold colors keyed by note+octave strings
/// such as `'C5'` or `'C#4'`, which take precedence over [colors] when an
/// octave is known.  This lets the same pitch class (e.g. C) appear in
/// different colors on different octaves (e.g. low-C purple, high-C pink).
class InstrumentColorScheme {
  final String id;
  final String name;

  /// Whether this is a built-in (non-deletable) scheme.
  final bool isBuiltIn;

  /// Per-note colors keyed by the values in [kNoteKeys].
  final Map<String, Color> colors;

  /// Optional octave-specific overrides, e.g. `{'C5': Color(0xFFE91E63)}`.
  /// Keys are `step + octave` (or `step# + octave` for sharps).
  final Map<String, Color> octaveOverrides;

  const InstrumentColorScheme({
    required this.id,
    required this.name,
    required this.colors,
    this.isBuiltIn = false,
    this.octaveOverrides = const {},
  });

  /// Returns the color for a note given its [step] (C–B), [alter] (-1/0/+1),
  /// and optional [octave].  Octave-specific overrides are checked first.
  Color colorForNote(String step, double alter, {int? octave}) {
    if (octave != null && octaveOverrides.isNotEmpty) {
      final key = alter == 1
          ? '$step#$octave'
          : alter == -1
              ? '${step}b$octave'
              : '$step$octave';
      if (octaveOverrides.containsKey(key)) return octaveOverrides[key]!;

      // Also try the enharmonic sharp form for flat notes.
      if (alter == -1) {
        final enharmonic = kFlatToSharp['${step}b'];
        if (enharmonic != null &&
            octaveOverrides.containsKey('$enharmonic$octave')) {
          return octaveOverrides['$enharmonic$octave']!;
        }
      }
    }

    if (alter == 1) {
      return colors['$step#'] ?? colors[step] ?? Colors.grey;
    } else if (alter == -1) {
      final enharmonic = kFlatToSharp['${step}b'];
      return colors[enharmonic] ?? colors[step] ?? Colors.grey;
    }
    return colors[step] ?? Colors.grey;
  }

  /// Creates a copy with optionally updated fields.
  InstrumentColorScheme copyWith({
    String? name,
    Map<String, Color>? colors,
    Map<String, Color>? octaveOverrides,
  }) {
    return InstrumentColorScheme(
      id: id,
      name: name ?? this.name,
      colors: colors ?? Map.from(this.colors),
      isBuiltIn: isBuiltIn,
      octaveOverrides: octaveOverrides ?? Map.from(this.octaveOverrides),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colors': colors.map((k, v) => MapEntry(k, v.value)),
        if (octaveOverrides.isNotEmpty)
          'octaveOverrides':
              octaveOverrides.map((k, v) => MapEntry(k, v.value)),
      };

  factory InstrumentColorScheme.fromJson(Map<String, dynamic> json) {
    final raw = json['colors'] as Map<String, dynamic>;
    final rawOverrides =
        json['octaveOverrides'] as Map<String, dynamic>? ?? {};
    return InstrumentColorScheme(
      id: json['id'] as String,
      name: json['name'] as String,
      colors: raw.map((k, v) => MapEntry(k, Color(v as int))),
      octaveOverrides:
          rawOverrides.map((k, v) => MapEntry(k, Color(v as int))),
    );
  }

  // ── Built-in schemes ──────────────────────────────────────────────────────

  /// Xylophone with the traditional 8-bar diatonic palette:
  /// C=purple, D=blue, E=green, F=lime, G=yellow, A=orange, B=red, C(high)=pink.
  ///
  /// The high C is modelled as octave overrides for C5 and C6 so the pink
  /// colour is applied regardless of which octave range the instrument uses.
  static const InstrumentColorScheme myXylophone = InstrumentColorScheme(
    id: 'builtin_my_xylophone',
    name: 'My Xylophone',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFF9C27B0),  // purple
      'C#': Color(0xFF7B1FA2),
      'D': Color(0xFF1E88E5),  // blue
      'D#': Color(0xFF1565C0),
      'E': Color(0xFF43A047),  // green
      'F': Color(0xFF8BC34A),  // lime green
      'F#': Color(0xFF558B2F),
      'G': Color(0xFFFDD835),  // yellow
      'G#': Color(0xFFF9A825),
      'A': Color(0xFFF57C00),  // orange
      'A#': Color(0xFFE65100),
      'B': Color(0xFFE53935),  // red
    },
    octaveOverrides: {
      'C5': Color(0xFFE91E63),  // pink – high C on an alto xylophone (C4–C5)
      'C6': Color(0xFFE91E63),  // pink – high C on a soprano xylophone (C5–C6)
    },
  );

  /// Default xylophone palette (red → orange → yellow → green → teal → blue → purple).
  static const InstrumentColorScheme defaultXylophone = InstrumentColorScheme(
    id: 'builtin_default',
    name: 'Default Xylophone',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFFE53935),
      'C#': Color(0xFFD81B60),
      'D': Color(0xFFF57C00),
      'D#': Color(0xFFE65100),
      'E': Color(0xFFFDD835),
      'F': Color(0xFF43A047),
      'F#': Color(0xFF2E7D32),
      'G': Color(0xFF00ACC1),
      'G#': Color(0xFF00695C),
      'A': Color(0xFF1E88E5),
      'A#': Color(0xFF1565C0),
      'B': Color(0xFF8E24AA),
    },
  );

  /// Smooth rainbow gradient across all 12 chromatic steps.
  static const InstrumentColorScheme rainbow = InstrumentColorScheme(
    id: 'builtin_rainbow',
    name: 'Rainbow',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFFFF1744),
      'C#': Color(0xFFFF6D00),
      'D': Color(0xFFFFAB00),
      'D#': Color(0xFFFFEA00),
      'E': Color(0xFF76FF03),
      'F': Color(0xFF00E676),
      'F#': Color(0xFF1DE9B6),
      'G': Color(0xFF00B0FF),
      'G#': Color(0xFF2979FF),
      'A': Color(0xFF651FFF),
      'A#': Color(0xFFD500F9),
      'B': Color(0xFFFF1744),
    },
  );

  /// Soft pastel tones, easy on the eyes.
  static const InstrumentColorScheme pastel = InstrumentColorScheme(
    id: 'builtin_pastel',
    name: 'Pastel',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFFFF9AA2),
      'C#': Color(0xFFFFB7B2),
      'D': Color(0xFFFFDAC1),
      'D#': Color(0xFFE2F0CB),
      'E': Color(0xFFB5EAD7),
      'F': Color(0xFF9BE7E0),
      'F#': Color(0xFFC7CEEA),
      'G': Color(0xFFAEC6CF),
      'G#': Color(0xFFB5B9FF),
      'A': Color(0xFFF9D0C4),
      'A#': Color(0xFFD4F0F0),
      'B': Color(0xFFE8D5C4),
    },
  );

  /// Greyscale – useful for monochrome printing.
  static const InstrumentColorScheme monochrome = InstrumentColorScheme(
    id: 'builtin_mono',
    name: 'Monochrome',
    isBuiltIn: true,
    colors: {
      'C': Color(0xFF212121),
      'C#': Color(0xFF424242),
      'D': Color(0xFF616161),
      'D#': Color(0xFF757575),
      'E': Color(0xFF9E9E9E),
      'F': Color(0xFFBDBDBD),
      'F#': Color(0xFFE0E0E0),
      'G': Color(0xFF757575),
      'G#': Color(0xFF616161),
      'A': Color(0xFF424242),
      'A#': Color(0xFF212121),
      'B': Color(0xFF9E9E9E),
    },
  );

  static const List<InstrumentColorScheme> builtIns = [
    myXylophone,
    defaultXylophone,
    rainbow,
    pastel,
    monochrome,
  ];
}
