import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/music_note.dart';
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
  bool _showLetter = true;
  bool _showSolfege = false;
  int _measuresPerRow = 4;

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final provider = context.watch<ColorSchemeProvider>();
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Settings',
                  style: Theme.of(sheetCtx).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 24),

                // Letters toggle
                SwitchListTile(
                  title: const Text('Letters'),
                  subtitle: const Text('Show letter names on notes (A, B, C…)'),
                  value: _showLetter,
                  onChanged: (v) {
                    setState(() => _showLetter = v);
                    setSheetState(() {});
                    context
                        .read<ColorSchemeProvider>()
                        .setShowNoteLabels(v || _showSolfege);
                  },
                ),

                // Solfège toggle
                SwitchListTile(
                  title: const Text('Solfège'),
                  subtitle:
                      const Text('Show solfège names on notes (Do, Re, Mi…)'),
                  value: _showSolfege,
                  onChanged: (v) {
                    setState(() => _showSolfege = v);
                    setSheetState(() {});
                    context
                        .read<ColorSchemeProvider>()
                        .setShowNoteLabels(_showLetter || v);
                  },
                ),

                const Divider(height: 24),

                // Measures per row
                ListTile(
                  title: const Text('Measures per row'),
                  trailing: DropdownButton<int>(
                    value: _measuresPerRow,
                    underline: const SizedBox.shrink(),
                    items: [2, 3, 4, 6]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _measuresPerRow = v);
                        setSheetState(() {});
                      }
                    },
                  ),
                ),

                const Divider(height: 24),

                // Instrument
                ListTile(
                  title: const Text('Instrument'),
                  subtitle: Text(provider.activeScheme.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ColorSchemesScreen(),
                      ),
                    );
                  },
                ),

                const Divider(height: 24),

                // Print
                ListTile(
                  leading: const Icon(Icons.print),
                  title: const Text('Print'),
                  subtitle: const Text('Generate a PDF of this song'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _printSong();
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _printSong() async {
    final provider = context.read<ColorSchemeProvider>();
    final song = widget.song;

    await Printing.layoutPdf(
      name: song.title,
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        final allNotes = song.allNotes;
        if (allNotes.isEmpty) {
          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (_) => pw.Center(
                child: pw.Text('No notes found in this song.'),
              ),
            ),
          );
          return doc.save();
        }

        const double noteSize = 28;
        const double notePadding = 4;
        const double measureSpacing = 12;
        const double rowSpacing = 12;
        const double headerHeight = 60;
        const double rowHeight = noteSize + notePadding * 2 + rowSpacing;

        final pageHeight = format.availableHeight;

        // Build per-measure note groups (skip empty measures)
        final List<List<MusicNote>> measureNotes = song.measures
            .map((m) => m.playableNotes)
            .where((notes) => notes.isNotEmpty)
            .toList();

        // Split measures into rows of [_measuresPerRow]
        final List<List<List<MusicNote>>> rows = [];
        for (int i = 0; i < measureNotes.length; i += _measuresPerRow) {
          rows.add(
            measureNotes.sublist(
              i,
              (i + _measuresPerRow).clamp(0, measureNotes.length),
            ),
          );
        }

        final rowsPerPage =
            ((pageHeight - headerHeight) / rowHeight).floor().clamp(1, rows.length);

        for (int pageStart = 0;
            pageStart < rows.length;
            pageStart += rowsPerPage) {
          final pageRows = rows.sublist(
            pageStart,
            (pageStart + rowsPerPage).clamp(0, rows.length),
          );

          doc.addPage(
            pw.Page(
              pageFormat: format,
              build: (pw.Context ctx) {
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (pageStart == 0) ...[
                      pw.Text(
                        song.title,
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      if (song.composer.isNotEmpty)
                        pw.Text(
                          song.composer,
                          style: const pw.TextStyle(fontSize: 12),
                        ),
                      pw.SizedBox(height: 12),
                      pw.Divider(),
                      pw.SizedBox(height: 8),
                    ],
                    ...pageRows.map(
                      (rowMeasures) => pw.Padding(
                        padding:
                            const pw.EdgeInsets.only(bottom: rowSpacing),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: rowMeasures.map((notes) {
                            return pw.Padding(
                              padding: pw.EdgeInsets.only(
                                  right: measureSpacing),
                              child: pw.Wrap(
                                spacing: notePadding,
                                runSpacing: notePadding,
                                children: notes.map((note) {
                                  final color = provider.colorForNote(
                                    note.step,
                                    note.alter,
                                    octave: note.octave,
                                  );
                                  final pdfColor = PdfColor(
                                    color.red / 255,
                                    color.green / 255,
                                    color.blue / 255,
                                  );
                                  final textColor =
                                      color.computeLuminance() > 0.35
                                          ? PdfColors.black
                                          : PdfColors.white;

                                  String label = '';
                                  if (_showLetter && _showSolfege) {
                                    label =
                                        '${note.step}\n${note.solfegeName}';
                                  } else if (_showLetter) {
                                    label = note.step;
                                    if (note.alter == 1) label += '#';
                                    if (note.alter == -1) label += 'b';
                                  } else if (_showSolfege) {
                                    label = note.solfegeName;
                                  }

                                  return pw.Container(
                                    width: noteSize,
                                    height: noteSize,
                                    decoration: pw.BoxDecoration(
                                      color: pdfColor,
                                      shape: pw.BoxShape.circle,
                                    ),
                                    alignment: pw.Alignment.center,
                                    child: label.isNotEmpty
                                        ? pw.Text(
                                            label,
                                            textAlign: pw.TextAlign.center,
                                            style: pw.TextStyle(
                                              color: textColor,
                                              fontSize: 7,
                                              fontWeight:
                                                  pw.FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        }

        return doc.save();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SheetMusicWidget(
        song: widget.song,
        showSolfege: _showSolfege,
        showLetter: _showLetter,
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
