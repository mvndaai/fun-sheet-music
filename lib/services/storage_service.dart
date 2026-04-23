import '../music_kit/models/song.dart';
import 'database.dart';
import 'package:drift/drift.dart';

/// Manages local persistence of song metadata and tags using Drift (SQLite).
class StorageService {
  final AppDatabase _db;

  StorageService({required AppDatabase db}) : _db = db;

  /// Returns all stored songs (metadata only).
  Future<List<Song>> getAllSongs() async {
    final rows = await _db.getAllSongs();
    return rows.map((row) => _mapToSong(row)).toList();
  }

  /// Saves a song's metadata and XML content.
  Future<void> saveSong(Song song, {String? xmlContent}) async {
    await _db.insertSong(SongDbEntity(
      id: song.id,
      title: song.title,
      composer: song.composer,
      tags: song.tags,
      library: song.library,
      localPath: song.localPath,
      sourceUrl: song.sourceUrl,
      createdAt: song.createdAt,
      xmlContent: xmlContent ?? '',
    ));
  }

  /// Deletes a song by ID.
  Future<void> deleteSong(String id) async {
    await _db.deleteSong(id);
  }

  /// Returns the stored MusicXML content for a song, or null if not stored.
  Future<String?> getXmlContent(String id) async {
    final row = await _db.getSongById(id);
    return row?.xmlContent;
  }

  /// Updates the tags for a specific song.
  Future<void> updateTags(String songId, List<String> tags) async {
    await _db.updateSongTags(songId, tags);
  }

  Song _mapToSong(SongDbEntity row) {
    return Song(
      id: row.id,
      title: row.title,
      composer: row.composer,
      measures: [], // Measures are re-parsed from XML when needed
      tags: row.tags,
      library: row.library,
      localPath: row.localPath,
      sourceUrl: row.sourceUrl,
      createdAt: row.createdAt,
    );
  }
}
