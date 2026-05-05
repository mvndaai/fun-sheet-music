import 'package:flutter/material.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/models/music_note.dart';

class LegendCircle extends StatelessWidget {
  final String label;
  final Color color;
  final bool showSolfege;
  final bool showLabels;
  final double size;

  const LegendCircle({
    super.key,
    required this.label,
    required this.color,
    this.showSolfege = false,
    this.showLabels = true,
    this.size = 32,
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
        width: size,
        height: size,
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
                    fontSize: size * 0.28,
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
