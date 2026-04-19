import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/music_note.dart';
import '../providers/color_scheme_provider.dart';
import '../utils/note_colors.dart';

/// Regex used to strip octave digits from letter names.
final _octaveDigits = RegExp(r'\d');

/// Displays a single musical note as a colored circle with the note name.
class NoteWidget extends StatelessWidget {
  final MusicNote note;
  final bool isActive; // Highlighted when microphone hears this note
  final bool isPast; // Notes already played (dimmed)
  final double size;
  final bool showSolfege; // Show Do/Re/Mi instead of A/B/C
  final bool showLetter; // Show letter name (C, D, E, ...)

  const NoteWidget({
    super.key,
    required this.note,
    this.isActive = false,
    this.isPast = false,
    this.size = 52,
    this.showSolfege = false,
    this.showLetter = true,
  });

  @override
  Widget build(BuildContext context) {
    if (note.isRest) return _buildRest();

    // Use active color scheme from provider; fall back to static NoteColors.
    final colorProvider = context.watch<ColorSchemeProvider>();
    final color = colorProvider.colorForNote(note.step, note.alter, octave: note.octave);
    final textColor = NoteColors.textColorFor(color);

    // Global label toggle overrides per-screen flags.
    final showLabels = colorProvider.showNoteLabels && (showLetter || showSolfege);
    final displayName = showSolfege
        ? note.solfegeName
        : note.letterName.replaceAll(_octaveDigits, '');

    final double scale = isActive ? 1.35 : 1.0;
    final opacity = isPast ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ]
                : null,
            border: isActive
                ? Border.all(color: Colors.white, width: 3)
                : null,
          ),
          child: showLabels
              ? Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showLetter && showSolfege) ...[
                            Text(
                              displayName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: size * 0.28,
                              ),
                            ),
                            Text(
                              note.letterName.replaceAll(_octaveDigits, ''),
                              style: TextStyle(
                                color: textColor.withOpacity(0.8),
                                fontSize: size * 0.2,
                              ),
                            ),
                          ] else
                            Text(
                              displayName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: size * 0.32,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildRest() {
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          _restSymbol(),
          style: TextStyle(
            fontSize: size * 0.6,
            color: Colors.grey.shade400,
          ),
        ),
      ),
    );
  }

  String _restSymbol() {
    switch (note.type) {
      case 'whole':
        return '𝄻';
      case 'half':
        return '𝄼';
      case 'quarter':
        return '𝄽';
      case 'eighth':
        return '𝄾';
      default:
        return '𝄽';
    }
  }
}
