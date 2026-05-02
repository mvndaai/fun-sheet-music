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
  });

  bool get isDefault => localPath?.contains('/defaults/') ?? false;
  bool get isHidden => localPath?.contains('/hidden_defaults/') ?? false;
  bool get isTesting => localPath?.contains('/testing/') ?? false;
  bool get isShared => localPath?.contains('/shared_by_users/') ?? false;

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
    );
  }

  /// Returns all playable notes (non-rest, non-chord-continuation) in order.
  List<MusicNote> get allNotes {
    return measures.expand((m) => m.playableNotes).toList();
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
      );
}
