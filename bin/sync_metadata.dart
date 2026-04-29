import 'dart:io';
import 'package:yaml/yaml.dart';

/// This script synchronizes the app name and description from pubspec.yaml
/// to various native and configuration files across the project.
void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: pubspec.yaml not found.');
    return;
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final pubspec = loadYaml(pubspecContent);

  final String title = pubspec['names_launcher']?['name'] ?? 'Fun Sheet Music';
  final String description = pubspec['description'] ?? '';
  final String appName = pubspec['name'] ?? 'fun_sheet_music';
  final String shortName = title.replaceAll(' ', '').toLowerCase();
  
  // Generate className without "App" suffix as requested
  final String className = title
          .split(RegExp(r'[\s_-]'))
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
          .join();

  print('Syncing Metadata:');
  print('  Title: $title');
  print('  Description: $description');
  print('  AppName (underscore): $appName');
  print('  ShortName (no spaces): $shortName');
  print('  ClassName: $className');

  // Read current className from AppConfig to handle renaming classes in main.dart
  const appConfigPath = 'lib/config/app_config.dart';
  String oldClassName = '';
  if (File(appConfigPath).existsSync()) {
    final appConfigContent = File(appConfigPath).readAsStringSync();
    final match = RegExp(r"static const String title = '(.*?)';").firstMatch(appConfigContent);
    if (match != null) {
      final oldTitle = match.group(1)!;
      oldClassName = oldTitle
          .split(RegExp(r'[\s_-]'))
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
          .join();
    }
  }

  // 1. Update AppConfig.dart
  _updateFile(
    appConfigPath,
    [
      (RegExp(r"static const String title = '.*?';"), "static const String title = '$title';"),
      (RegExp(r"static const String description = '.*?';"), "static const String description = '$description';"),
    ],
  );

  // 2. Update AndroidManifest.xml
  _updateFile(
    'android/app/src/main/AndroidManifest.xml',
    [
      (RegExp(r'android:label=".*?"'), 'android:label="$title"'),
    ],
  );

  // 3. Update iOS Info.plist
  _updateFile(
    'ios/Runner/Info.plist',
    [
      (RegExp(r'<key>CFBundleDisplayName</key>\s*<string>.*?</string>'), '<key>CFBundleDisplayName</key>\n\t<string>$title</string>'),
      (RegExp(r'<key>CFBundleName</key>\s*<string>.*?</string>'), '<key>CFBundleName</key>\n\t<string>$appName</string>'),
    ],
  );

  // 4. Update web/index.html
  _updateFile(
    'web/index.html',
    [
      (RegExp(r'<title>.*?</title>'), '<title>$title</title>'),
      (RegExp(r'<meta name="description" content=".*?">'), '<meta name="description" content="$description">'),
      (RegExp(r'<meta name="apple-mobile-web-app-title" content=".*?">'), '<meta name="apple-mobile-web-app-title" content="$title">'),
    ],
  );

  // 5. Update web/manifest.json
  _updateFile(
    'web/manifest.json',
    [
      (RegExp(r'"name": ".*?"'), '"name": "$title"'),
      (RegExp(r'"short_name": ".*?"'), '"short_name": "$shortName"'),
      (RegExp(r'"description": ".*?"'), '"description": "$description"'),
    ],
  );

  // 6. Update README.md
  _updateFile(
    'README.md',
    [
      (RegExp(r'^# .*', multiLine: true), '# $title'),
      (RegExp(r'^A Flutter app (?:for|that) .*?\.', multiLine: true), description),
    ],
  );

  // 7. Update main.dart class name and usage
  if (oldClassName.isNotEmpty && oldClassName != className) {
    _updateFile('lib/main.dart', [
      (RegExp('\\b$oldClassName\\b'), className),
    ]);
    // Also update tests
    _updateFile('test/home_screen_test.dart', [
      (RegExp('\\b$oldClassName\\b'), className),
    ]);
  }

  print('\nMetadata sync complete!');
}

void _updateFile(String path, List<(RegExp, String)> replacements) {
  final file = File(path);
  if (!file.existsSync()) {
    print('  Skipping $path: File not found.');
    return;
  }

  String content = file.readAsStringSync();
  bool changed = false;

  for (final replacement in replacements) {
    final oldContent = content;
    content = content.replaceAll(replacement.$1, replacement.$2);
    if (oldContent != content) changed = true;
  }

  if (changed) {
    file.writeAsStringSync(content);
    print('  Updated $path');
  } else {
    print('  No changes needed for $path');
  }
}
