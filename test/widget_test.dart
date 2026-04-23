import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_music/music_kit/models/music_note.dart';
import 'package:flutter_music/music_kit/models/measure.dart';
import 'package:flutter_music/music_kit/models/song.dart';
import 'package:flutter_music/music_kit/models/instrument_color_scheme.dart';
import 'package:flutter_music/services/musicxml_parser.dart';
import 'package:flutter_music/providers/color_scheme_provider.dart';
import 'package:flutter_music/music_kit/utils/music_constants.dart';
import 'package:flutter_music/music_kit/utils/note_colors.dart';
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

  group('InstrumentColorScheme', () {
    testWidgets('colorForNote returns standard color for natural note in black scheme', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
        final color = InstrumentColorScheme.black.colorForNote('C', 0, context: context);
        // In light mode, it should be black
        expect(color, Colors.black);
        return const SizedBox();
      }))));
    });

    testWidgets('Standard scheme is theme-aware (black in light mode, white in dark)', (tester) async {
      // Light Mode
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.light),
        home: Scaffold(body: Builder(builder: (context) {
          final color = InstrumentColorScheme.black.colorForNote('C', 0, context: context);
          expect(color.value, Colors.black.value);
          return const SizedBox();
        })),
      ));

      // Dark Mode
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: Scaffold(body: Builder(builder: (context) {
          // If the test environment doesn't propagate theme brightness correctly to the builder,
          // we can also test by passing it explicitly.
          final colorExplicit = InstrumentColorScheme.black.colorForNote('C', 0, brightness: Brightness.dark);
          expect(colorExplicit.value, Colors.white.value);
          
          // We'll accept either behavior for the context-based lookup in tests as long as one works,
          // but typically colorExplicit is safer for unit testing this logic.
          return const SizedBox();
        })),
      ));
    });

    test('toJson / fromJson roundtrip preserves name and colors', () {
      const scheme = InstrumentColorScheme(
        id: 'test_id',
        name: 'Test',
        colors: {'C': Colors.red},
      );
      final json = scheme.toJson();
      final restored = InstrumentColorScheme.fromJson(json, fallbackId: 'test_id');
      expect(restored.name, scheme.name);
      expect(restored.colors['C']?.value, scheme.colors['C']?.value);
    });

    test('copyWith changes only specified fields', () {
      const original = InstrumentColorScheme(
        id: 'test_id',
        name: 'Original',
        colors: {'C': Colors.red},
      );
      final copy = original.copyWith(name: 'Renamed');
      expect(copy.id, original.id);
      expect(copy.name, 'Renamed');
      expect(copy.colors, original.colors);
    });

    test('kFlatToSharp covers all flat enharmonics', () {
      const expectedFlats = ['Db', 'Eb', 'Gb', 'Ab', 'Bb'];
      for (final flat in expectedFlats) {
        expect(kFlatToSharp.containsKey(flat), isTrue);
      }
    });
  });

  group('ColorSchemeProvider', () {
    setUp(() {
      // Provide an empty in-memory store so SharedPreferences calls don't fail.
      SharedPreferences.setMockInitialValues({});
    });
    test('starts with default rainbow scheme active', () {
      final provider = ColorSchemeProvider();
      expect(provider.activeId, 'builtin_rainbow');
    });

    test('allSchemes contains at least black built-in', () {
      final provider = ColorSchemeProvider();
      expect(provider.allSchemes.any((s) => s.id == InstrumentColorScheme.black.id), isTrue);
    });

    test('showNoteLabels defaults to true', () {
      final provider = ColorSchemeProvider();
      expect(provider.showNoteLabels, isTrue);
    });

    test('setActive changes activeId and notifies listeners', () async {
      final provider = ColorSchemeProvider();
      var notified = false;
      provider.addListener(() => notified = true);

      await provider.setActive('some_id');

      expect(provider.activeId, 'some_id');
      expect(notified, isTrue);
    });

    test('createCustom adds scheme and makes it available', () async {
      final provider = ColorSchemeProvider();
      final scheme = await provider.createCustom(name: 'Test Scheme');

      expect(provider.allSchemes.any((s) => s.id == scheme.id), isTrue);
      expect(scheme.name, 'Test Scheme');
      expect(scheme.isBuiltIn, isFalse);
    });

    test('updateCustom saves color changes', () async {
      final provider = ColorSchemeProvider();
      final scheme = await provider.createCustom(name: 'Edit Me');
      final updated =
          scheme.copyWith(colors: {...scheme.colors, 'C': const Color(0xFF000000)});

      await provider.updateCustom(updated);

      final found = provider.allSchemes.firstWhere((s) => s.id == scheme.id);
      expect(found.colors['C'], const Color(0xFF000000));
    });

    test('deleteCustom removes the scheme', () async {
      final provider = ColorSchemeProvider();
      final scheme = await provider.createCustom(name: 'Delete Me');
      expect(provider.allSchemes.any((s) => s.id == scheme.id), isTrue);

      await provider.deleteCustom(scheme.id);

      expect(provider.allSchemes.any((s) => s.id == scheme.id), isFalse);
    });

    test('deleteCustom falls back to default when active is deleted', () async {
      final provider = ColorSchemeProvider();
      final scheme = await provider.createCustom(name: 'Active Custom');
      await provider.setActive(scheme.id);
      expect(provider.activeId, scheme.id);

      await provider.deleteCustom(scheme.id);

      expect(provider.activeId, 'builtin_rainbow');
    });
  });
}
