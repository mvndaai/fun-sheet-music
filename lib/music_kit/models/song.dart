import 'measure.dart';
import 'music_note.dart';

/// Represents a parsed song from a MusicXML file.
class Song {
  final String id;
  final String title;
  final String icon;
  final String composer;
  final String arranger;
  final List<Measure> measures;
  final List<String> tags;
  final String library;
  final String? localPath; // path to local MusicXML file
  final String? sourceUrl; // original URL if downloaded from cloud
  final DateTime createdAt;
  final Map<String, List<String>> lyricsVariables; // Deprecated: use lyricsVariableSets
  final List<Map<String, String>> lyricsVariableSets;
  final Map<String, String> defaultLyricsVariables;

  const Song({
    required this.id,
    required this.title,
    required this.measures,
    this.icon = '',
    this.composer = '',
    this.arranger = '',
    this.tags = const [],
    this.library = 'Default',
    this.localPath,
    this.sourceUrl,
    required this.createdAt,
    this.lyricsVariables = const {},
    this.lyricsVariableSets = const [],
    this.defaultLyricsVariables = const {},
  });

  bool get isAutoAdd => localPath?.contains('/auto-add/') ?? false;
  bool get isDefaultLibrary => localPath?.contains('/defaults/') ?? false;
  bool get isTesting => localPath?.contains('/testing/') ?? false;
  bool get isCommunity => library == 'Community';

  Song copyWith({
    String? id,
    String? title,
    String? icon,
    String? composer,
    String? arranger,
    List<Measure>? measures,
    List<String>? tags,
    String? library,
    String? localPath,
    String? sourceUrl,
    DateTime? createdAt,
    Map<String, List<String>>? lyricsVariables,
    List<Map<String, String>>? lyricsVariableSets,
    Map<String, String>? defaultLyricsVariables,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      icon: icon ?? this.icon,
      composer: composer ?? this.composer,
      arranger: arranger ?? this.arranger,
      measures: measures ?? this.measures,
      tags: tags ?? this.tags,
      library: library ?? this.library,
      localPath: localPath ?? this.localPath,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      createdAt: createdAt ?? this.createdAt,
      lyricsVariables: lyricsVariables ?? this.lyricsVariables,
      lyricsVariableSets: lyricsVariableSets ?? this.lyricsVariableSets,
      defaultLyricsVariables: defaultLyricsVariables ?? this.defaultLyricsVariables,
    );
  }

  /// Returns the total number of verses based on the notes and variable sets.
  int get totalVerses {
    int maxVerse = 1;
    for (final m in measures) {
      for (final n in m.notes) {
        for (final v in n.lyrics.keys) {
          if (v < 99 && v > maxVerse) maxVerse = v;
        }
      }
    }
    
    // Check variable sets
    if (lyricsVariableSets.length > maxVerse) {
      maxVerse = lyricsVariableSets.length;
    }
    
    // Legacy check
    for (final values in lyricsVariables.values) {
      if (values.length > maxVerse) maxVerse = values.length;
    }
    
    return maxVerse;
  }

  /// Returns all playable notes (non-rest, non-chord-continuation) in order.
  List<MusicNote> get allNotes {
    return measures.expand((m) => m.playableNotes).toList();
  }

  /// Returns all notes including rests for playback.
  List<MusicNote> get playbackNotes {
    return measures.expand((m) => m.allDisplayNotes).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'icon': icon,
        'composer': composer,
        'arranger': arranger,
        'tags': tags,
        'library': library,
        'localPath': localPath,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.toIso8601String(),
        'lyricsVariables': lyricsVariables,
        'lyricsVariableSets': lyricsVariableSets,
        'defaultLyricsVariables': defaultLyricsVariables,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        icon: (json['icon'] as String?) ?? '',
        composer: (json['composer'] as String?) ?? '',
        arranger: (json['arranger'] as String?) ?? '',
        measures: const [], // measures are re-parsed from file
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        library: (json['library'] as String?) ?? 'Default',
        localPath: json['localPath'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        lyricsVariables: (json['lyricsVariables'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, (v as List).map((e) => e.toString()).toList()),
            ) ??
            const {},
        lyricsVariableSets: (json['lyricsVariableSets'] as List<dynamic>?)?.map(
              (e) => (e as Map<String, dynamic>).map((k, v) => MapEntry(k, v.toString())),
            ).toList() ??
            const [],
        defaultLyricsVariables: (json['defaultLyricsVariables'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(k, v.toString()),
            ) ??
            const {},
      );
}
