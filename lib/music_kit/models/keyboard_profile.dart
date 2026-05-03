import 'package:uuid/uuid.dart';

class KeyboardProfile {
  final String id;
  final String name;
  final String? icon;
  final String? emoji;
  final bool isBuiltIn;
  final bool isImported;

  /// Optional keyboard overrides, mapping a note name to a physical key name.
  /// E.g. `{'C4': 'KeyA'}`.
  final Map<String, String> keyboardOverrides;

  /// Optional mapping from note names to recorded sound file paths.
  final Map<String, String> noteSounds;

  const KeyboardProfile({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    this.isBuiltIn = false,
    this.isImported = false,
    this.keyboardOverrides = const {},
    this.noteSounds = const {},
  });

  KeyboardProfile copyWith({
    String? id,
    String? name,
    String? icon,
    String? emoji,
    Map<String, String>? keyboardOverrides,
    Map<String, String>? noteSounds,
    bool? isBuiltIn,
    bool? isImported,
  }) {
    return KeyboardProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isImported: isImported ?? this.isImported,
      keyboardOverrides: keyboardOverrides ?? Map.from(this.keyboardOverrides),
      noteSounds: noteSounds ?? Map.from(this.noteSounds),
    );
  }

  /// Gets a sample path for a note, with fallback to C4 if the specific octave doesn't exist.
  /// Also falls back to the standard profile's defaults if not found in this profile.
  String? getSamplePath(String noteName) {
    // Normalize to sharps for consistent lookup (Db -> C#)
    final normalized = _normalizeToSharps(noteName);
    
    // 1. Check for exact match (e.g., "C#5")
    final exactPath = noteSounds[normalized];
    if (exactPath != null && exactPath.isNotEmpty) return exactPath;

    final step = normalized.replaceAll(RegExp(r'\d'), '');
    
    // 2. Check for step-only "default" recording (e.g., "C#" without octave)
    final stepOnlyPath = noteSounds[step];
    if (stepOnlyPath != null && stepOnlyPath.isNotEmpty) return stepOnlyPath;
    
    // 3. Check for octave 4 fallback (e.g., "C#4")
    final fallbackNote = '${step}4';
    final fallbackPath = noteSounds[fallbackNote];
    if (fallbackPath != null && fallbackPath.isNotEmpty) return fallbackPath;

    // 4. Check standard profile defaults if this isn't the standard profile
    if (id != KeyboardProfile.standard.id) {
      final standardExact = KeyboardProfile.standard.noteSounds[normalized];
      if (standardExact != null && standardExact.isNotEmpty) return standardExact;
      
      final standardStepOnly = KeyboardProfile.standard.noteSounds[step];
      if (standardStepOnly != null && standardStepOnly.isNotEmpty) return standardStepOnly;
      
      final standardFallback = KeyboardProfile.standard.noteSounds[fallbackNote];
      if (standardFallback != null && standardFallback.isNotEmpty) return standardFallback;
    }

    return null;
  }

  /// Gets a keyboard mapping for a note, with fallback to the standard profile if not found.
  String? getKeyMapping(String noteName) {
    // Normalize to sharps for consistent lookup
    final normalized = _normalizeToSharps(noteName);
    
    final mapping = keyboardOverrides[normalized];
    if (mapping != null && mapping.isNotEmpty) return mapping;

    // Check standard profile defaults if this isn't the standard profile
    if (id != KeyboardProfile.standard.id) {
      final standardMapping = KeyboardProfile.standard.keyboardOverrides[normalized];
      if (standardMapping != null && standardMapping.isNotEmpty) return standardMapping;
    }

    return null;
  }

  /// Normalizes flats to sharps (Db -> C#)
  static String _normalizeToSharps(String note) {
    return note
        .replaceAll('Db', 'C#')
        .replaceAll('Eb', 'D#')
        .replaceAll('Gb', 'F#')
        .replaceAll('Ab', 'G#')
        .replaceAll('Bb', 'A#');
  }

  /// Gets all keyboard mappings with standard profile fallbacks merged in.
  Map<String, String> getAllKeyMappings() {
    if (id == KeyboardProfile.standard.id) {
      return Map.from(keyboardOverrides);
    }
    // Start with standard mappings, then override with custom ones
    final merged = Map<String, String>.from(KeyboardProfile.standard.keyboardOverrides);
    merged.addAll(keyboardOverrides);
    return merged;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        if (emoji != null) 'emoji': emoji,
        if (keyboardOverrides.isNotEmpty) 'keyboardOverrides': keyboardOverrides,
        if (noteSounds.isNotEmpty) 'noteSounds': noteSounds,
      };

  factory KeyboardProfile.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawKeyboard = json['keyboardOverrides'] as Map<String, dynamic>? ?? {};
    final rawSounds = json['noteSounds'] as Map<String, dynamic>? ?? {};
    return KeyboardProfile(
      id: (json['id'] as String?) ?? fallbackId ?? const Uuid().v7(),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      emoji: json['emoji'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? false,
      keyboardOverrides: rawKeyboard.cast<String, String>(),
      noteSounds: rawSounds.cast<String, String>(),
    );
  }

  static const KeyboardProfile standard = KeyboardProfile(
    id: 'builtin_keyboard_standard',
    name: 'Standard QWERTY',
    emoji: '⌨️',
    isBuiltIn: true,
    keyboardOverrides: {
      'C4': 'KeyA', 'C#4': 'KeyW', 'D4': 'KeyS', 'D#4': 'KeyE', 'E4': 'KeyD',
      'F4': 'KeyF', 'F#4': 'KeyT', 'G4': 'KeyG', 'G#4': 'KeyY', 'A4': 'KeyH',
      'A#4': 'KeyU', 'B4': 'KeyJ',
      'C5': 'Shift+KeyA', 'C#5': 'Shift+KeyW', 'D5': 'Shift+KeyS', 'D#5': 'Shift+KeyE',
      'E5': 'Shift+KeyD', 'F5': 'Shift+KeyF', 'F#5': 'Shift+KeyT', 'G5': 'Shift+KeyG',
      'G#5': 'Shift+KeyY', 'A5': 'Shift+KeyH', 'A#5': 'Shift+KeyU', 'B5': 'Shift+KeyJ',
      'C6': 'Alt+KeyA', 'D6': 'Alt+KeyS', 'E6': 'Alt+KeyD',
    },
  );
}
