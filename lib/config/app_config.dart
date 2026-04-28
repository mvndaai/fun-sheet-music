/// General application configuration.
/// 
/// NOTE: To update name or description across the entire project (native files included),
/// change them in [pubspec.yaml] and run:
/// [dart run bin/sync_metadata.dart]
class AppConfig {
  AppConfig._();

  /// Display name (e.g., "Fun Sheet Music")
  static const String title = 'Fun Sheet Music';

  /// App description
  static const String description = 'An app for displaying colored sheet music with practice modes.';

  /// Package name / directory name (e.g., "fun_sheet_music")
  static String get appName => title.toLowerCase().replaceAll(' ', '_');

  /// No spaces, lowercase (e.g., "funsheetmusic")
  static String get shortName => title.toLowerCase().replaceAll(' ', '');

  /// Root widget class name (e.g., "FunSheetMusic")
  static String get className => title
      .split(RegExp(r'[\s_-]'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
      .join();
}
