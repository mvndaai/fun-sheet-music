import 'package:xml/xml.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/measure.dart';
import '../music_kit/models/song.dart';

/// Parses a MusicXML string into a [Song].
class MusicXmlParser {
  /// Parses the given MusicXML [content] and returns a [Song].
  ///
  /// [id] and [createdAt] are metadata not present in the XML.
  static Song parse(
    String content, {
    required String id,
    List<String> tags = const [],
    String library = 'Default',
    String? localPath,
    String? sourceUrl,
    DateTime? createdAt,
  }) {
    final document = XmlDocument.parse(content);
    final root = _getRoot(document);

    final title = _getTitle(root);
    final icon = _getMiscellaneousField(root, 'icon');
    final xmlTags = _getMiscellaneousFields(root, 'tag');
    final lyricsVariables = _getLyricsVariables(root);
    final (lyricsVariableSets, defaultLyricsVariables) = _getLyricsVariableSets(root);
    final composer = _getComposer(root);
    final measures = _parseMeasures(root);

    return Song(
      id: id,
      title: title.isNotEmpty ? title : 'Untitled',
      icon: icon,
      composer: composer,
      measures: measures,
      tags: <String>{...tags, ...xmlTags}.toList(),
      library: library,
      localPath: localPath,
      sourceUrl: sourceUrl,
      createdAt: createdAt ?? DateTime.now(),
      lyricsVariables: lyricsVariables,
      lyricsVariableSets: lyricsVariableSets,
      defaultLyricsVariables: defaultLyricsVariables,
    );
  }

