import 'package:uuid/uuid.dart';
import '../utils/note_map_lookup.dart';

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

  /// Optional keyboard shortcuts for the music editor.
  /// E.g. `{'pitchUp': 'ArrowUp'}`.
  final Map<String, String> editorShortcuts;

  const KeyboardProfile({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    this.isBuiltIn = false,
    this.isImported = false,
    this.keyboardOverrides = const {},
    this.editorShortcuts = const {},
  });

  KeyboardProfile copyWith({
    String? id,
    String? name,
    String? icon,
    String? emoji,
    Map<String, String>? keyboardOverrides,
    Map<String, String>? editorShortcuts,
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
      editorShortcuts: editorShortcuts ?? Map.from(this.editorShortcuts),
    );
  }

  /// Gets a keyboard mapping for a note.
  /// Looks for exact octave match first, then step-only "default", then standard profile.
  String? getKeyMapping(String noteName) {
    return NoteMapLookup.lookup<String>(
      noteName: noteName,
      primaryMap: keyboardOverrides,
      fallbackMap: id != KeyboardProfile.standard.id 
          ? KeyboardProfile.standard.keyboardOverrides 
          : null,
      isEmpty: (value) => value.isEmpty,
    );
  }

  /// Gets an editor shortcut for an action.
  String? getEditorShortcut(String action) {
    return editorShortcuts[action] ?? KeyboardProfile.standard.editorShortcuts[action];
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
        if (editorShortcuts.isNotEmpty) 'editorShortcuts': editorShortcuts,
      };

  factory KeyboardProfile.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawKeyboard = json['keyboardOverrides'] as Map<String, dynamic>? ?? {};
    final rawEditor = json['editorShortcuts'] as Map<String, dynamic>? ?? {};
    return KeyboardProfile(
      id: (json['id'] as String?) ?? fallbackId ?? const Uuid().v7(),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      emoji: json['emoji'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? false,
      keyboardOverrides: rawKeyboard.cast<String, String>(),
      editorShortcuts: rawEditor.cast<String, String>(),
    );
  }

  static const KeyboardProfile simple = KeyboardProfile(
    id: 'builtin_keyboard_simple',
    name: 'Simple QWERTY (Any Octave)',
    emoji: '🎹',
    isBuiltIn: true,
    keyboardOverrides: {
      'C': 'A', 'C#': 'W', 'D': 'S', 'D#': 'E', 'E': 'D',
      'F': 'F', 'F#': 'T', 'G': 'G', 'G#': 'Y', 'A': 'H',
      'A#': 'U', 'B': 'J',
    },
    editorShortcuts: {
      'pitchUp': 'ArrowUp',
      'pitchDown': 'ArrowDown',
      'durationUp': 'ArrowRight',
      'durationDown': 'ArrowLeft',
      'toggleBeam': 'B',
      'addNote': 'Space',
      'deleteNote': 'Backspace',
      'undo': 'Control+Z',
      'redo': 'Control+Y',
      'print': 'Control+P',
      'save': 'Control+S',
      'toggleListening': 'L',
      'prevMeasure': 'BracketLeft',
      'nextMeasure': 'BracketRight',
      'togglePlayback': 'Control+Space',
    },
  );

  static const KeyboardProfile standard = KeyboardProfile(
    id: 'builtin_keyboard_standard',
    name: 'Standard QWERTY',
    emoji: '⌨️',
    isBuiltIn: true,
    keyboardOverrides: {
      'C4': 'A', 'C#4': 'W', 'D4': 'S', 'D#4': 'E', 'E4': 'D',
      'F4': 'F', 'F#4': 'T', 'G4': 'G', 'G#4': 'Y', 'A4': 'H',
      'A#4': 'U', 'B4': 'J',
      'C5': 'Shift+A', 'C#5': 'Shift+W', 'D5': 'Shift+S', 'D#5': 'Shift+E',
      'E5': 'Shift+D', 'F5': 'Shift+F', 'F#5': 'Shift+T', 'G5': 'Shift+G',
      'G#5': 'Shift+Y', 'A5': 'Shift+H', 'A#5': 'Shift+U', 'B5': 'Shift+J',
      'C6': 'Alt+A', 'D6': 'Alt+S', 'E6': 'Alt+D',
    },
    editorShortcuts: {
      'pitchUp': 'ArrowUp',
      'pitchDown': 'ArrowDown',
      'durationUp': 'ArrowRight',
      'durationDown': 'ArrowLeft',
      'toggleBeam': 'B',
      'addNote': 'Space',
      'deleteNote': 'Backspace',
      'undo': 'Control+Z',
      'redo': 'Control+Y',
      'print': 'Control+P',
      'save': 'Control+S',
      'toggleListening': 'L',
      'prevMeasure': 'BracketLeft',
      'nextMeasure': 'BracketRight',
      'togglePlayback': 'Control+Space',
    },
  );
}
