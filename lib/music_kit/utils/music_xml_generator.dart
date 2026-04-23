import '../models/song.dart';
import '../models/measure.dart';
import '../models/music_note.dart';

/// Utility to generate MusicXML content from a [Song] model.
class MusicXmlGenerator {
  MusicXmlGenerator._();

  static String generate(Song song) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">');
    buffer.writeln('<score-partwise version="4.0">');
    
    // Work/Movement Title
    buffer.writeln('  <work>');
    buffer.writeln('    <work-title>${_escape(song.title)}</work-title>');
    buffer.writeln('  </work>');
    
    // Identification / Composer
    buffer.writeln('  <identification>');
    buffer.writeln('    <creator type="composer">${_escape(song.composer)}</creator>');
    buffer.writeln('    <encoding>');
    buffer.writeln('      <software>Flutter Music Editor</software>');
    buffer.writeln('      <encoding-date>${DateTime.now().toIso8601String().split('T')[0]}</encoding-date>');
    buffer.writeln('    </encoding>');
    buffer.writeln('  </identification>');

    // Part List
    buffer.writeln('  <part-list>');
    buffer.writeln('    <score-part id="P1">');
    buffer.writeln('      <part-name>${_escape(song.title)}</part-name>');
    buffer.writeln('    </score-part>');
    buffer.writeln('  </part-list>');

    // Part
    buffer.writeln('  <part id="P1">');
    
    int currentBeats = -1;
    int currentBeatType = -1;
    int currentDivisions = 4; // Standard: 4 divisions per quarter note

    for (var i = 0; i < song.measures.length; i++) {
      final measure = song.measures[i];
      buffer.writeln('    <measure number="${measure.number}">');

      // Attributes (only if changed or first measure)
      final timeChanged = measure.beats != currentBeats || measure.beatType != currentBeatType;
      if (i == 0 || timeChanged) {
        buffer.writeln('      <attributes>');
        if (i == 0) {
          buffer.writeln('        <divisions>$currentDivisions</divisions>');
          buffer.writeln('        <key>');
          buffer.writeln('          <fifths>0</fifths>');
          buffer.writeln('        </key>');
          buffer.writeln('        <clef>');
          buffer.writeln('          <sign>G</sign>');
          buffer.writeln('          <line>2</line>');
          buffer.writeln('        </clef>');
        }
        if (timeChanged) {
          buffer.writeln('        <time>');
          buffer.writeln('          <beats>${measure.beats}</beats>');
          buffer.writeln('          <beat-type>${measure.beatType}</beat-type>');
          buffer.writeln('        </time>');
          currentBeats = measure.beats;
          currentBeatType = measure.beatType;
        }
        buffer.writeln('      </attributes>');
      }

      for (final note in measure.notes) {
        buffer.writeln('      <note>');
        if (note.isRest) {
          buffer.writeln('        <rest/>');
        } else {
          buffer.writeln('        <pitch>');
          buffer.writeln('          <step>${note.step}</step>');
          if (note.alter != 0) {
            buffer.writeln('          <alter>${note.alter.toInt()}</alter>');
          }
          buffer.writeln('          <octave>${note.octave}</octave>');
          buffer.writeln('        </pitch>');
        }
        
        // duration in divisions = note.duration * divisions (where 1.0 is quarter)
        final durationInDivisions = (note.duration * currentDivisions).round();
        buffer.writeln('        <duration>$durationInDivisions</duration>');
        buffer.writeln('        <type>${note.type}</type>');
        if (note.isDotted) {
          buffer.writeln('        <dot/>');
        }
        if (note.isChordContinuation) {
          buffer.writeln('        <chord/>');
        }
        if (note.beam != null) {
          buffer.writeln('        <beam number="1">${note.beam}</beam>');
        }
        buffer.writeln('      </note>');
      }
      buffer.writeln('    </measure>');
    }

    buffer.writeln('  </part>');
    buffer.writeln('</score-partwise>');
    return buffer.toString();
  }

  static String _escape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
