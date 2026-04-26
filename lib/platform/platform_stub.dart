import 'package:drift/drift.dart';

/// A stub implementation of platform-specific functions.
/// This file is used as a fallback and to define the interface.

/// Platform interface for a tone player.
abstract class PlatformTonePlayer {
  Future<void> playTone(double frequency, int durationMs);
  void startTone(double frequency);
  void stopTone(double frequency);
  Future<void> playSample(String path);
  void startSample(String path);
  void stopSample(String path);
  void dispose();
}

/// Creates a platform-specific tone player.
PlatformTonePlayer createPlatformPlayer() {
  throw UnsupportedError('Cannot create player without platform implementation');
}

/// Saves a file to the device.
Future<void> saveFile({required String title, required String content}) {
  throw UnimplementedError('saveFile has not been implemented on this platform.');
}

/// Opens a platform-specific database connection.
QueryExecutor openDatabaseConnection() {
  throw UnsupportedError('openDatabaseConnection has not been implemented on this platform.');
}

/// Gets the directory for storing audio samples.
/// Returns null on web since file system access is not available.
Future<String?> getSamplesDirectory(String instrumentId) {
  throw UnimplementedError('getSamplesDirectory has not been implemented on this platform.');
}
