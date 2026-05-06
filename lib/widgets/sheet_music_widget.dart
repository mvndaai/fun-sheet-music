import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/widgets/sheet_music_renderer.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/instrument_profile.dart';
import 'legend_circle.dart';
import 'legend_piano.dart';

/// App-specific wrapper around [SheetMusicRenderer] that connects it to [InstrumentProvider].
class SheetMusicWidget extends StatelessWidget {
  final Song song;
  final int activeNoteIndex;
  final int? ghostNoteIndex;
  final MusicNote? ghostNote;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final int measuresPerRow;
  final bool includePickupInFirstRow;
  final bool showHeader;
  final bool scrollable;
  final double labelRotation;
  final ScrollController? scrollController;
  final int currentVerse;
  final bool? showLyrics;

  final bool extendLines;

  const SheetMusicWidget({
    super.key,
    required this.song,
    this.activeNoteIndex = -1,
    this.ghostNoteIndex,
    this.ghostNote,
    this.showSolfege = false,
    this.showLetter = true,
    this.labelsBelow = true,
    this.coloredLabels = false,
    this.measuresPerRow = 4,
    this.includePickupInFirstRow = true,
    this.showHeader = true,
    this.scrollable = true,
    this.labelRotation = 0,
    this.scrollController,
    this.currentVerse = 1,
    this.showLyrics,
    this.extendLines = false,
  });

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<InstrumentProvider>();
    final effectiveShowHeader = showHeader && ip.showLegend;

    return SheetMusicRenderer(
      song: song,
      instrument: ip.activeScheme,
      activeNoteIndex: activeNoteIndex,
      ghostNoteIndex: ghostNoteIndex,
      ghostNote: ghostNote,
      showSolfege: showSolfege,
      showLetter: showLetter,
      labelsBelow: labelsBelow,
      coloredLabels: coloredLabels,
      measuresPerRow: measuresPerRow,
      showNoteLabels: ip.showNoteLabels,
      includePickupInFirstRow: includePickupInFirstRow,
      header: effectiveShowHeader ? _ColorLegend(showSolfege: showSolfege) : null,
      scrollable: scrollable,
      labelRotation: labelRotation,
      scrollController: scrollController,
      currentVerse: currentVerse,
      showLyrics: showLyrics ?? ip.showLyrics,
      extendLines: extendLines,
    );
  }
}

class _ColorLegend extends StatelessWidget {
  final bool showSolfege;
  const _ColorLegend({required this.showSolfege});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstrumentProvider>();
    final scheme = provider.activeScheme;
    final showLabels = provider.showNoteLabels;
    final style = provider.legendStyle;

    if (style == LegendStyle.piano) {
      return LegendPiano(
        instrument: scheme,
        showSolfege: showSolfege,
        showLabels: showLabels,
      );
    }

    final coloredNotes = kNoteKeys.where((n) => scheme.colors.containsKey(n));
    final overrideKeys = scheme.octaveOverrides.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...coloredNotes.map((note) => LegendCircle(
                label: note,
                color: scheme.colors[note]!,
                showSolfege: showSolfege,
                showLabels: showLabels,
              )),
          ...overrideKeys.map((key) => LegendCircle(
                label: key,
                color: scheme.octaveOverrides[key]!,
                showSolfege: showSolfege,
                showLabels: showLabels,
              )),
        ],
      ),
    );
  }
}
