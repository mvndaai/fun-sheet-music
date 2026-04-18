import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_music/models/music_note.dart';
import 'package:flutter_music/models/measure.dart';
import 'package:flutter_music/models/song.dart';
import 'package:flutter_music/services/musicxml_parser.dart';
import 'package:flutter_music/utils/music_constants.dart';
import 'package:flutter_music/utils/note_colors.dart';
import 'package:flutter/material.dart';

void main() {
  group('MusicNote', () {
    test('letter name for natural note', () {
      const note = MusicNote(step: 'C', octave: 4, duration: 1, type: 'quarter');
      expect(note.letterName, 'C4');
    });

    test('letter name for sharp', () {
      const note = MusicNote(step: 'F', octave: 5, duration: 1, type: 'quarter', alter: 1);
      expect(note.letterName, 'F#5');
    });

    test('letter name for flat', () {
      const note = MusicNote(step: 'B', octave: 3, duration: 1, type: 'quarter', alter: -1);
      expect(note.letterName, 'Bb3');
    });

    test('solfege name for C', () {
      const note = MusicNote(step: 'C', octave: 4, duration: 1, type: 'quarter');
      expect(note.solfegeName, 'Do');
    });

    test('solfege name for G', () {
      const note = MusicNote(step: 'G', octave: 5, duration: 1, type: 'quarter');
      expect(note.solfegeName, 'Sol');
    });

    test('MIDI number for C4', () {
      const note = MusicNote(step: 'C', octave: 4, duration: 1, type: 'quarter');
      expect(note.midiNumber, 60);
    });

    test('MIDI number for A4', () {
      const note = MusicNote(step: 'A', octave: 4, duration: 1, type: 'quarter');
      expect(note.midiNumber, 69);
    });

    test('MIDI number for C#4', () {
      const note = MusicNote(step: 'C', octave: 4, duration: 1, type: 'quarter', alter: 1);
      expect(note.midiNumber, 61);
    });

    test('frequency for A4 is approximately 440 Hz', () {
      const note = MusicNote(step: 'A', octave: 4, duration: 1, type: 'quarter');
      expect(note.frequency, closeTo(440.0, 1.0));
    });

    test('rest note', () {
      const note = MusicNote(step: 'C', octave: 4, duration: 1, type: 'quarter', isRest: true);
      expect(note.isRest, isTrue);
      expect(note.letterName, 'Rest');
      expect(note.solfegeName, 'Rest');
      expect(note.midiNumber, -1);
    });
  });

  group('Measure', () {
    test('playableNotes excludes rests', () {
      const notes = [
        MusicNote(step: 'C', octave: 5, duration: 1, type: 'quarter'),
        MusicNote(step: 'C', octave: 5, duration: 1, type: 'quarter', isRest: true),
        MusicNote(step: 'G', octave: 5, duration: 1, type: 'quarter'),
      ];
      const measure = Measure(number: 1, notes: notes);
      expect(measure.playableNotes.length, 2);
    });

    test('playableNotes excludes chord continuations', () {
      const notes = [
        MusicNote(step: 'C', octave: 5, duration: 1, type: 'quarter'),
        MusicNote(step: 'E', octave: 5, duration: 1, type: 'quarter', isChordContinuation: true),
        MusicNote(step: 'G', octave: 5, duration: 1, type: 'quarter'),
      ];
      const measure = Measure(number: 1, notes: notes);
      expect(measure.playableNotes.length, 2);
    });
  });

  group('MusicXmlParser', () {
    const sampleXml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="3.1">
  <work><work-title>Test Song</work-title></work>
  <identification>
    <creator type="composer">Test Composer</creator>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Music</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <key><fifths>0</fifths></key>
        <time><beats>4</beats><beat-type>4</beat-type></time>
        <clef><sign>G</sign><line>2</line></clef>
      </attributes>
      <note>
        <pitch><step>C</step><octave>5</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <pitch><step>G</step><octave>5</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
      </note>
      <note>
        <rest/>
        <duration>2</duration>
        <type>half</type>
      </note>
    </measure>
  </part>
</score-partwise>''';

    test('parses title and composer', () {
      final song = MusicXmlParser.parse(sampleXml, id: 'test-id');
      expect(song.title, 'Test Song');
      expect(song.composer, 'Test Composer');
    });

    test('parses measures', () {
      final song = MusicXmlParser.parse(sampleXml, id: 'test-id');
      expect(song.measures.length, 1);
    });

    test('parses notes correctly', () {
      final song = MusicXmlParser.parse(sampleXml, id: 'test-id');
      final notes = song.measures.first.notes;
      expect(notes.length, 3);
      expect(notes[0].step, 'C');
      expect(notes[0].octave, 5);
      expect(notes[0].isRest, false);
      expect(notes[2].isRest, true);
    });

    test('allNotes returns only playable notes', () {
      final song = MusicXmlParser.parse(sampleXml, id: 'test-id');
      expect(song.allNotes.length, 2); // C and G, not the rest
    });

    test('throws on invalid XML', () {
      expect(
        () => MusicXmlParser.parse('<invalid/>', id: 'bad'),
        throwsA(isA<FormatException>()),
      );
    });

    test('tags and id are stored', () {
      final song = MusicXmlParser.parse(
        sampleXml,
        id: 'my-id',
        tags: ['kids', 'easy'],
      );
      expect(song.id, 'my-id');
      expect(song.tags, containsAll(['kids', 'easy']));
    });
  });

  group('Song', () {
    test('toJson / fromJson roundtrip', () {
      final song = Song(
        id: 'abc',
        title: 'My Song',
        composer: 'Bach',
        measures: [],
        tags: ['classical', 'kids'],
        localPath: '/path/to/file.xml',
        createdAt: DateTime(2024, 1, 15),
      );
      final json = song.toJson();
      final restored = Song.fromJson(json);
      expect(restored.id, song.id);
      expect(restored.title, song.title);
      expect(restored.composer, song.composer);
      expect(restored.tags, song.tags);
      expect(restored.localPath, song.localPath);
      expect(restored.createdAt, song.createdAt);
    });

    test('copyWith changes only specified fields', () {
      final song = Song(
        id: 'abc',
        title: 'Original',
        measures: [],
        tags: ['a'],
        createdAt: DateTime.now(),
      );
      final copy = song.copyWith(title: 'New Title', tags: ['b', 'c']);
      expect(copy.id, song.id);
      expect(copy.title, 'New Title');
      expect(copy.tags, ['b', 'c']);
    });
  });

  group('NoteColors', () {
    test('C is red', () {
      final color = NoteColors.forNote('C', 0);
      expect(color, const Color(0xFFE53935));
    });

    test('sharp note returns different color from natural', () {
      final natural = NoteColors.forNote('C', 0);
      final sharp = NoteColors.forNote('C', 1);
      expect(natural == sharp, isFalse);
    });

    test('restColor is grey', () {
      expect(NoteColors.restColor.computeLuminance(), greaterThan(0.3));
    });

    test('textColorFor light background is dark', () {
      const lightColor = Color(0xFFFFFF00); // yellow
      expect(NoteColors.textColorFor(lightColor), Colors.black87);
    });

    test('textColorFor dark background is light', () {
      const darkColor = Color(0xFF1565C0); // dark blue
      expect(NoteColors.textColorFor(darkColor), Colors.white);
    });
  });

  group('MusicConstants', () {
    test('frequencyToNoteName for A4 (440 Hz)', () {
      final name = MusicConstants.frequencyToNoteName(440.0);
      expect(name, 'A4');
    });

    test('frequencyToNoteName for C4 (~261.63 Hz)', () {
      final name = MusicConstants.frequencyToNoteName(261.63);
      expect(name, 'C4');
    });

    test('frequencyToMidi for A4 is 69', () {
      final midi = MusicConstants.frequencyToMidi(440.0);
      expect(midi, 69);
    });

    test('frequencyToMidi for C4 is 60', () {
      final midi = MusicConstants.frequencyToMidi(261.63);
      expect(midi, 60);
    });

    test('stepToSolfege maps all 7 notes', () {
      expect(MusicConstants.stepToSolfege.length, 7);
      expect(MusicConstants.stepToSolfege['C'], 'Do');
      expect(MusicConstants.stepToSolfege['G'], 'Sol');
    });
  });
}
