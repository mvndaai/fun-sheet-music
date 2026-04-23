import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/color_scheme_provider.dart';
import '../music_kit/widgets/sheet_music_renderer.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/instrument_color_scheme.dart';
import '../music_kit/utils/music_constants.dart';

/// App-specific wrapper around [SheetMusicRenderer] that connects it to [ColorSchemeProvider].
class SheetMusicWidget extends StatelessWidget {
  final Song song;
  final int activeNoteIndex;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final int measuresPerRow;

  const SheetMusicWidget({
    super.key,
    required this.song,
    this.activeNoteIndex = -1,
    this.showSolfege = false,
    this.showLetter = true,
    this.labelsBelow = true,
    this.coloredLabels = false,
    this.measuresPerRow = 4,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ColorSchemeProvider>();

    return SheetMusicRenderer(
      song: song,
      colorScheme: cp.activeScheme,
      activeNoteIndex: activeNoteIndex,
      showSolfege: showSolfege,
      showLetter: showLetter,
      labelsBelow: labelsBelow,
      coloredLabels: coloredLabels,
      measuresPerRow: measuresPerRow,
      showNoteLabels: cp.showNoteLabels,
      header: _ColorLegend(showSolfege: showSolfege),
    );
  }
}

class _ColorLegend extends StatelessWidget {
  final bool showSolfege;
  const _ColorLegend({required this.showSolfege});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ColorSchemeProvider>();
    final scheme = provider.activeScheme;
    final showLabels = provider.showNoteLabels;

    final coloredNotes = kNoteKeys.where((n) => scheme.colors.containsKey(n));
    final overrideKeys = scheme.octaveOverrides.keys.toList()..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          ...coloredNotes.map((note) => _LegendCircle(
                label: note,
                color: scheme.colors[note]!,
                showSolfege: showSolfege,
                showLabels: showLabels,
              )),
          ...overrideKeys.map((key) => _LegendCircle(
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

class _LegendCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool showSolfege;
  final bool showLabels;

  const _LegendCircle({
    required this.label,
    required this.color,
    required this.showSolfege,
    required this.showLabels,
  });

  @override
  Widget build(BuildContext context) {
    final baseNote = label.replaceAll(RegExp(r'[0-9]'), '');
    final solfege = MusicConstants.stepToSolfege[baseNote] ?? baseNote;
    final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

    String displayLabel = label;
    if (showSolfege) {
      displayLabel = '$solfege\n$label';
    }

    return Tooltip(
      message: label,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: showLabels
            ? Center(
                child: Text(
                  displayLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