  /// Parses only metadata (title, icon, composer) from MusicXML.
  /// This is much faster than full parsing for large files.
  static Song parseMetadata(
    String content, {
    required String id,
    List<String> tags = const [],
    String library = 'Default',
    String? localPath,
    String? sourceUrl,
    DateTime? createdAt,
  }) {
    final document = XmlDocument.parse(content);
    final root = _getRoot(document);

    final title = _getTitle(root);
    final icon = _getMiscellaneousField(root, 'icon');
    final xmlTags = _getMiscellaneousFields(root, 'tag');
    final composer = _getComposer(root);

    return Song(
      id: id,
      title: title.isNotEmpty ? title : 'Untitled',
      icon: icon,
      composer: composer,
      measures: const [], // No measures for metadata-only
      tags: <String>{...tags, ...xmlTags}.toList(),
      library: library,
      localPath: localPath,
      sourceUrl: sourceUrl,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static XmlElement _getRoot(XmlDocument document) {
    final scorePartwise = document.findElements('score-partwise').firstOrNull;
    final scoreTimewise = document.findElements('score-timewise').firstOrNull;
    final root = scorePartwise ?? scoreTimewise;
    if (root == null) {
      throw const FormatException('Not a valid MusicXML file');
    }
    return root;
  }

  static String _getMiscellaneousField(XmlElement root, String fieldName) {
    for (final field in root.findAllElements('miscellaneous-field')) {
      if (field.getAttribute('name') == fieldName) {
        return field.innerText.trim();
      }
    }
    return '';
  }

  static List<String> _getMiscellaneousFields(XmlElement root, String fieldName) {
    final results = <String>[];
    for (final field in root.findAllElements('miscellaneous-field')) {
      if (field.getAttribute('name') == fieldName) {
        final val = field.innerText.trim();
        if (val.isNotEmpty) results.add(val);
      }
    }
    return results;
  }

  static Map<String, List<String>> _getLyricsVariables(XmlElement root) {
    final results = <String, List<String>>{};
    for (final field in root.findAllElements('miscellaneous-field')) {
      final name = field.getAttribute('name') ?? '';
      if (name.startsWith('vars-')) {
        final key = name.substring(5);
        final values = field.innerText.split(',').map((e) => e.trim()).toList();
        results[key] = values;
      }
    }
    return results;
  }

  static (List<Map<String, String>>, Map<String, String>) _getLyricsVariableSets(XmlElement root) {
    final sets = <Map<String, String>>[];
    Map<String, String> defaultSet = {};
    
    // 1. Check for structured "variables" field (New XML-like format)
    for (final field in root.findAllElements('miscellaneous-field')) {
      if (field.getAttribute('name') == 'variables') {
        // Look for default variables
        final defaultEl = field.findElements('default').firstOrNull;
        if (defaultEl != null) {
          for (final node in defaultEl.children) {
            if (node is XmlElement) {
              defaultSet[node.name.local] = node.innerText.trim();
            }
          }
        }

        // Look for nested <verse> elements
        final verseEls = field.findElements('verse');
        if (verseEls.isNotEmpty) {
          for (final verseEl in verseEls) {
            final Map<String, String> set = {};
            for (final node in verseEl.children) {
              if (node is XmlElement) {
                set[node.name.local] = node.innerText.trim();
              }
            }
            sets.add(set);
          }
          continue;
        }

        // Fallback: Semi-colon format
        final content = field.innerText.trim();
        if (content.isEmpty) continue;
        
        try {
          final parts = content.split(';');
          for (final part in parts) {
            final eqIdx = part.indexOf('=');
            if (eqIdx == -1) continue;
            
            final fullKey = part.substring(0, eqIdx).trim();
            final value = part.substring(eqIdx + 1).trim();
            
            final match = RegExp(r'vars\[(\d+)\]\.(.+)').firstMatch(fullKey);
            if (match != null) {
              final index = int.parse(match.group(1)!);
              final key = match.group(2)!;
              
              while (sets.length <= index) {
                sets.add({});
              }
              sets[index][key] = value;
            }
          }
        } catch (e) {
          // ignore malformed content
        }
      }
    }

    // 2. Check for individual fields (Transition format)
    for (final field in root.findAllElements('miscellaneous-field')) {
      final name = field.getAttribute('name') ?? '';
      if (name.startsWith('vars[')) {
        // format: vars[0].animal = cow
        final match = RegExp(r'vars\[(\d+)\]\.(.+)').firstMatch(name);
        if (match != null) {
          final index = int.parse(match.group(1)!);
          final key = match.group(2)!;
          final value = field.innerText.trim();
          
          while (sets.length <= index) {
            sets.add({});
          }
          // Only add if not already set by the new format
          if (!sets[index].containsKey(key)) {
            sets[index][key] = value;
          }
        }
      }
    }
    return (sets, defaultSet);
  }

  static String _getTitle(XmlElement root) {
    return root
            .findAllElements('work-title')
            .firstOrNull
            ?.innerText
            .trim() ??
        root
            .findAllElements('movement-title')
            .firstOrNull
            ?.innerText
            .trim() ??
        '';
  }

  static String _getComposer(XmlElement root) {
    for (final creator in root.findAllElements('creator')) {
      final type = creator.getAttribute('type') ?? '';
      if (type.toLowerCase() == 'composer' || type.isEmpty) {
        return creator.innerText.trim();
      }
    }
    return '';
  }

  static List<Measure> _parseMeasures(XmlElement root) {
    final measures = <Measure>[];

    // For partwise score, use measures from the first part.
    final parts = root.findElements('part').toList();
    if (parts.isEmpty) return measures;

    // Use the first part (typically melody).
    final firstPart = parts.first;

    int currentBeats = 4;
    int currentBeatType = 4;
    int currentDivisions = 1;

    for (final measureEl in firstPart.findElements('measure')) {
      final numberStr = measureEl.getAttribute('number') ?? '0';
      final number = int.tryParse(numberStr) ?? 0;
      final isImplicit = measureEl.getAttribute('implicit') == 'yes';
      final attribEl = measureEl.findElements('attributes').firstOrNull;
      if (attribEl != null) {
        final divisionsEl = attribEl.findElements('divisions').firstOrNull;
        if (divisionsEl != null) {
          currentDivisions = int.tryParse(divisionsEl.innerText) ?? 1;
        }
        final timeEl = attribEl.findElements('time').firstOrNull;
        if (timeEl != null) {
          currentBeats =
              int.tryParse(timeEl.findElements('beats').firstOrNull?.innerText ?? '4') ?? 4;
          currentBeatType =
              int.tryParse(timeEl.findElements('beat-type').firstOrNull?.innerText ?? '4') ??
                  4;
        }
      }

      final notes = <MusicNote>[];
      for (final noteEl in measureEl.findElements('note')) {
        final note = _parseNote(noteEl, currentDivisions);
        notes.add(note);
      }

      measures.add(Measure(
        number: number,
        notes: notes,
        beats: currentBeats,
        beatType: currentBeatType,
        isPickup: isImplicit || (number == 0 && measures.isEmpty),
      ));
    }

    return measures;
  }

  static MusicNote _parseNote(XmlElement noteEl, int divisions) {
    final isRest = noteEl.findElements('rest').isNotEmpty;
    final isChord = noteEl.findElements('chord').isNotEmpty;
    final dotCount = noteEl.findElements('dot').length;

    // Tie handling
    final tieEls = noteEl.findElements('tie');
    bool isTied = false;
    bool isTiedToPrevious = false;
    for (final tie in tieEls) {
      final type = tie.getAttribute('type');
      if (type == 'start') {
        isTied = true;
      } else if (type == 'stop') {
        isTiedToPrevious = true;
      }
    }

    final pitchEl = noteEl.findElements('pitch').firstOrNull;
    final step = pitchEl?.findElements('step').firstOrNull?.innerText.trim() ?? 'C';
    final octave = int.tryParse(
            pitchEl?.findElements('octave').firstOrNull?.innerText ?? '4') ??
        4;
    final alter = double.tryParse(
            pitchEl?.findElements('alter').firstOrNull?.innerText ?? '0') ??
        0.0;

    final durationText =
        noteEl.findElements('duration').firstOrNull?.innerText.trim() ?? '1';
    final rawDuration = double.tryParse(durationText) ?? 1.0;
    final duration = rawDuration / divisions;

    final typeText =
        noteEl.findElements('type').firstOrNull?.innerText.trim() ?? 'quarter';

    final beamEl = noteEl.findElements('beam').firstOrNull;
    final beam = beamEl?.innerText.trim();

    final lyrics = <int, String>{};
    for (final lyricEl in noteEl.findElements('lyric')) {
      final numberStr = lyricEl.getAttribute('number') ?? '1';
      final number = int.tryParse(numberStr) ?? 1;
      final text = lyricEl.findElements('text').firstOrNull?.innerText.trim() ?? '';
      if (text.isNotEmpty) {
        lyrics[number] = text;
      }
    }

    return MusicNote(
      step: step,
      octave: octave,
      alter: alter,
      duration: duration,
      type: typeText,
      isRest: isRest,
      isChordContinuation: isChord,
      dot: dotCount,
      beam: beam,
      isTied: isTied,
      isTiedToPrevious: isTiedToPrevious,
      lyrics: lyrics,
    );
  }
}
