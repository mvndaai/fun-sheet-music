import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/song.dart';
import '../services/musicxml_parser.dart';
import '../services/storage_service.dart';
import '../services/cloud_service.dart';
import '../config/app_config.dart';

/// Manages the list of songs and loading/saving operations.
class SongProvider extends ChangeNotifier {
  final StorageService _storage;
  final CloudService _cloud;
  final Uuid _uuid = const Uuid();

  SongProvider({
    required StorageService storage,
    CloudService? cloud,
  })  : _storage = storage,
        _cloud = cloud ?? CloudService();

  List<Song> _songs = [];
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  final Set<String> _selectedTags = {};
  final Set<String> _selectedLibraries = {AppConfig.appName}; // TODO add a second library for user uploads

  List<Song>? _filteredSongsCache;

  List<Song> get songs => _songs;
  bool get loading => _loading;
  String? get error => _error;
  Set<String> get selectedTags => _selectedTags;
  String get searchQuery => _searchQuery;
  Set<String> get selectedLibraries => _selectedLibraries;

  List<Song> get filteredSongs {
    if (_filteredSongsCache != null) return _filteredSongsCache!;

    _filteredSongsCache = _songs.where((s) {
      final matchesTag = _selectedTags.isEmpty || s.tags.any((t) => _selectedTags.contains(t));
      final matchesSearch = _searchQuery.isEmpty ||
          s.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.composer.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesTag && matchesSearch;
    }).toList();

    return _filteredSongsCache!;
  }

  void _invalidateCache() {
    _filteredSongsCache = null;
  }

  List<String> get allTags {
    final tags = <String>{};
    for (final song in _songs) {
      tags.addAll(song.tags);
    }
    return tags.toList()..sort();
  }

  /// Returns all libraries currently in the user's collection.
  List<String> get currentLibraries {
    final libs = <String>{};
    for (final song in _songs) {
      libs.add(song.library);
    }
    // These are the known "available" libraries.
    libs.add(AppConfig.appName);
    return libs.toList()..sort();
  }

  /// Metadata for bundled songs available in the app.
  static final Map<String, List<Map<String, dynamic>>> bundledSongs = {
    AppConfig.appName: [
      {'title': 'Twinkle Twinkle Little Star', 'asset': 'assets/sample_songs/twinkle_twinkle.xml', 'tags': [], 'isDefault': true},
      {'title': 'The Wheels on the Bus', 'asset': 'assets/sample_songs/the_wheels_on_the_bus.xml', 'tags': [], 'isDefault': true},
      {'title': 'Mary Had a Little Lamb', 'asset': 'assets/sample_songs/mary_had_a_little_lamb.xml', 'tags': [], 'isDefault': true},
      {'title': 'Row, Row, Row Your Boat', 'asset': 'assets/sample_songs/row_row_row_your_boat.xml', 'tags': [], 'isDefault': true},
      {'title': 'Old MacDonald Had A Farm', 'asset': 'assets/sample_songs/old_macdonald.xml', 'tags': [], 'isDefault': true},
      {'title': 'Bingo', 'asset': 'assets/sample_songs/bingo.xml', 'tags': [], 'isDefault': true},
      {'title': 'Happy Birthday', 'asset': 'assets/sample_songs/happy_birthday.xml', 'tags': [], 'isDefault': true},
      {'title': 'Hey Diddle Diddle', 'asset': 'assets/sample_songs/hey_diddle_diddle.xml', 'tags': [], 'isDefault': true},
      {'title': 'Humpty Dumpty', 'asset': 'assets/sample_songs/humpty_dumpty.xml', 'tags': [], 'isDefault': true},

      {'title': 'Silent Night', 'asset': 'assets/sample_songs/silent_night.xml', 'tags': ['Religious'], 'isDefault': false},
      {'title': 'Concerning Hobbits', 'asset': 'assets/sample_songs/concerning_hobbits.xml', 'tags': ['Movie'], 'isDefault': false},
      {'title': 'Formatting', 'asset': 'assets/sample_songs/formatting.xml', 'tags': ['Testing'], 'isDefault': false},
      // {'title': 'Itsy Bitsy Spider', 'asset': 'assets/sample_songs/itsy_bitsy_spider.xml', 'tags': [], 'isDefault': true},
    ],
  };

