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

  /// Notes that are disabled for this instrument (e.g. no sharps on a simple recorder).
  final Set<String> disabledKeys;

  /// Optional tuning overrides, mapping an intended note name to what is actually heard.
  /// E.g. `{'C5': 'B4'}` means when the app expects C5, it should listen for B4.
  final Map<String, String> tuningOverrides;

  /// Optional keyboard overrides, mapping a note name to a physical key name.
  /// E.g. `{'C4': 'KeyA'}`.
  final Map<String, String> keyboardOverrides;

  const InstrumentProfile({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    required this.colors,
    this.isBuiltIn = false,
    this.isImported = false,
    this.octaveOverrides = const {},
    this.disabledKeys = const {},
    this.tuningOverrides = const {},
    this.keyboardOverrides = const {},
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
    Set<String>? disabledKeys,
    Map<String, String>? tuningOverrides,
    Map<String, String>? keyboardOverrides,
    bool? isBuiltIn,
    bool? isImported,
  }) {
    // Determine which icon/emoji to use based on which one is provided.
    // If both are provided, we should probably prefer emoji or follow the caller.
    // To support clearing, we can check if they are explicitly passed.
    // For now, we'll stick to the existing pattern but be mindful in the caller.
    return InstrumentProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      colors: colors ?? Map.from(this.colors),
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isImported: isImported ?? this.isImported,
      octaveOverrides: octaveOverrides ?? Map.from(this.octaveOverrides),
      disabledKeys: disabledKeys ?? Set.from(this.disabledKeys),
      tuningOverrides: tuningOverrides ?? Map.from(this.tuningOverrides),
      keyboardOverrides: keyboardOverrides ?? Map.from(this.keyboardOverrides),
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
      disabledKeys: disabledKeys,
      tuningOverrides: tuningOverrides,
      keyboardOverrides: keyboardOverrides,
    );
  }

  /// Returns a merged map of keyboard overrides, falling back to the standard profile.
  Map<String, String> get effectiveKeyboardOverrides {
    if (id == black.id) return keyboardOverrides;
    return {
      ...black.keyboardOverrides,
      ...keyboardOverrides,
    };
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (icon != null) 'icon': icon,
        if (emoji != null) 'emoji': emoji,
        'colors': colors.map((k, v) => MapEntry(k, v.toARGB32())),
        if (octaveOverrides.isNotEmpty)
          'octaveOverrides':
              octaveOverrides.map((k, v) => MapEntry(k, v.toARGB32())),
        if (disabledKeys.isNotEmpty) 'disabledKeys': disabledKeys.toList(),
        if (keyboardOverrides.isNotEmpty) 'keyboardOverrides': keyboardOverrides,
        // Skipped attributes: id, tuningOverrides, isBuiltIn, isImported
      };

  factory InstrumentProfile.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawColors = json['colors'] as Map<String, dynamic>? ?? {};
    final rawOverrides =
        json['octaveOverrides'] as Map<String, dynamic>? ?? {};
    final rawDisabled = json['disabledKeys'] as List<dynamic>? ?? [];
    final rawTuning = json['tuningOverrides'] as Map<String, dynamic>? ?? {};
    final rawKeyboard = json['keyboardOverrides'] as Map<String, dynamic>? ?? {};
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
      disabledKeys: rawDisabled.cast<String>().toSet(),
      tuningOverrides: rawTuning.cast<String, String>(),
      keyboardOverrides: rawKeyboard.cast<String, String>(),
    );
  }

  static const InstrumentProfile black = InstrumentProfile(
    id: 'builtin_black',
    name: 'Standard',
    emoji: '🎹',
    isBuiltIn: true,
    colors: {},
    keyboardOverrides: {
      'C4': 'KeyA',
      'C#4': 'KeyW',
      'D4': 'KeyS',
      'D#4': 'KeyE',
      'E4': 'KeyD',
      'F4': 'KeyF',
      'F#4': 'KeyT',
      'G4': 'KeyG',
      'G#4': 'KeyY',
      'A4': 'KeyH',
      'A#4': 'KeyU',
      'B4': 'KeyJ',
      'C5': 'Shift+KeyA',
      'C#5': 'Shift+KeyW',
      'D5': 'Shift+KeyS',
      'D#5': 'Shift+KeyE',
      'E5': 'Shift+KeyD',
      'F5': 'Shift+KeyF',
      'F#5': 'Shift+KeyT',
      'G5': 'Shift+KeyG',
      'G#5': 'Shift+KeyY',
      'A5': 'Shift+KeyH',
      'A#5': 'Shift+KeyU',
      'B5': 'Shift+KeyJ',
      'C6': 'Alt+KeyA',
      'D6': 'Alt+KeyS',
      'E6': 'Alt+KeyD',
    },
  );
}
