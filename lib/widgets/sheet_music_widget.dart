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
  final int? solfegeShift;
  final double? solfegeTonicAlter;
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
  final bool? showHighlight;

  final bool extendLines;

  const SheetMusicWidget({
    super.key,
    required this.song,
    this.activeNoteIndex = -1,
    this.ghostNoteIndex,
    this.ghostNote,
    this.showSolfege = false,
    this.solfegeShift,
    this.solfegeTonicAlter,
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
    this.showHighlight,
    this.extendLines = false,
  });

  @override
  Widget build(BuildContext context) {
    final ip = context.watch<InstrumentProvider>();
    final effectiveShowHeader = showHeader && ip.showLegend;
    final effectiveShowHighlight = showHighlight ?? (ip.showPlayControl || ip.showMicControl);

    final int finalShift = solfegeShift ?? song.solfegeShift ?? ip.solfegeShift;
    final double finalAlter = solfegeTonicAlter ?? song.solfegeTonicAlter ?? ip.solfegeTonicAlter;

    return SheetMusicRenderer(
      song: song,
      instrument: ip.activeScheme,
      activeNoteIndex: activeNoteIndex,
      ghostNoteIndex: ghostNoteIndex,
      ghostNote: ghostNote,
      showSolfege: showSolfege,
      solfegeShift: finalShift,
      solfegeTonicAlter: finalAlter,
      showLetter: showLetter,
      labelsBelow: labelsBelow,
      coloredLabels: coloredLabels,
      measuresPerRow: measuresPerRow,
      showNoteLabels: ip.showNoteLabels,
      includePickupInFirstRow: includePickupInFirstRow,
      header: effectiveShowHeader ? _ColorLegend(song: song, showSolfege: showSolfege) : null,
      scrollable: scrollable,
      labelRotation: labelRotation,
      scrollController: scrollController,
      currentVerse: currentVerse,
      showLyrics: showLyrics ?? ip.showLyrics,
      showHighlight: effectiveShowHighlight,
      extendLines: extendLines,
    );
  }
}

class _ColorLegend extends StatelessWidget {
  final Song song;
  final bool showSolfege;
  const _ColorLegend({required this.song, required this.showSolfege});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstrumentProvider>();
    final scheme = provider.activeScheme;
    final showLabels = provider.showNoteLabels;
    final style = provider.legendStyle;

    if (style == LegendStyle.piano) {
      final int finalShift = showSolfege ? (song.solfegeShift ?? provider.solfegeShift) : 0;
      final double finalAlter = showSolfege ? (song.solfegeTonicAlter ?? provider.solfegeTonicAlter) : 0.0;
      return LegendPiano(
        instrument: scheme,
        showSolfege: showSolfege,
        solfegeShift: finalShift,
        solfegeTonicAlter: finalAlter,
        showLabels: showLabels,
      );
    }

    final int finalShift = song.solfegeShift ?? provider.solfegeShift;
    final double finalAlter = song.solfegeTonicAlter ?? provider.solfegeTonicAlter;

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
                solfegeShift: finalShift,
                solfegeTonicAlter: finalAlter,
                showLabels: showLabels,
              )),
          ...overrideKeys.map((key) => LegendCircle(
                label: key,
                color: scheme.octaveOverrides[key]!,
                showSolfege: showSolfege,
                solfegeShift: finalShift,
                solfegeTonicAlter: finalAlter,
                showLabels: showLabels,
              )),
        ],
      ),
    );
  }
}
