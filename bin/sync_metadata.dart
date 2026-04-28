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

  final String title = pubspec['names_launcher']?['name'] ?? 'Flutter App';
  final String description = pubspec['description'] ?? '';
  final String appName = pubspec['name'] ?? 'flutter_app';
  final String shortName = title.replaceAll(' ', '').toLowerCase();
  final String className = title
          .split(RegExp(r'[\s_-]'))
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase() + s.substring(1).toLowerCase())
          .join() +
      'App';

  print('Syncing Metadata:');
  print('  Title: $title');
  print('  Description: $description');
  print('  AppName (underscore): $appName');
  print('  ShortName (no spaces): $shortName');
  print('  ClassName: $className');

  // 1. Update AppConfig.dart
  _updateFile(
    'lib/config/app_config.dart',
    [
      (RegExp(r"static const String title = '.*?';"), "static const String title = '$title';"),
      (RegExp(r"static const String appName = '.*?';"), "static const String appName = '$appName';"),
      (RegExp(r"static const String shortName = '.*?';"), "static const String shortName = '$shortName';"),
      (RegExp(r"static const String description = '.*?';"), "static const String description = '$description';"),
      (RegExp(r"static const String className = '.*?';"), "static const String className = '$className';"),
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
  // This is a bit more invasive, we look for the old class name by looking at what's currently in AppConfig
  final appConfigContent = File('lib/config/app_config.dart').readAsStringSync();
  final oldClassNameMatch = RegExp(r"static const String className = '(.*?)';").firstMatch(appConfigContent);
  if (oldClassNameMatch != null) {
    final oldClassName = oldClassNameMatch.group(1)!;
    if (oldClassName != className) {
      _updateFile('lib/main.dart', [
        (RegExp('class $oldClassName'), 'class $className'),
        (RegExp('runApp\\($oldClassName'), 'runApp($className'),
      ]);
      // Also update tests
      _updateFile('test/home_screen_test.dart', [
        (RegExp('await tester.pumpWidget\\($oldClassName'), 'await tester.pumpWidget($className'),
      ]);
    }
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
