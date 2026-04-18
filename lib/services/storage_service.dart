import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song.dart';

/// Manages local persistence of song metadata and tags.
///
/// Song metadata (title, composer, tags, paths) is stored in SharedPreferences.
/// The actual MusicXML content is stored as a separate preference entry.
class StorageService {
  static const String _songsKey = 'songs_metadata';
  static const String _xmlPrefix = 'song_xml_';

  late SharedPreferences _prefs;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      _prefs = await SharedPreferences.getInstance();
      _initialized = true;
    }
  }

  /// Returns all stored songs (metadata only; measures are empty until re-parsed).
  Future<List<Song>> getAllSongs() async {
    await _ensureInitialized();
    final raw = _prefs.getString(_songsKey);
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => Song.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Saves a song's metadata and optionally its XML content.
  Future<void> saveSong(Song song, {String? xmlContent}) async {
    await _ensureInitialized();
    final songs = await getAllSongs();
    final index = songs.indexWhere((s) => s.id == song.id);
    if (index >= 0) {
      songs[index] = song;
    } else {
      songs.add(song);
    }
    await _prefs.setString(_songsKey, jsonEncode(songs.map((s) => s.toJson()).toList()));
    if (xmlContent != null) {
      await _prefs.setString('$_xmlPrefix${song.id}', xmlContent);
    }
  }

  /// Deletes a song by ID.
  Future<void> deleteSong(String id) async {
    await _ensureInitialized();
    final songs = await getAllSongs();
    songs.removeWhere((s) => s.id == id);
    await _prefs.setString(_songsKey, jsonEncode(songs.map((s) => s.toJson()).toList()));
    await _prefs.remove('$_xmlPrefix$id');
  }

  /// Returns the stored MusicXML content for a song, or null if not stored.
  Future<String?> getXmlContent(String id) async {
    await _ensureInitialized();
    return _prefs.getString('$_xmlPrefix$id');
  }

  /// Returns all unique tags currently in use across all songs.
  Future<List<String>> getAllTags() async {
    final songs = await getAllSongs();
    final tags = <String>{};
    for (final song in songs) {
      tags.addAll(song.tags);
    }
    final sorted = tags.toList()..sort();
    return sorted;
  }

  /// Updates the tags for a specific song.
  Future<void> updateTags(String songId, List<String> tags) async {
    await _ensureInitialized();
    final songs = await getAllSongs();
    final index = songs.indexWhere((s) => s.id == songId);
    if (index < 0) return;
    final updated = songs[index].copyWith(tags: tags);
    await saveSong(updated);
  }
}
