import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/measure.dart';
import '../models/music_note.dart';
import '../models/instrument_color_scheme.dart';
import '../sheet_music_constants.dart';
import 'staff_painter.dart';

/// A decoupled widget that renders full sheet music.
class SheetMusicRenderer extends StatelessWidget {
  final Song song;
  final int activeNoteIndex;
  final int? ghostNoteIndex;
  final MusicNote? ghostNote;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final int measuresPerRow;
  final InstrumentColorScheme colorScheme;
  final bool showNoteLabels;
  final Widget? header;

  const SheetMusicRenderer({
    super.key,
    required this.song,
    required this.colorScheme,
    this.activeNoteIndex = -1,
    this.ghostNoteIndex,
    this.ghostNote,
    this.showSolfege = false,
    this.showLetter = true,
    this.labelsBelow = true,
    this.coloredLabels = false,
    this.measuresPerRow = 4,
    this.showNoteLabels = true,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    if (song.measures.isEmpty) {
      return const Center(child: Text('No notes found in this song.'));
    }

    final rows = _buildRows();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          ...rows.map(
            (row) => _StaffRow(
              row: row,
              activeNoteIndex: activeNoteIndex,
              ghostNoteIndex: ghostNoteIndex,
              ghostNote: ghostNote,
              showSolfege: showSolfege,
              showLetter: showLetter,
              labelsBelow: labelsBelow,
              coloredLabels: coloredLabels,
              colorScheme: colorScheme,
              showNoteLabels: showNoteLabels,
            ),
          ),
        ],
      ),
    );
  }

  List<StaffRowData> _buildRows() {
    final rows = <StaffRowData>[];
    int noteOffset = 0;
    Measure? prevMeasure;
    for (int i = 0; i < song.measures.length; i += measuresPerRow) {
      final end = (i + measuresPerRow).clamp(0, song.measures.length);
      final batch = song.measures.sublist(i, end);
      rows.add(StaffRowData(
        measures: batch,
        firstNoteIndex: noteOffset,
        isFirstRow: i == 0,
        isLastRow: end == song.measures.length,
        measuresPerRow: measuresPerRow,
        previousMeasure: prevMeasure,
      ));
      noteOffset += batch.fold(0, (s, m) => s + m.playableNotes.length);
      prevMeasure = batch.last;
    }
    return rows;
  }
}

class _StaffRow extends StatelessWidget {
  final StaffRowData row;
  final int activeNoteIndex;
  final int? ghostNoteIndex;
  final MusicNote? ghostNote;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final InstrumentColorScheme colorScheme;
  final bool showNoteLabels;

  const _StaffRow({
    required this.row,
    required this.activeNoteIndex,
    this.ghostNoteIndex,
    this.ghostNote,
    required this.showSolfege,
    required this.showLetter,
    required this.labelsBelow,
    required this.coloredLabels,
    required this.colorScheme,
    required this.showNoteLabels,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: kRowH,
          width: constraints.maxWidth,
          child: CustomPaint(
            painter: StaffPainter(
              row: row,
              activeNoteIndex: activeNoteIndex,
              ghostNoteIndex: ghostNoteIndex,
              ghostNote: ghostNote,
              showSolfege: showSolfege,
              showLetter: showLetter,
              labelsBelow: labelsBelow,
              coloredLabels: coloredLabels,
              colorScheme: colorScheme,
              showNoteLabels: showNoteLabels,
              context: context,
            ),
          ),
        ),
      ),
    );
  }
}
