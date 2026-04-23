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

    final scorePartwise = document.findElements('score-partwise').firstOrNull;
    final scoreTimewise = document.findElements('score-timewise').firstOrNull;
    final root = scorePartwise ?? scoreTimewise;
    if (root == null) {
      throw const FormatException('Not a valid MusicXML file');
    }

    final title = _getTitle(root);
    final composer = _getComposer(root);
    final tempo = _getTempo(root);
    final measures = _parseMeasures(root);

    return Song(
      id: id,
      title: title.isNotEmpty ? title : 'Untitled',
      composer: composer,
      measures: measures,
      tags: tags,
      library: library,
      localPath: localPath,
      sourceUrl: sourceUrl,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  static double _getTempo(XmlElement root) {
    final metronome = root.findAllElements('metronome').firstOrNull;
    if (metronome != null) {
      final beatUnit = metronome.findElements('beat-unit').firstOrNull?.innerText ?? 'quarter';
      final perMinute = double.tryParse(metronome.findElements('per-minute').firstOrNull?.innerText ?? '120') ?? 120.0;
      // Simple conversion for now: assuming 4/4 and metronome is usually quarter note.
      return perMinute;
    }
    final sound = root.findAllElements('sound').firstOrNull;
    if (sound != null) {
      final tempoAttr = sound.getAttribute('tempo');
      if (tempoAttr != null) {
        return double.tryParse(tempoAttr) ?? 120.0;
      }
    }
    return 120.0;
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

      // Update time/key attributes if present.
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
    for (final tie in tieEls) {
      if (tie.getAttribute('type') == 'start') {
        isTied = true;
        break;
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
    );
  }
}
