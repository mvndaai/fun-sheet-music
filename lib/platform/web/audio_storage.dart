import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import '../../config/app_config.dart';

/// Stores and retrieves audio samples in IndexedDB for web platform.
/// 
/// Uses a simple key-value store where keys are in format "instrumentId:noteName"
/// and values are audio Blob objects.
class AudioStorage {
  static const String _dbName = '${AppConfig.appName}_audio';
  static const String _storeName = 'samples';
  static const int _dbVersion = 1;

  web.IDBDatabase? _db;
  final Completer<void> _initCompleter = Completer<void>();

  AudioStorage() {
    _init();
  }

  Future<void> _init() async {
    try {
      final request = web.window.indexedDB.open(_dbName, _dbVersion);

      request.onupgradeneeded = (web.IDBVersionChangeEvent e) {
        final db = (e.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(_storeName);
        }
      }.toJS;

      request.onsuccess = (web.Event e) {
        _db = (e.target as web.IDBOpenDBRequest).result as web.IDBDatabase;
        _initCompleter.complete();
      }.toJS;

      request.onerror = (web.Event e) {
        _initCompleter.completeError('Failed to open IndexedDB');
      }.toJS;
    } catch (e) {
      _initCompleter.completeError(e);
    }
  }

  /// Ensures the database is initialized before operations.
  Future<void> _ensureInitialized() async {
    if (!_initCompleter.isCompleted) {
      await _initCompleter.future;
    }
  }

  /// Saves an audio blob with the given key.
  /// Returns the key on success, null on failure.
  Future<String?> saveAudioBlob({
    required String instrumentId,
    required String noteName,
    required web.Blob blob,
  }) async {
    try {
      await _ensureInitialized();
      if (_db == null) return null;

      final key = '$instrumentId:$noteName';
      final transaction = _db!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);

      final completer = Completer<String?>();
      final request = store.put(blob, key.toJS);

      request.onsuccess = (web.Event e) {
        completer.complete(key);
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(null);
      }.toJS;

      return await completer.future;
    } catch (e) {
      return null;
    }
  }

  /// Retrieves an audio blob by key.
  /// Returns null if not found.
  Future<web.Blob?> getAudioBlob(String key) async {
    try {
      await _ensureInitialized();
      if (_db == null) return null;

      final transaction = _db!.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);

      final completer = Completer<web.Blob?>();
      final request = store.get(key.toJS);

      request.onsuccess = (web.Event e) {
        final result = (e.target as web.IDBRequest).result;
        if (result != null && result.typeofEquals('object')) {
          completer.complete(result as web.Blob);
        } else {
          completer.complete(null);
        }
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(null);
      }.toJS;

      return await completer.future;
    } catch (e) {
      return null;
    }
  }

  /// Creates a blob URL for the given key.
  /// Returns null if the blob is not found.
  /// 
  /// IMPORTANT: Caller must revoke the URL when done using web.URL.revokeObjectURL()
  Future<String?> createBlobUrl(String key) async {
    final blob = await getAudioBlob(key);
    if (blob == null) return null;
    return web.URL.createObjectURL(blob);
  }

  /// Deletes an audio blob by key.
  Future<bool> deleteAudioBlob(String key) async {
    try {
      await _ensureInitialized();
      if (_db == null) return false;

      final transaction = _db!.transaction(_storeName.toJS, 'readwrite');
      final store = transaction.objectStore(_storeName);

      final completer = Completer<bool>();
      final request = store.delete(key.toJS);

      request.onsuccess = (web.Event e) {
        completer.complete(true);
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete(false);
      }.toJS;

      return await completer.future;
    } catch (e) {
      return false;
    }
  }

  /// Lists all keys in storage.
  Future<List<String>> listKeys() async {
    try {
      await _ensureInitialized();
      if (_db == null) return [];

      final transaction = _db!.transaction(_storeName.toJS, 'readonly');
      final store = transaction.objectStore(_storeName);

      final completer = Completer<List<String>>();
      final request = store.getAllKeys();

      request.onsuccess = (web.Event e) {
        final result = (e.target as web.IDBRequest).result;
        if (result != null) {
          final keys = <String>[];
          final jsArray = result as JSArray;
          for (var i = 0; i < jsArray.length; i++) {
            final key = jsArray[i];
            if (key != null) {
              keys.add(key.toString());
            }
          }
          completer.complete(keys);
        } else {
          completer.complete([]);
        }
      }.toJS;

      request.onerror = (web.Event e) {
        completer.complete([]);
      }.toJS;

      return await completer.future;
    } catch (e) {
      return [];
    }
  }

  /// Closes the database connection.
  void dispose() {
    _db?.close();
    _db = null;
  }
}
