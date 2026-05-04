import 'package:uuid/uuid.dart';
import '../utils/note_map_lookup.dart';

class SoundProfile {
  final String id;
  final String name;
  final String? icon;
  final String? emoji;
  final bool isBuiltIn;
  final bool isImported;

  /// Optional mapping from note names to recorded sound file paths.
  /// E.g. `{'C4': 'path/to/c4.wav'}`.
  final Map<String, String> noteSounds;

  const SoundProfile({
    required this.id,
    required this.name,
    this.icon,
    this.emoji,
    this.isBuiltIn = false,
    this.isImported = false,
    this.noteSounds = const {},
  });

  SoundProfile copyWith({
    String? id,
    String? name,
    String? icon,
    String? emoji,
    Map<String, String>? noteSounds,
    bool? isBuiltIn,
    bool? isImported,
  }) {
    return SoundProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      emoji: emoji ?? this.emoji,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
      isImported: isImported ?? this.isImported,
      noteSounds: noteSounds ?? Map.from(this.noteSounds),
    );
  }

  /// Gets a sample path for a note.
  String? getSamplePath(String noteName) {
    return NoteMapLookup.lookup<String>(
      noteName: noteName,
      primaryMap: noteSounds,
      fallbackMap: id != SoundProfile.standard.id 
          ? SoundProfile.standard.noteSounds 
          : null,
      isEmpty: (value) => value.isEmpty,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (icon != null) 'icon': icon,
        if (emoji != null) 'emoji': emoji,
        if (noteSounds.isNotEmpty) 'noteSounds': noteSounds,
      };

  factory SoundProfile.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    final rawSounds = json['noteSounds'] as Map<String, dynamic>? ?? {};
    return SoundProfile(
      id: (json['id'] as String?) ?? fallbackId ?? const Uuid().v7(),
      name: json['name'] as String,
      icon: json['icon'] as String?,
      emoji: json['emoji'] as String?,
      isBuiltIn: json['isBuiltIn'] as bool? ?? false,
      isImported: json['isImported'] as bool? ?? false,
      noteSounds: rawSounds.cast<String, String>(),
    );
  }

  static const SoundProfile standard = SoundProfile(
    id: 'builtin_sound_standard',
    name: 'Default Synth',
    emoji: '🎹',
    isBuiltIn: true,
    noteSounds: {},
  );
}
