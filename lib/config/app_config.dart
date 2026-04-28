/// General application configuration.
/// 
/// NOTE: To update name or description across the entire project (native files included),
/// change them in [pubspec.yaml] and run:
/// [dart run bin/sync_metadata.dart]
class AppConfig {
  AppConfig._();

  /// Display name (e.g., "Fun Sheet Music")
  static const String title = 'Fun Sheet Music';

  /// Package name / directory name (e.g., "fun_sheet_music")
  static const String appName = 'fun_sheet_music';

  /// No spaces, lowercase (e.g., "funsheetmusic")
  static const String shortName = 'funsheetmusic';

  /// App description
  static const String description = 'An app for displaying colored sheet music with practice modes.';

  /// Root widget class name (e.g., "FunSheetMusicApp")
  static const String className = 'FunSheetMusicApp';
}
