import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/color_scheme_provider.dart';
import '../music_kit/widgets/note_renderer.dart';
import '../music_kit/models/music_note.dart';

/// App-specific wrapper around [NoteRenderer] that connects it to [ColorSchemeProvider].
class NoteWidget extends StatelessWidget {
  final MusicNote note;
  final bool isActive;
  final bool isPast;
  final double size;
  final bool showSolfege;
  final bool showLetter;

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
    final colorProvider = context.watch<ColorSchemeProvider>();
    
    return NoteRenderer(
      note: note,
      colorScheme: colorProvider.activeScheme,
      showNoteLabels: colorProvider.showNoteLabels,
      isActive: isActive,
      isPast: isPast,
      size: size,
      showSolfege: showSolfege,
      showLetter: showLetter,
    );
  }
}
