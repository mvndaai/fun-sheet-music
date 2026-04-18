import 'measure.dart';
import 'music_note.dart';

/// Represents a parsed song from a MusicXML file.
class Song {
  final String id;
  final String title;
  final String composer;
  final List<Measure> measures;
  final List<String> tags;
  final String? localPath; // path to local MusicXML file
  final String? sourceUrl; // original URL if downloaded from cloud
  final DateTime createdAt;

  const Song({
    required this.id,
    required this.title,
    required this.measures,
    this.composer = '',
    this.tags = const [],
    this.localPath,
    this.sourceUrl,
    required this.createdAt,
  });

  Song copyWith({
    String? id,
    String? title,
    String? composer,
    List<Measure>? measures,
    List<String>? tags,
    String? localPath,
    String? sourceUrl,
    DateTime? createdAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      composer: composer ?? this.composer,
      measures: measures ?? this.measures,
      tags: tags ?? this.tags,
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
        'composer': composer,
        'tags': tags,
        'localPath': localPath,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'] as String,
        title: json['title'] as String,
        composer: (json['composer'] as String?) ?? '',
        measures: const [], // measures are re-parsed from file
        tags: (json['tags'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        localPath: json['localPath'] as String?,
        sourceUrl: json['sourceUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
