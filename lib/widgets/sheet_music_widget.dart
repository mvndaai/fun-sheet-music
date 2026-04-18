import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/music_note.dart';
import '../models/measure.dart';
import '../providers/color_scheme_provider.dart';
import '../utils/music_constants.dart';
import '../utils/note_colors.dart';
import 'note_widget.dart';

/// Displays the full sheet music for a song with color-coded notes.
class SheetMusicWidget extends StatelessWidget {
  final Song song;
  final int activeNoteIndex; // Index into song.allNotes; -1 = none highlighted
  final bool showSolfege;
  final bool showLetter;
  final int measuresPerRow;

  const SheetMusicWidget({
    super.key,
    required this.song,
    this.activeNoteIndex = -1,
    this.showSolfege = false,
    this.showLetter = true,
    this.measuresPerRow = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (song.measures.isEmpty) {
      return const Center(child: Text('No notes found in this song.'));
    }

    final allNotes = song.allNotes;
    int globalNoteIndex = 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Song header
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (song.composer.isNotEmpty)
                  Text(
                    song.composer,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
          ),
          const Divider(),

          // Note color legend
          _ColorLegend(showSolfege: showSolfege),
          const SizedBox(height: 12),

          // Measures
          ...List.generate(
            ((song.measures.length + measuresPerRow - 1) / measuresPerRow)
                .ceil(),
            (rowIndex) {
              final start = rowIndex * measuresPerRow;
              final end =
                  (start + measuresPerRow).clamp(0, song.measures.length);
              final rowMeasures = song.measures.sublist(start, end);

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: rowMeasures.map((measure) {
                    final widget = _MeasureWidget(
                      measure: measure,
                      allNotes: allNotes,
                      startNoteIndex: globalNoteIndex,
                      activeNoteIndex: activeNoteIndex,
                      showSolfege: showSolfege,
                      showLetter: showLetter,
                    );
                    globalNoteIndex += measure.playableNotes.length;
                    return Expanded(child: widget);
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Displays a single measure of notes.
class _MeasureWidget extends StatelessWidget {
  final Measure measure;
  final List<MusicNote> allNotes;
  final int startNoteIndex;
  final int activeNoteIndex;
  final bool showSolfege;
  final bool showLetter;

  const _MeasureWidget({
    required this.measure,
    required this.allNotes,
    required this.startNoteIndex,
    required this.activeNoteIndex,
    required this.showSolfege,
    required this.showLetter,
  });

  @override
  Widget build(BuildContext context) {
    final playable = measure.playableNotes;
    // Include rests for display
    final displayNotes = measure.notes
        .where((n) => !n.isChordContinuation)
        .toList();
    int playableOffset = 0;

    return Container(
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.grey.shade400, width: 2),
          right: BorderSide(color: Colors.grey.shade300),
          top: BorderSide(color: Colors.grey.shade200),
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Measure number
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text(
                '${measure.number}',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ),
          // Notes
          Padding(
            padding: const EdgeInsets.all(4),
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: displayNotes.map((note) {
                int globalIndex = -1;
                bool isActive = false;
                bool isPast = false;
                if (!note.isRest) {
                  globalIndex = startNoteIndex + playableOffset;
                  isActive = globalIndex == activeNoteIndex;
                  isPast = activeNoteIndex >= 0 &&
                      globalIndex < activeNoteIndex;
                  playableOffset++;
                }
                return NoteWidget(
                  note: note,
                  isActive: isActive,
                  isPast: isPast,
                  size: 44,
                  showSolfege: showSolfege,
                  showLetter: showLetter,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact legend row showing color → note name mapping using the active scheme.
class _ColorLegend extends StatelessWidget {
  final bool showSolfege;

  const _ColorLegend({this.showSolfege = false});

  // Natural notes only (C D E F G A B) for the legend
  static const _naturalNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.watch<ColorSchemeProvider>().activeScheme;
    final showLabels = context.watch<ColorSchemeProvider>().showNoteLabels;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _naturalNotes.map((note) {
        final color = scheme.colors[note] ?? Colors.grey;
        final solfege = MusicConstants.stepToSolfege[note] ?? note;
        final textColor = color.computeLuminance() > 0.35
            ? Colors.black87
            : Colors.white;
        final label = showSolfege ? '$solfege\n$note' : note;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: showLabels
              ? Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                )
              : null,
        );
      }).toList(),
    );
  }
}