  Future<void> loadSongs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _songs = await _storage.getAllSongs();
      _invalidateCache();
      // Ensure all default bundled songs are present in the library
      await _loadSampleSongs(onlyDefaults: true);
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads sample songs from the assets folder into the library if they are missing.
  Future<void> _loadSampleSongs({bool onlyDefaults = false}) async {
    for (final entry in bundledSongs.entries) {
      final libraryName = entry.key;
      for (final songData in entry.value) {
        if (onlyDefaults && songData['isDefault'] != true) continue;

        final title = songData['title'] as String;
        final alreadyExists = _songs.any((s) => s.title == title && s.library == libraryName);
        if (alreadyExists) continue;

        try {
          final assetPath = songData['asset'] as String;
          final xmlContent = await rootBundle.loadString(assetPath);
          await addSongFromXml(
            xmlContent,
            tags: List<String>.from(songData['tags'] as List),
            library: libraryName,
          );
        } catch (e) {
          debugPrint('Failed to load sample song: $e');
        }
      }
    }
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    _invalidateCache();
    notifyListeners();
  }

  void clearTags() {
    _selectedTags.clear();
    _invalidateCache();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _invalidateCache();
    notifyListeners();
  }

  void setLibrarySelected(String library, bool selected) {
    if (selected) {
      _selectedLibraries.add(library);
    } else {
      if (_selectedLibraries.length > 1) {
        _selectedLibraries.remove(library);
      }
    }
    notifyListeners();
  }

  /// Adds a song from raw MusicXML content.
  Future<Song?> addSongFromXml(
    String xmlContent, {
    List<String> tags = const [],
    String library = 'Default',
    String? sourceUrl,
    String? id,
  }) async {
    try {
      final songId = id ?? _uuid.v7();
      // Offload parsing to a separate isolate to keep UI smooth.
      final song = await compute(_parseSongInIsolate, {
        'content': xmlContent,
        'id': songId,
        'tags': tags,
        'library': library,
        'sourceUrl': sourceUrl,
      });

      await _storage.saveSong(song, xmlContent: xmlContent);
      
      final index = _songs.indexWhere((s) => s.id == songId);
      if (index >= 0) {
        _songs[index] = song;
      } else {
        _songs.add(song);
      }
      _invalidateCache();
      notifyListeners();
      return song;
    } catch (e) {
      _error = 'Failed to parse MusicXML: $e';
      notifyListeners();
      return null;
    }
  }

  Future<void> updateSongXml(String songId, String xmlContent) async {
    final meta = _songs.firstWhere((s) => s.id == songId);
    await addSongFromXml(
      xmlContent,
      id: meta.id,
      tags: meta.tags,
      library: meta.library,
      sourceUrl: meta.sourceUrl,
    );
  }

  /// Downloads and adds a song from a URL.
  Future<Song?> addSongFromUrl(String url, {List<String> tags = const [], String library = 'Default'}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final resolvedUrl = CloudService.isGcsUrl(url) && url.startsWith('gs://')
          ? CloudService.gsToHttps(url)
          : url;
      final xmlContent = await _cloud.fetchXml(resolvedUrl);
      return await addSongFromXml(xmlContent, tags: tags, library: library, sourceUrl: url);
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
      final xmlContent = await _storage.getXmlContent(songId);
      if (xmlContent == null) return meta;

      // Offload parsing to a separate isolate.
      return await compute(_parseSongInIsolate, {
        'content': xmlContent,
        'id': meta.id,
        'tags': meta.tags,
        'library': meta.library,
        'localPath': meta.localPath,
        'sourceUrl': meta.sourceUrl,
        'createdAt': meta.createdAt,
      });
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
      _invalidateCache();
      notifyListeners();
    }
  }

  Future<void> deleteSong(String songId) async {
    await _storage.deleteSong(songId);
    _songs.removeWhere((s) => s.id == songId);
    _invalidateCache();
    notifyListeners();
  }
}

/// Helper for running MusicXmlParser in an isolate.
Song _parseSongInIsolate(Map<String, dynamic> params) {
  return MusicXmlParser.parse(
    params['content'] as String,
    id: params['id'] as String,
    tags: params['tags'] as List<String>,
    library: params['library'] as String,
    localPath: params['localPath'] as String?,
    sourceUrl: params['sourceUrl'] as String?,
    createdAt: params['createdAt'] as DateTime?,
  );
}
