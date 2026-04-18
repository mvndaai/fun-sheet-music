import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../providers/color_scheme_provider.dart';
import '../widgets/sheet_music_widget.dart';
import 'practice_screen.dart';
import 'color_schemes_screen.dart';

/// Displays the full sheet music for a song with color-coded notes.
class SheetMusicScreen extends StatefulWidget {
  final Song song;

  const SheetMusicScreen({super.key, required this.song});

  @override
  State<SheetMusicScreen> createState() => _SheetMusicScreenState();
}

class _SheetMusicScreenState extends State<SheetMusicScreen> {
  bool _showSolfege = false;
  bool _showBoth = false;
  int _measuresPerRow = 4;

  String get _labelMode {
    if (_showBoth) return 'both';
    if (_showSolfege) return 'solfege';
    return 'letter';
  }

  @override
  Widget build(BuildContext context) {
    final labelProvider = context.watch<ColorSchemeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        actions: [
          // Note labels toggle (also respects global off switch)
          PopupMenuButton<String>(
            icon: const Icon(Icons.label),
            tooltip: 'Note labels',
            onSelected: (value) {
              if (value == 'off') {
                context.read<ColorSchemeProvider>().setShowNoteLabels(false);
              } else {
                context.read<ColorSchemeProvider>().setShowNoteLabels(true);
                setState(() {
                  switch (value) {
                    case 'letter':
                      _showSolfege = false;
                      _showBoth = false;
                    case 'solfege':
                      _showSolfege = true;
                      _showBoth = false;
                    case 'both':
                      _showSolfege = true;
                      _showBoth = true;
                  }
                });
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'letter',
                child: Row(children: [
                  if (labelProvider.showNoteLabels && _labelMode == 'letter')
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  const Text('Letter (A, B, C)'),
                ]),
              ),
              PopupMenuItem(
                value: 'solfege',
                child: Row(children: [
                  if (labelProvider.showNoteLabels && _labelMode == 'solfege')
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  const Text('Solfège (Do, Re, Mi)'),
                ]),
              ),
              PopupMenuItem(
                value: 'both',
                child: Row(children: [
                  if (labelProvider.showNoteLabels && _labelMode == 'both')
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  const Text('Both'),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'off',
                child: Row(children: [
                  if (!labelProvider.showNoteLabels)
                    const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  const Text('None (colors only)'),
                ]),
              ),
            ],
          ),
          // Measures per row
          PopupMenuButton<int>(
            icon: const Icon(Icons.grid_view),
            tooltip: 'Layout',
            onSelected: (v) => setState(() => _measuresPerRow = v),
            itemBuilder: (_) => [2, 3, 4, 6].map((v) {
              return PopupMenuItem(
                value: v,
                child: Row(children: [
                  if (_measuresPerRow == v) const Icon(Icons.check, size: 16),
                  const SizedBox(width: 8),
                  Text('$v measures per row'),
                ]),
              );
            }).toList(),
          ),
          // Color scheme shortcut
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Instrument colors',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ColorSchemesScreen()),
            ),
          ),
          // Practice mode button
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Practice mode',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PracticeScreen(song: widget.song),
              ),
            ),
          ),
        ],
      ),
      body: SheetMusicWidget(
        song: widget.song,
        showSolfege: _showSolfege,
        showLetter: !_showSolfege || _showBoth,
        measuresPerRow: _measuresPerRow,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PracticeScreen(song: widget.song),
          ),
        ),
        icon: const Icon(Icons.mic),
        label: const Text('Practice'),
      ),
    );
  }
}
