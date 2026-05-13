import 'dart:convert';
import 'dart:io';
import 'package:xml/xml.dart';

/// Scans the community_library/songs/ directory and generates a manifest JSON.
void main() async {
  final songsDir = Directory('community_library/songs');
  if (!songsDir.existsSync()) {
    print('Error: community_library/songs directory not found.');
    exit(1);
  }

  final List<Map<String, dynamic>> songs = [];
  final files = songsDir.listSync().whereType<File>().where((f) => f.path.endsWith('.xml'));

  print('Scanning ${files.length} files...');

  for (final file in files) {
    try {
      final content = file.readAsStringSync();
      final document = XmlDocument.parse(content);

      final scorePartwise = document.findElements('score-partwise').firstOrNull;
      final scoreTimewise = document.findElements('score-timewise').firstOrNull;
      final root = scorePartwise ?? scoreTimewise;

      if (root == null) continue;

      final title = _getTitle(root);
      final composer = _getComposer(root);
      final icon = _getMiscellaneousField(root, 'icon');
      final tags = _getMiscellaneousFields(root, 'tag');

      songs.add({
        'id': 'community_${file.uri.pathSegments.last.replaceAll('.xml', '')}',
        'title': title.isNotEmpty ? title : 'Untitled',
        'composer': composer,
        'icon': icon,
        'tags': tags,
        'library': 'Community',
        'localPath': 'https://raw.githubusercontent.com/mvndaai/fun-sheet-music/main/community_library/songs/${file.uri.pathSegments.last}',
        'createdAt': DateTime.now().toIso8601String(),
      });
      print('Added: $title');
    } catch (e) {
      print('Error parsing ${file.path}: $e');
    }
  }

  final manifestFile = File('community_library/songs_manifest.json');
  final encoder = JsonEncoder.withIndent('  ');
  manifestFile.writeAsStringSync(encoder.convert(songs));

  print('Manifest generated at ${manifestFile.path}');
}

String _getTitle(XmlElement root) {
  final work = root.findElements('work').firstOrNull;
  if (work != null) {
    final title = work.findElements('work-title').firstOrNull;
    if (title != null) return title.innerText.trim();
  }
  final movement = root.findElements('movement-title').firstOrNull;
  if (movement != null) return movement.innerText.trim();

  final credit = root.findElements('credit').firstOrNull;
  if (credit != null) {
    final words = credit.findElements('credit-words').firstOrNull;
    if (words != null) return words.innerText.trim();
  }

  return '';
}

String _getComposer(XmlElement root) {
  final identification = root.findElements('identification').firstOrNull;
  if (identification != null) {
    for (final creator in identification.findElements('creator')) {
      if (creator.getAttribute('type') == 'composer') {
        return creator.innerText.trim();
      }
    }
  }
  return '';
}

String _getMiscellaneousField(XmlElement root, String fieldName) {
  final identification = root.findElements('identification').firstOrNull;
  if (identification == null) return '';
  final misc = identification.findElements('miscellaneous').firstOrNull;
  if (misc == null) return '';

  for (final field in misc.findElements('miscellaneous-field')) {
    if (field.getAttribute('name') == fieldName) {
      return field.innerText.trim();
    }
  }
  return '';
}

List<String> _getMiscellaneousFields(XmlElement root, String fieldName) {
  final identification = root.findElements('identification').firstOrNull;
  if (identification == null) return [];
  final misc = identification.findElements('miscellaneous').firstOrNull;
  if (misc == null) return [];

  final List<String> fields = [];
  for (final field in misc.findElements('miscellaneous-field')) {
    if (field.getAttribute('name') == fieldName) {
      fields.add(field.innerText.trim());
    }
  }
  return fields;
}
