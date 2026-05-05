import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/song.dart';
import '../services/musicxml_parser.dart';
import '../services/storage_service.dart';
import '../services/cloud_service.dart';
import '../config/app_config.dart';
import '../main.dart'; // Import to use showToast

/// Manages the list of songs and loading/saving operations.
class SongProvider extends ChangeNotifier {
  static const String builtinLibraryName = 'Fun Sheet Music';
  static const String _songOrderKey = 'song_order';
  static const String _seenAssetsKey = 'seen_auto_add_assets';
  final StorageService _storage;
  final CloudService _cloud;
  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;
  List<String> _songOrder = [];

  SongProvider({
    required StorageService storage,
    CloudService? cloud,
  })  : _storage = storage,
        _cloud = cloud ?? CloudService();

  List<Song> _songs = [];
  Map<String, List<Song>> _bundledSongsMetadata = {};
  bool _loading = false;
  String? _error;
  String _searchQuery = '';
  final Set<String> _selectedTags = {};
  final Set<String> _selectedLibraries = {builtinLibraryName};

  List<Song>? _filteredSongsCache;

  List<Song> get songs => _songs;
  Map<String, List<Song>> get bundledSongsMetadata => _bundledSongsMetadata;
  bool get loading => _loading;
  String? get error => _error;
  Set<String> get selectedTags => _selectedTags;
  String get searchQuery => _searchQuery;
  Set<String> get selectedLibraries => _selectedLibraries;

