import 'package:flutter/material.dart';
import '../music_kit/models/instrument_profile.dart';
import '../music_kit/utils/music_constants.dart';

class LegendPiano extends StatelessWidget {
  final InstrumentProfile instrument;
  final bool showSolfege;
  final bool showLabels;
  final double keyWidth;
  final double keyHeight;

  const LegendPiano({
    super.key,
    required this.instrument,
    this.showSolfege = false,
    this.showLabels = true,
    this.keyWidth = 32,
    this.keyHeight = 48,
  });

  @override
  Widget build(BuildContext context) {
    // We'll show one full octave (C to B) of piano keys
    final whiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SizedBox(
        height: keyHeight,
        child: Stack(
          children: [
            // White keys
            Row(
              mainAxisSize: MainAxisSize.min,
              children: whiteNotes.map((note) => _buildKey(context, note, isBlack: false)).toList(),
            ),
            // Black keys
            Positioned(
              top: 0,
              left: keyWidth * 0.7,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildKey(context, 'C#', isBlack: true),
                  SizedBox(width: keyWidth * 0.3),
                  _buildKey(context, 'D#', isBlack: true),
                  SizedBox(width: keyWidth * 1.3),
                  _buildKey(context, 'F#', isBlack: true),
                  SizedBox(width: keyWidth * 0.3),
                  _buildKey(context, 'G#', isBlack: true),
                  SizedBox(width: keyWidth * 0.3),
                  _buildKey(context, 'A#', isBlack: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context, String note, {required bool isBlack}) {
    final color = instrument.colors[note] ?? instrument.colorForNote(note, 0, context: context);
    final isHidden = instrument.hiddenKeys.contains(note);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isBlack ? Colors.black : Colors.white;
    final borderColor = isDark ? Colors.white24 : Colors.black26;
    
    // If hidden, we show it dimmed or as a standard key
    final displayColor = isHidden ? baseColor : color;
    final opacity = isHidden ? 0.3 : 1.0;

    final textColor = displayColor.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
    final solfege = MusicConstants.stepToSolfege[note] ?? note;
    final label = showSolfege ? solfege : note;

    return Opacity(
      opacity: opacity,
      child: Container(
        width: isBlack ? keyWidth * 0.6 : keyWidth,
        height: isBlack ? keyHeight * 0.6 : keyHeight,
        decoration: BoxDecoration(
          color: displayColor,
          border: Border.all(color: borderColor, width: 0.5),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(3)),
          boxShadow: [
            if (!isBlack) BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1)),
            //if (!isBlack) BoxShadow(color: Colors.black.withValues(alpha: .1), blurRadius: 2, offset: const Offset(0, 1)),
          ],
        ),
        child: showLabels && !isBlack
            ? Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: textColor,
                      fontSize: keyWidth * 0.4,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
