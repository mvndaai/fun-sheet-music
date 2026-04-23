import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/song.dart';
import '../services/musicxml_parser.dart';
import '../services/storage_service.dart';
import '../services/cloud_service.dart';

/// Manages the list of songs and loading/saving operations.
class SongProvider extends ChangeNotifier {
  final StorageService _storage = StorageService();
  final CloudService _cloud = CloudService();
  final Uuid _uuid = const Uuid();

  List<Song> _songs = [];
  bool _loading = false;
  String? _error;
  String _selectedTag = '';

  List<Song> get songs => _songs;
  bool get loading => _loading;
  String? get error => _error;
  String get selectedTag => _selectedTag;

  List<Song> get filteredSongs {
    if (_selectedTag.isEmpty) return _songs;
    return _songs.where((s) => s.tags.contains(_selectedTag)).toList();
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final song in _songs) {
      tags.addAll(song.tags);
    }
    return tags.toList()..sort();
  }

  Future<void> loadSongs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _songs = await _storage.getAllSongs();
      // Load sample songs on first run (empty library)
      if (_songs.isEmpty) {
        await _loadSampleSongs();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads sample songs from the assets folder into the library.
  Future<void> _loadSampleSongs() async {
    final sampleSongs = [
      'assets/sample_songs/twinkle_twinkle.xml',
      'assets/sample_songs/mary_had_a_little_lamb.xml',
      'assets/sample_songs/row_row_row_your_boat.xml',
      'assets/sample_songs/concerning_hobbits.xml',
      'assets/sample_songs/formatting.xml',
    ];

    for (final assetPath in sampleSongs) {
      try {
        final xmlContent = await rootBundle.loadString(assetPath);
        await addSongFromXml(
          xmlContent,
          tags: ['Sample', 'Kids Songs'],
        );
      } catch (e) {
        debugPrint('Failed to load sample song $assetPath: $e');
      }
    }
  }

  void selectTag(String tag) {
    _selectedTag = tag;
    notifyListeners();
  }

  /// Adds a song from raw MusicXML content.
  Future<Song?> addSongFromXml(
    String xmlContent, {
    List<String> tags = const [],
    String? sourceUrl,
  }) async {
    try {
      final id = _uuid.v7();
      final song = MusicXmlParser.parse(
        xmlContent,
        id: id,
        tags: tags,
        sourceUrl: sourceUrl,
      );
      await _storage.saveSong(song, xmlContent: xmlContent);
      _songs.add(song);
      notifyListeners();
      return song;
    } catch (e) {
      _error = 'Failed to parse MusicXML: $e';
      notifyListeners();
      return null;
    }
  }

  /// Downloads and adds a song from a URL.
  Future<Song?> addSongFromUrl(String url, {List<String> tags = const []}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      // Convert gs:// URLs to https://
      final resolvedUrl = CloudService.isGcsUrl(url) && url.startsWith('gs://')
          ? CloudService.gsToHttps(url)
          : url;
      final xmlContent = await _cloud.fetchXml(resolvedUrl);
      return await addSongFromXml(xmlContent, tags: tags, sourceUrl: url);
    } catch (e) {
      _error = 'Failed to download song: $e';
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads full MusicXML (re-parses) for a stored song.
  Future<Song?> loadFullSong(String songId) async {
    final meta = _songs.firstWhere(
      (s) => s.id == songId,
      orElse: () => Song(
        id: '',
        title: '',
        measures: [],
        createdAt: DateTime.now(),
      ),
    );
    if (meta.id.isEmpty) return null;

    final xmlContent = await _storage.getXmlContent(songId);
    if (xmlContent == null) return meta;

    try {
      return MusicXmlParser.parse(
        xmlContent,
        id: meta.id,
        tags: meta.tags,
        localPath: meta.localPath,
        sourceUrl: meta.sourceUrl,
        createdAt: meta.createdAt,
      );
    } catch (e) {
      _error = 'Failed to load song: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateTags(String songId, List<String> tags) async {
    await _storage.updateTags(songId, tags);
    final index = _songs.indexWhere((s) => s.id == songId);
    if (index >= 0) {
      _songs[index] = _songs[index].copyWith(tags: tags);
      notifyListeners();
    }
  }

  Future<void> deleteSong(String songId) async {
    await _storage.deleteSong(songId);
    _songs.removeWhere((s) => s.id == songId);
    notifyListeners();
  }
}