  bool get isTestingEnabled {
    final uri = Uri.base;
    return kDebugMode || (kIsWeb && (uri.host == 'localhost' || uri.queryParameters.containsKey('testing')));
  }

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
    libs.add(builtinLibraryName);
    for (final libName in _bundledSongsMetadata.keys) {
      libs.add(libName);
    }
    return libs.where((l) => l.isNotEmpty).toList()..sort();
  }

  Future<void> loadSongs() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _songOrder = _prefs!.getStringList(_songOrderKey) ?? [];
      _songs = await _storage.getAllSongs();
      _applySongOrder();

      // Only perform migrations if needed
      final lastMigrated = _prefs!.getInt('last_migration_version') ?? 0;
      if (lastMigrated < 1) {
        await _performMigrations();
        await _prefs!.setInt('last_migration_version', 1);
      }

      _invalidateCache();
      
      // Load bundled metadata and handle sample songs in the background
      _initializeAssets(onlyDefaults: true);
    } catch (e) {
      _error = e.toString();
      showToast('Error loading library: $e', isError: true);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _performMigrations() async {
    for (int i = 0; i < _songs.length; i++) {
      try {
        final song = _songs[i];
        bool needsUpdate = false;
        String? newLibrary;

        if (song.library == AppConfig.appName || song.library == 'Built In') {
          newLibrary = builtinLibraryName;
          needsUpdate = true;
        }

        if (needsUpdate) {
          _songs[i] = song.copyWith(library: newLibrary ?? song.library);
          await _storage.updateMetadata(_songs[i].id, library: newLibrary);
        }
      } catch (e) {
        debugPrint('Migration error for song: $e');
      }
    }
  }

  Future<void> _initializeAssets({bool onlyDefaults = false}) async {
    // Load bundled song metadata for the "Add Song" screen
    await _loadBundledMetadata();
    // Load remote samples if in testing mode
    await _loadRemoteTestingMetadata();
    // Ensure all default bundled songs are present in the library
    await _loadSampleSongs(onlyDefaults: onlyDefaults);
  }

  /// Loads metadata for all bundled songs from assets.
  Future<void> _loadBundledMetadata() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final songAssets = manifest.listAssets().where((p) => p.endsWith('.xml') && (p.contains('assets/music/') || p.contains('music/'))).toList();

      final uri = Uri.base;
      final isTestingEnabled = kDebugMode || (kIsWeb && (uri.host == 'localhost' || uri.queryParameters.containsKey('testing')));

      // Load all XML contents in parallel
      final List<({String path, String content})> loadedAssets = await Future.wait(
        songAssets.map((path) async {
          try {
            final content = await rootBundle.loadString(path);
            return (path: path, content: content);
          } catch (e) {
            debugPrint('Error loading asset $path: $e');
            return (path: path, content: '');
          }
        }),
      );

      final Map<String, List<Song>> results = {};
      
      // Perform metadata parsing in parallel using isolates to keep the UI thread free
      final List<Song> parsedMetadatas = await compute(_parseMultipleMetadatas, loadedAssets);

      for (final metadata in parsedMetadatas) {
        results.putIfAbsent(metadata.library, () => []).add(metadata);
      }
      _bundledSongsMetadata = results;
      
      // Auto-select discovered libraries if we only had the default one
      if (_selectedLibraries.length == 1 && _selectedLibraries.contains(builtinLibraryName)) {
        _selectedLibraries.addAll(_bundledSongsMetadata.keys);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading asset manifest: $e');
      showToast('Error discovering bundled music: $e', isError: true);
    }
  }

  /// Loads remote MusicXML samples for testing purposes.
  Future<void> _loadRemoteTestingMetadata() async {
    final uri = Uri.base;
    final isTestingEnabled = kDebugMode || (kIsWeb && (uri.host == 'localhost' || uri.queryParameters.containsKey('testing')));
    if (!isTestingEnabled) return;

    const libraryName = 'W3C Samples';
    try {
      final List<Song> remoteSongs = [];
      
      // We use a reliable mirror for the official W3C samples since raw.githubusercontent 
      // can be inconsistent with branch names (master vs main vs v3.1)
      const samplesBaseUrl = 'https://raw.githubusercontent.com/kddeisz/musicxml/master/samples/';
      
      // These are confirmed working URLs in the kddeisz mirror
      final standardSamples = [
        'ActorPreludeSample.xml',
        'Dichterliebe01.xml',
        'Binchois.xml',
        'Moza545.xml',
        'Saltorel.xml',
        'Schubert_AnDieMusik.xml',
      ];

      for (final name in standardSamples) {
        remoteSongs.add(Song(
          id: '$samplesBaseUrl$name',
          title: name.replaceAll('.xml', '').replaceAll('_', ' '),
          library: libraryName,
          sourceUrl: '$samplesBaseUrl$name',
          createdAt: DateTime.now(),
          measures: const [],
        ));
      }

      _bundledSongsMetadata[libraryName] = remoteSongs;
      _selectedLibraries.add(libraryName);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to load remote testing samples: $e');
      showToast('Failed to load remote test samples: $e', isError: true);
    }
  }

  /// Loads sample songs from the assets folder into the library if they are missing.
  Future<void> _loadSampleSongs({bool onlyDefaults = false}) async {
    final seenAssets = _prefs?.getStringList(_seenAssetsKey)?.toSet() ?? {};
    final newSeenAssets = Set<String>.from(seenAssets);
    final Map<String, int> newAvailableByLibrary = {};
    // We consider it a "clean slate" only if they have no songs and haven't seen assets before.
    bool isFirstRun = seenAssets.isEmpty && _songs.isEmpty;

    for (final entry in _bundledSongsMetadata.entries) {
      final libraryName = entry.key;
      for (final metadata in entry.value) {
        // Yield every few songs to keep UI thread from locking up
        if (newSeenAssets.length % 5 == 0) {
          await Future.delayed(Duration.zero);
        }

        try {
          final assetPath = metadata.localPath;
          if (assetPath == null) continue; // Skip remote songs

          final isAutoAdd = assetPath.contains('/auto-add/');
          if (onlyDefaults && !isAutoAdd) continue;

          // Check if this specific asset is already imported
          final alreadyExists = _songs.any((s) => s.localPath == assetPath && s.library == libraryName);

          if (alreadyExists) {
            newSeenAssets.add(assetPath);
            continue;
          }

          // If we've "seen" it before, it means the user deleted it or we notified them about it already.
          if (seenAssets.contains(assetPath)) {
            continue;
          }

          // Double check by title to avoid duplicates
          if (_songs.any((s) => s.title == metadata.title && s.library == libraryName)) {
            final existing = _songs.firstWhere((s) => s.title == metadata.title && s.library == libraryName);
            await _storage.updateMetadata(existing.id, localPath: assetPath);
            newSeenAssets.add(assetPath);
            continue;
          }

          // DECISION POINT: Auto-add vs Notify
          // We only auto-add to the home screen if it's the very first run AND the song is in auto-add.
          if (isAutoAdd && isFirstRun) {
            final xmlContent = await rootBundle.loadString(assetPath);
            await addSongFromXml(
              xmlContent,
              tags: metadata.tags,
              library: libraryName,
              localPath: assetPath,
            );
            newSeenAssets.add(assetPath);
          } else {
            // It's a new song we haven't seen before. 
            // We don't auto-add (to avoid being intrusive), but we notify.
            newAvailableByLibrary[libraryName] = (newAvailableByLibrary[libraryName] ?? 0) + 1;
            newSeenAssets.add(assetPath);
          }
        } catch (e) {
          debugPrint('Failed to load sample song (${metadata.title}): $e');
        }
      }
    }

    if (newSeenAssets.length != seenAssets.length) {
      await _prefs?.setStringList(_seenAssetsKey, newSeenAssets.toList());
    }

    if (newAvailableByLibrary.isNotEmpty) {
      final messages = newAvailableByLibrary.entries.map((e) => '${e.value} in ${e.key}').join(', ');
      showToast('New music available: $messages. Check the "Add Song" menu!');
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

  /// Clears all data and reloads the app state to simulate a new user.
  Future<void> resetApp() async {
    _loading = true;
    notifyListeners();
    try {
      // 1. Clear database
      await _storage.clearAll();
      
      // 2. Clear all preferences
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.clear();
      
      // 3. Clear in-memory state
      _songs = [];
      _songOrder = [];
      _selectedTags.clear();
      _selectedLibraries.clear();
      _selectedLibraries.add(builtinLibraryName);
      _invalidateCache();
      
      // 4. Trigger a full reload of everything
      await loadSongs();
      
      showToast('App reset successful. Simulation of new user complete.');
    } catch (e) {
      debugPrint('Reset failed: $e');
      showToast('Failed to reset app: $e', isError: true);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Adds a song from raw MusicXML content.
  Future<Song?> addSongFromXml(
    String xmlContent, {
    List<String> tags = const [],
    String library = 'Default',
    String? icon,
    String? localPath,
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
        'icon': icon,
        'localPath': localPath,
        'sourceUrl': sourceUrl,
      });

      await _storage.saveSong(song, xmlContent: xmlContent);
      
      final index = _songs.indexWhere((s) => s.id == songId);
      if (index >= 0) {
        _songs[index] = song;
      } else {
        _songs.insert(0, song); // Add new songs to the top
      }
      _invalidateCache();
      notifyListeners();
      return song;
    } catch (e) {
      _error = 'Failed to parse MusicXML: $e';
      showToast(_error!, isError: true);
      notifyListeners();
      return null;
    }
  }

  Future<void> updateSongXml(String songId, String xmlContent) async {
    try {
      final meta = _songs.firstWhere((s) => s.id == songId);
      await addSongFromXml(
        xmlContent,
        id: meta.id,
        tags: meta.tags,
        library: meta.library,
        sourceUrl: meta.sourceUrl,
      );
    } catch (e) {
      showToast('Failed to update song: $e', isError: true);
    }
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
      showToast(_error!, isError: true);
      return null;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Loads full MusicXML (re-parses) for a stored song.
  Future<Song?> loadFullSong(String songId) async {
    try {
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
      showToast(_error!, isError: true);
      notifyListeners();
      return null;
    }
  }

  Future<void> updateTags(String songId, List<String> tags) async {
    try {
      await _storage.updateTags(songId, tags);
      final index = _songs.indexWhere((s) => s.id == songId);
      if (index >= 0) {
        _songs[index] = _songs[index].copyWith(tags: tags);
        _invalidateCache();
        notifyListeners();
      }
    } catch (e) {
      showToast('Failed to update tags: $e', isError: true);
    }
  }

  Future<void> deleteSong(String songId) async {
    try {
      await _storage.deleteSong(songId);
      _songs.removeWhere((s) => s.id == songId);
      _invalidateCache();
      notifyListeners();
    } catch (e) {
      showToast('Failed to delete song: $e', isError: true);
    }
  }

  /// Reorders songs in the list and persists the order.
  Future<void> reorderSongs(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;
    
    // Adjust newIndex if moving down (ReorderableList behavior)
    if (newIndex > oldIndex) {
      newIndex -= 1;
    }
    
    // Reorder the filtered songs list (what the user sees)
    final song = _songs.removeAt(oldIndex);
    _songs.insert(newIndex, song);
    
    // Save the new order
    _songOrder = _songs.map((s) => s.id).toList();
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setStringList(_songOrderKey, _songOrder);
    
    _invalidateCache();
    notifyListeners();
  }

  /// Applies the saved song order to the songs list.
  void _applySongOrder() {
    if (_songOrder.isEmpty) return;
    
    // Create a map for quick lookup
    final songMap = {for (var song in _songs) song.id: song};
    
    // Build ordered list based on saved order
    final orderedSongs = <Song>[];
    for (final id in _songOrder) {
      if (songMap.containsKey(id)) {
        orderedSongs.add(songMap[id]!);
        songMap.remove(id);
      }
    }
    
    // Add any new songs that aren't in the saved order at the beginning
    orderedSongs.insertAll(0, songMap.values);
    
    _songs = orderedSongs;
    
    // Update the order to include new songs
    if (songMap.isNotEmpty) {
      _songOrder = _songs.map((s) => s.id).toList();
      _prefs?.setStringList(_songOrderKey, _songOrder);
    }
  }
}

/// Helper for running MusicXmlParser in an isolate.
Song _parseSongInIsolate(Map<String, dynamic> params) {
  final song = MusicXmlParser.parse(
    params['content'] as String,
    id: params['id'] as String,
    tags: params['tags'] as List<String>,
    library: params['library'] as String,
    localPath: params['localPath'] as String?,
    sourceUrl: params['sourceUrl'] as String?,
    createdAt: params['createdAt'] as DateTime?,
  );

  // If an icon was provided in params, it overrides the one in XML
  if (params['icon'] != null && (params['icon'] as String).isNotEmpty) {
    return song.copyWith(icon: params['icon'] as String);
  }
  return song;
}

/// Helper for parsing multiple metadatas in an isolate to unblock the UI thread.
List<Song> _parseMultipleMetadatas(List<({String path, String content})> assets) {
  final List<Song> results = [];
  for (final asset in assets) {
    if (asset.content.isEmpty) continue;
    try {
      // Determine library name from folder
      String libraryName = SongProvider.builtinLibraryName;
      final parts = asset.path.split('/');
      final musicIndex = parts.indexOf('music');

      if (musicIndex != -1 && musicIndex + 1 < parts.length) {
        final folderName = parts[musicIndex + 1];
        if (folderName == 'shared_by_users') {
          libraryName = 'Shared by Users';
        } else if (folderName == 'testing') {
          libraryName = 'Testing';
        } else if (folderName == 'defaults') {
          libraryName = SongProvider.builtinLibraryName;
        } else {
          libraryName = folderName
              .split('_')
              .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
              .join(' ');
        }
      }

      final metadata = MusicXmlParser.parseMetadata(
        asset.content,
        id: asset.path,
        library: libraryName,
        localPath: asset.path,
      );
      results.add(metadata);
    } catch (_) {
      // Ignore individual failures
    }
  }
  return results;
}
