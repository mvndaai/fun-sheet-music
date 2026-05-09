import 'package:flutter_test/flutter_test.dart';
import 'package:fun_sheet_music/services/musicxml_parser.dart';
import 'package:fun_sheet_music/music_kit/models/music_note.dart';

void main() {
  group('Lyrics and Variables Parsing', () {
    const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <identification>
    <miscellaneous>
      <miscellaneous-field name="variables">
        <verse>
          <animal>cow</animal>
          <sound>moo</sound>
        </verse>
        <verse>
          <animal>pig</animal>
          <sound>oink</sound>
        </verse>
      </miscellaneous-field>
    </miscellaneous>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Test</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
        <time><beats>4</beats><beat-type>4</beat-type></time>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <type>quarter</type>
        <lyric number="1"><text>had a {{animal}}</text></lyric>
        <lyric number="99"><text>final verse</text></lyric>
      </note>
    </measure>
  </part>
</score-partwise>''';

    test('should parse structured variables from nested XML and lyrics', () {
      final song = MusicXmlParser.parse(xml, id: 'test');
      expect(song.lyricsVariableSets.length, equals(2));
      expect(song.lyricsVariableSets[0]['animal'], equals('cow'));
      expect(song.lyricsVariableSets[1]['animal'], equals('pig'));
      
      final note = song.measures.first.notes.first;
      expect(note.lyrics[1], equals('had a {{animal}}'));
      expect(note.lyrics[99], equals('final verse'));
    });

    test('should resolve variable sets correctly', () {
      final song = MusicXmlParser.parse(xml, id: 'test');
      final note = song.measures.first.notes.first;
      
      // Verse 1
      expect(note.getResolvedLyric(1, {}, variableSets: song.lyricsVariableSets), equals('had a cow'));
      
      // Verse 2
      expect(note.getResolvedLyric(2, {}, variableSets: song.lyricsVariableSets), equals('had a pig'));
      
      // Last verse logic (Verse 2 is total verses)
      expect(note.getResolvedLyric(2, {}, isLastVerse: true, variableSets: song.lyricsVariableSets), equals('final verse'));
    });

    test('should handle missing variables gracefully', () {
      const note = MusicNote(
        step: 'C', octave: 4, duration: 1, type: 'quarter',
        lyrics: {1: 'hello {{name}}'}
      );
      expect(note.getResolvedLyric(1, {}), equals('hello {{name}}'));
    });

    test('should support default variables', () {
      const xmlWithDefault = '''<?xml version="1.0" encoding="UTF-8"?>
<score-partwise version="4.0">
  <identification>
    <miscellaneous>
      <miscellaneous-field name="variables">
        <default>
          <ending>town</ending>
        </default>
        <verse>
          <subject>wheels</subject>
        </verse>
        <verse>
          <subject>horn</subject>
          <ending>farm</ending>
        </verse>
      </miscellaneous-field>
    </miscellaneous>
  </identification>
  <part-list>
    <score-part id="P1"><part-name>Test</part-name></score-part>
  </part-list>
  <part id="P1">
    <measure number="1">
      <attributes>
        <divisions>1</divisions>
      </attributes>
      <note>
        <pitch><step>C</step><octave>4</octave></pitch>
        <duration>1</duration>
        <lyric number="1"><text>{{subject}} in {{ending}}</text></lyric>
      </note>
    </measure>
  </part>
</score-partwise>''';

      final song = MusicXmlParser.parse(xmlWithDefault, id: 'test');
      expect(song.defaultLyricsVariables['ending'], equals('town'));
      
      final note = song.measures.first.notes.first;

      expect(note.getResolvedLyric(1, {}, variableSets: song.lyricsVariableSets, defaultVariableSet: song.defaultLyricsVariables), equals('wheels in town'));
      expect(note.getResolvedLyric(2, {}, variableSets: song.lyricsVariableSets, defaultVariableSet: song.defaultLyricsVariables), equals('horn in farm'));
    });
  });
}
