import 'package:flutter/material.dart';
import '../models/song.dart';
import '../models/measure.dart';
import '../models/music_note.dart';
import '../models/instrument_profile.dart';
import '../sheet_music_constants.dart';
import 'staff_painter.dart';

/// A decoupled widget that renders full sheet music.
class SheetMusicRenderer extends StatefulWidget {
  final Song song;
  final int activeNoteIndex;
  final int? ghostNoteIndex;
  final MusicNote? ghostNote;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final int measuresPerRow;
  final InstrumentProfile instrument;
  final bool showNoteLabels;
  final Widget? header;
  final bool includePickupInFirstRow;

  const SheetMusicRenderer({
    super.key,
    required this.instrument,
    required this.song,
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
    this.includePickupInFirstRow = true,
  });

  @override
  State<SheetMusicRenderer> createState() => _SheetMusicRendererState();
}

class _SheetMusicRendererState extends State<SheetMusicRenderer> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _rowKeys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final int targetIndex = widget.activeNoteIndex >= 0 ? widget.activeNoteIndex : (widget.ghostNoteIndex ?? -1);
      if (targetIndex >= 0) {
        _scrollToIndex(targetIndex);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SheetMusicRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);

    final int targetIndex = widget.activeNoteIndex >= 0 ? widget.activeNoteIndex : (widget.ghostNoteIndex ?? -1);
    final int oldTargetIndex = oldWidget.activeNoteIndex >= 0 ? oldWidget.activeNoteIndex : (oldWidget.ghostNoteIndex ?? -1);

    // Scroll if the target note moves, or if the song structure changes (e.g. new measures)
    if (targetIndex != oldTargetIndex || widget.song.measures.length != oldWidget.song.measures.length) {
      if (targetIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToIndex(targetIndex);
        });
      }
    }
  }

  void _scrollToIndex(int noteIndex) {
    if (!mounted) return;
    final rows = _buildRows();
    
    // Ensure we have enough keys for all rows before calculating scroll
    while (_rowKeys.length < rows.length) {
      _rowKeys.add(GlobalKey());
    }

    int rowIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final int rowNoteCount = row.measures.fold(0, (s, m) => s + m.notes.length);
      
      // If noteIndex is within this row's range
      if (noteIndex >= row.firstNoteIndex && noteIndex < row.firstNoteIndex + rowNoteCount) {
        rowIndex = i;
        break;
      }
      // Handle the insertion point at the start of a new row
      if (noteIndex == row.firstNoteIndex) {
        rowIndex = i;
        break;
      }
      // Handle the insertion point at the very end of the song
      if (noteIndex == row.firstNoteIndex + rowNoteCount && row.isLastRow) {
        rowIndex = i;
      }
    }

    if (rowIndex >= 0 && rowIndex < _rowKeys.length) {
      final key = _rowKeys[rowIndex];
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.song.measures.isEmpty) {
      return const Center(child: Text('No notes found in this song.'));
    }

    final rows = _buildRows();
    
    // Ensure we have enough keys for all rows
    while (_rowKeys.length < rows.length) {
      _rowKeys.add(GlobalKey());
    }

    return Scrollbar(
      controller: _scrollController,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.header != null) widget.header!,
            ...List.generate(rows.length, (i) {
              final row = rows[i];
              return _StaffRow(
                key: _rowKeys[i],
                row: row,
                activeNoteIndex: widget.activeNoteIndex,
                ghostNoteIndex: widget.ghostNoteIndex,
                ghostNote: widget.ghostNote,
                showSolfege: widget.showSolfege,
                showLetter: widget.showLetter,
                labelsBelow: widget.labelsBelow,
                coloredLabels: widget.coloredLabels,
                instrument: widget.instrument,
                showNoteLabels: widget.showNoteLabels,
              );
            }),
          ],
        ),
      ),
    );
  }

  List<StaffRowData> _buildRows() {
    final rows = <StaffRowData>[];
    int noteOffset = 0;
    Measure? prevMeasure;

    int i = 0;
    while (i < widget.song.measures.length) {
      int count = widget.measuresPerRow;
      // If this is the first row and we have a pickup, and the option is enabled,
      // we add one to the count so the pickup is "extra".
      if (i == 0 && widget.includePickupInFirstRow && widget.song.measures.isNotEmpty && widget.song.measures[0].isPickup) {
        count++;
      }

      final end = (i + count).clamp(0, widget.song.measures.length);
      final batch = widget.song.measures.sublist(i, end);
      rows.add(StaffRowData(
        measures: batch,
        firstNoteIndex: noteOffset,
        isFirstRow: i == 0,
        isLastRow: end == widget.song.measures.length,
        measuresPerRow: count, // use the actual count for this row
        previousMeasure: prevMeasure,
      ));
      noteOffset += batch.fold(0, (s, m) => s + m.notes.length);
      prevMeasure = batch.last;
      i = end;
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
  final InstrumentProfile instrument;
  final bool showNoteLabels;

  const _StaffRow({
    super.key,
    required this.row,
    required this.activeNoteIndex,
    this.ghostNoteIndex,
    this.ghostNote,
    required this.showSolfege,
    required this.showLetter,
    required this.labelsBelow,
    required this.coloredLabels,
    required this.instrument,
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
              instrument: instrument,
              showNoteLabels: showNoteLabels,
              context: context,
            ),
          ),
        ),
      ),
    );
  }
}
