import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

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
class InstrumentProfile {
  final String id;
  final String name;
  final String? icon;
  final String? emoji;

  /// Whether this is a built-in (non-deletable) scheme.
  final bool isBuiltIn;

  /// Whether this was imported from the library (prevents sharing/re-submitting).
  final bool isImported;

  /// Per-note colors keyed by the values in [kNoteKeys].
  final Map<String, Color> colors;

  /// Optional octave-specific overrides, e.g. `{'C5': Color(0xFFE91E63)}`.
  final Map<String, Color> octaveOverrides;

  /// Notes that are hidden for this instrument (e.g. no sharps on a simple recorder).
  final Set<String> hiddenKeys;

  /// Optional tuning overrides, mapping an intended note name to what is actually heard.
  /// E.g. `{'C5': 'B4'}` means when the app expects C5, it should listen for B4.
  final Map<String, String> tuningOverrides;

  const InstrumentProfile({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    required this.colors,
    this.isBuiltIn = false,
    this.isImported = false,
    this.octaveOverrides = const {},
    this.hiddenKeys = const {},
    this.tuningOverrides = const {},
  });

  /// Returns the color for a note given its [step] (C–B), [alter] (-1/0/+1),
  /// and optional [octave].
  Color colorForNote(
    String step,
    double alter, {
    int? octave,
    BuildContext? context,
    Brightness? brightness,
  }) {
    Color? baseColor;

    if (octave != null && octaveOverrides.isNotEmpty) {
      final key = alter == 1
          ? '$step#$octave'
          : alter == -1
              ? '${step}b$octave'
              : '$step$octave';
      if (octaveOverrides.containsKey(key)) baseColor = octaveOverrides[key]!;

      if (baseColor == null && alter == -1) {
        final enharmonic = kFlatToSharp['${step}b'];
        if (enharmonic != null &&
            octaveOverrides.containsKey('$enharmonic$octave')) {
          baseColor = octaveOverrides['$enharmonic$octave']!;
        }
      }
    }

    if (baseColor == null) {
      if (alter == 1) {
        baseColor = colors['$step#'] ?? colors[step];
      } else if (alter == -1) {
        final enharmonic = kFlatToSharp['${step}b'];
        baseColor = colors[enharmonic] ?? colors[step];
      } else {
        baseColor = colors[step];
      }
    }

    final bool isStandard = baseColor == null ||
        baseColor.alpha == 0 ||
        baseColor.value == 0xFF000000 ||
        baseColor.value == 0xFFFFFFFF;

    if (isStandard) {
      final isDark = brightness == Brightness.dark ||
          (context != null && Theme.of(context).brightness == Brightness.dark);
      return isDark ? Colors.white : Colors.black;
    }

    return baseColor;
  }

  InstrumentProfile copyWith({
    String? id,
    String? name,
    String? icon,
    String? emoji,
    Map<String, Color>? colors,
    Map<String, Color>? octaveOverrides,
    Set<String>? hiddenKeys,
    Map<String, String>? tuningOverrides,
    bool? isBuiltIn,
    bool? isImported,
  }) {
    return InstrumentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      colors: colors ?? Map.from(this.colors),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isImported: isImported ?? this.isImported,
      octaveOverrides: octaveOverrides ?? Map.from(this.octaveOverrides),
      hiddenKeys: hiddenKeys ?? Set.from(this.hiddenKeys),
      tuningOverrides: tuningOverrides ?? Map.from(this.tuningOverrides),
    );
  }

  /// Returns a copy of this scheme with the icon/emoji cleared so only one is set.
  InstrumentProfile withIconOnly({String? icon, String? emoji}) {
    return InstrumentProfile(
      id: id,
      name: name,
      icon: icon,
      emoji: emoji,
      colors: colors,
      isBuiltIn: isBuiltIn,
      isImported: isImported,
      octaveOverrides: octaveOverrides,
      hiddenKeys: hiddenKeys,
      tuningOverrides: tuningOverrides,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (icon != null) 'icon': icon,
        if (emoji != null) 'emoji': emoji,
        'colors': colors.map((k, v) => MapEntry(k, v.toARGB32())),
        if (octaveOverrides.isNotEmpty)
          'octaveOverrides':
              octaveOverrides.map((k, v) => MapEntry(k, v.toARGB32())),
        if (hiddenKeys.isNotEmpty) 'hiddenKeys': hiddenKeys.toList(),
        if (tuningOverrides.isNotEmpty) 'tuningOverrides': tuningOverrides,
      };

  factory InstrumentProfile.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawColors = json['colors'] as Map<String, dynamic>? ?? {};
    final rawOverrides =
        json['octaveOverrides'] as Map<String, dynamic>? ?? {};
    final rawDisabled = json['hiddenKeys'] as List<dynamic>? ?? json['disabledKeys'] as List<dynamic>? ?? [];
    final rawTuning = json['tuningOverrides'] as Map<String, dynamic>? ?? {};
    return InstrumentProfile(
      id: (json['id'] as String?) ?? fallbackId ?? const Uuid().v7(),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      emoji: json['emoji'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? false,
      colors: rawColors.map((k, v) => MapEntry(k, Color(v as int))),
      octaveOverrides:
          rawOverrides.map((k, v) => MapEntry(k, Color(v as int))),
      hiddenKeys: rawDisabled.cast<String>().toSet(),
      tuningOverrides: rawTuning.cast<String, String>(),
    );
  }

  static const InstrumentProfile black = InstrumentProfile(
    id: 'builtin_black',
    name: 'Standard',
    emoji: '🎹',
    isBuiltIn: true,
    colors: {},
  );
}
