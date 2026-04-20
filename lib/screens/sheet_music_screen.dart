import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../models/measure.dart';
import '../models/music_note.dart';
import '../models/song.dart';
import '../providers/color_scheme_provider.dart';
import '../services/tone_player.dart';
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
  bool _labelsBelow = true;
  bool _coloredLabels = false;
  int _measuresPerRow = 4;
  
  // Playback state
  bool _isPlaying = false;
  int _activeNoteIndex = -1;
  Timer? _playbackTimer;
  int _currentNoteIndexInPlayback = 0;
  
  // Tempo in BPM (beats per minute)
  double _tempo = 120.0;
  
  // Audio player
  final TonePlayer _tonePlayer = TonePlayer();
  
  @override
  void dispose() {
    _stopPlayback();
    _tonePlayer.dispose();
    super.dispose();
  }
  
  void _toggleMetronome() {
    if (_tonePlayer.isMetronomeRunning) {
      _tonePlayer.stopMetronome();
    } else {
      _tonePlayer.startMetronome(_tempo);
    }
    if (mounted) {
      setState(() {});
    }
  }
  
  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }
  
  void _startPlayback() {
    final notes = widget.song.allNotes;
    if (notes.isEmpty) return;
    
    if (mounted) {
      setState(() {
        _isPlaying = true;
        if (_activeNoteIndex == -1 || _activeNoteIndex >= notes.length - 1) {
          _activeNoteIndex = 0;
          _currentNoteIndexInPlayback = 0;
        }
      });
    }
    
    _scheduleNextNote();
  }
  
  void _pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
      });
    }
  }
  
  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _activeNoteIndex = -1;
        _currentNoteIndexInPlayback = 0;
      });
    } else {
      // Widget is being disposed, just update the state without setState
      _isPlaying = false;
      _activeNoteIndex = -1;
      _currentNoteIndexInPlayback = 0;
    }
  }
  
  void _scheduleNextNote() {
    final notes = widget.song.allNotes;
    if (_currentNoteIndexInPlayback >= notes.length) {
      // Song finished
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _activeNoteIndex = -1;
          _currentNoteIndexInPlayback = 0;
        });
        
        // Show completion message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎵 Song finished!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    final note = notes[_currentNoteIndexInPlayback];
    if (mounted) {
      setState(() {
        _activeNoteIndex = _currentNoteIndexInPlayback;
      });
    }
    
    // Play the note sound
    _tonePlayer.playNote(note.frequency);
    
    // Calculate duration in milliseconds
    // Assuming quarter note = 1.0 duration, and tempo is in BPM
    final quarterNoteDuration = 60000.0 / _tempo; // milliseconds per quarter note
    final noteDurationMs = (note.duration * quarterNoteDuration).toInt();
    
    _playbackTimer = Timer(Duration(milliseconds: noteDurationMs), () {
      _currentNoteIndexInPlayback++;
      if (_isPlaying && mounted) {
        _scheduleNextNote();
      }
    });
  }

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
            child: SingleChildScrollView(
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

                // Labels below toggle
                SwitchListTile(
                  title: const Text('Labels Below Notes'),
                  subtitle:
                      const Text('Show labels under notes instead of inside'),
                  value: _labelsBelow,
                  onChanged: (v) {
                    setState(() => _labelsBelow = v);
                    setSheetState(() {});
                  },
                ),

                // Colored labels toggle
                SwitchListTile(
                  title: const Text('Colored Labels'),
                  subtitle:
                      const Text('Match label color to note color'),
                  value: _coloredLabels,
                  onChanged: (v) {
                    setState(() => _coloredLabels = v);
                    setSheetState(() {});
                  },
                ),

                const Divider(height: 24),

                // Tempo/Speed control
                ListTile(
                  title: const Text('Tempo'),
                  subtitle: Text('${_tempo.round()} BPM'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Slider(
                    value: _tempo,
                    min: 40,
                    max: 240,
                    divisions: 40,
                    label: '${_tempo.round()} BPM',
                    onChanged: (v) {
                      setState(() => _tempo = v);
                      setSheetState(() {});
                      // Restart metronome if running
                      if (_tonePlayer.isMetronomeRunning) {
                        _tonePlayer.startMetronome(_tempo);
                      }
                    },
                  ),
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

                // Theme
                ListTile(
                  title: const Text('Theme'),
                  trailing: DropdownButton<ThemeMode>(
                    value: provider.themeMode,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        provider.setThemeMode(v);
                        setSheetState(() {});
                      }
                    },
                  ),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _printSong() async {
    final provider = context.read<ColorSchemeProvider>();
    final song = widget.song;

    // Load a font that supports music symbols
    final musicFont = await PdfGoogleFonts.notoMusicRegular();

    await Printing.layoutPdf(
      name: song.title,
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document();

        if (song.measures.isEmpty) {
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

        // Staff notation constants
        const double lineSpacing = 10.0;
        const double staffHeight = lineSpacing * 4; // 5 lines = 4 spaces
        const double topMargin = lineSpacing * 4;
        const double bottomMargin = lineSpacing * 4;
        const double rowHeight = topMargin + staffHeight + bottomMargin;
        const double clefWidth = 35.0;
        const double timeSigWidth = 20.0;
        const double headerHeight = 80;

        final pageWidth = format.availableWidth;
        final pageHeight = format.availableHeight;

        // Split measures into rows
        final List<List<Measure>> rows = [];
        for (int i = 0; i < song.measures.length; i += _measuresPerRow) {
          rows.add(
            song.measures.sublist(
              i,
              (i + _measuresPerRow).clamp(0, song.measures.length),
            ),
          );
        }

        // Calculate total duration across ALL measures for consistent spacing
        final totalSongDuration = song.measures.fold(0.0, (sum, m) {
          final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
          final measureDuration = displayNotes.isEmpty ? 1.0 : displayNotes.fold(0.0, (s, n) => s + n.duration);
          return sum + measureDuration;
        });

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
                    ...pageRows.asMap().entries.map((entry) {
                      final rowIndex = pageStart + entry.key;
                      final rowMeasures = entry.value;
                      final isFirstRow = rowIndex == 0;
                      final isLastRow = rowIndex == rows.length - 1;

                      return pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 16),
                        child: _buildStaffRow(
                          rowMeasures,
                          provider,
                          pageWidth,
                          lineSpacing,
                          topMargin,
                          staffHeight,
                          clefWidth,
                          timeSigWidth,
                          isFirstRow,
                          isLastRow,
                          totalSongDuration,
                          musicFont,
                        ),
                      );
                    }),
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

  // Build a staff row with proper notation
  pw.Widget _buildStaffRow(
    List<Measure> measures,
    ColorSchemeProvider provider,
    double width,
    double ls,
    double topMargin,
    double staffHeight,
    double clefWidth,
    double timeSigWidth,
    bool isFirstRow,
    bool isLastRow,
    double totalSongDuration,
    pw.Font musicFont,
  ) {
    return pw.SizedBox(
      height: topMargin + staffHeight + topMargin,
      width: width,
      child: pw.Stack(
        children: [
          // Staff lines (5 horizontal lines)
          ...List.generate(5, (i) {
            return pw.Positioned(
              left: 0,
              right: 0,
              top: topMargin + i * ls,
              child: pw.Container(
                height: 0.5,
                color: PdfColors.grey700,
              ),
            );
          }),

          // Treble clef - using Unicode symbol with music font
          pw.Positioned(
            left: 2,
            top: topMargin - ls * 1.35, // Corrected offset to match screen
            child: pw.Text(
              '𝄞',
              style: pw.TextStyle(
                font: musicFont,
                fontSize: ls * 3.2,
                color: PdfColors.black,
              ),
            ),
          ),

          // Time signature (first row only)
          if (isFirstRow && measures.isNotEmpty) ...[
            pw.Positioned(
              left: clefWidth + 2,
              top: topMargin + ls * 0.2,
              child: pw.Text(
                '${measures.first.beats}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
            pw.Positioned(
              left: clefWidth + 2,
              top: topMargin + staffHeight / 2 + ls * 0.2,
              child: pw.Text(
                '${measures.first.beatType}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          ],

          // Notes and bar lines
          ..._buildMeasuresContent(
            measures,
            provider,
            width,
            ls,
            topMargin,
            staffHeight,
            clefWidth,
            timeSigWidth,
            isFirstRow,
            isLastRow,
            totalSongDuration,
          ),
        ],
      ),
    );
  }

  // Build notes and bar lines for all measures in a row
  List<pw.Widget> _buildMeasuresContent(
    List<Measure> measures,
    ColorSchemeProvider provider,
    double width,
    double ls,
    double topMargin,
    double staffHeight,
    double clefWidth,
    double timeSigWidth,
    bool isFirstRow,
    bool isLastRow,
    double totalSongDuration,
  ) {
    final widgets = <pw.Widget>[];
    double x = clefWidth + (isFirstRow ? timeSigWidth : 0);

    // Calculate duration for each measure in this row 
    final measureDurations = measures.map((m) {
      final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
      return displayNotes.isEmpty ? 1.0 : displayNotes.fold(0.0, (sum, n) => sum + n.duration);
    }).toList();
    
    // Calculate total duration for THIS ROW and use it for spacing
    final rowTotalDuration = measureDurations.fold(0.0, (s, d) => s + d);
    final availWidth = width - x;
    final pixelsPerDuration = rowTotalDuration > 0 ? (availWidth / rowTotalDuration) : 24.0;

    for (int mi = 0; mi < measures.length; mi++) {
      final measure = measures[mi];
      final measureDuration = measureDurations[mi];
      final measureWidth = measureDuration * pixelsPerDuration;

      // Measure number
      widgets.add(
        pw.Positioned(
          left: x + 2,
          top: 2,
          child: pw.Text(
            '${measure.number}',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey500,
            ),
          ),
        ),
      );

      // Notes in measure
      final displayNotes = measure.notes.where((n) => !n.isChordContinuation).toList();
      final noteTotalDuration = displayNotes.isEmpty 
          ? 1.0 
          : displayNotes.fold(0.0, (sum, n) => sum + n.duration);
      
      // Add padding within the measure for visual clarity
      const leftPadding = 20.0;
      const rightPadding = 20.0;
      
      double cumulativeDuration = 0.0;
      for (int ni = 0; ni < displayNotes.length; ni++) {
        final note = displayNotes[ni];
        if (!note.isRest) {
          // Position note in the center of its duration slot within the measure (matching screen behavior)
          final noteX = x + leftPadding + ((cumulativeDuration + note.duration / 2) / noteTotalDuration) * (measureWidth - leftPadding - rightPadding).clamp(0.0, measureWidth);
          
          widgets.addAll(_buildNote(
            note,
            noteX,
            topMargin,
            staffHeight,
            ls,
            provider,
          ));
        }
        cumulativeDuration += note.duration;
      }

      x += measureWidth;

      // Bar line
      final isLastMeasure = mi == measures.length - 1;
      if (isLastMeasure && isLastRow) {
        // Double bar line at end
        widgets.addAll([
          pw.Positioned(
            left: x - 3,
            top: topMargin,
            child: pw.Container(
              width: 2,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
          pw.Positioned(
            left: x,
            top: topMargin,
            child: pw.Container(
              width: 1,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
        ]);
      } else {
        widgets.add(
          pw.Positioned(
            left: x,
            top: topMargin,
            child: pw.Container(
              width: 1,
              height: staffHeight,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    return widgets;
  }

  // Build a single note with staff notation
  List<pw.Widget> _buildNote(
    MusicNote note,
    double x,
    double topMargin,
    double staffHeight,
    double ls,
    ColorSchemeProvider provider,
  ) {
    final widgets = <pw.Widget>[];

    // Calculate staff position
    const diatonic = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
    final pos = note.octave * 7 + (diatonic[note.step] ?? 0) - 30;
    final y = topMargin + staffHeight - pos * ls / 2;

    final color = provider.colorForNote(note.step, note.alter, octave: note.octave);
    final pdfColor = PdfColor(color.r, color.g, color.b);

    // Ledger lines (below staff)
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - 10,
            top: ly - 0.3,
            child: pw.Container(
              width: 20,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    // Ledger lines (above staff)
    if (pos > 8) {
      final highest = pos.isEven ? pos : pos - 1;
      for (int lp = 10; lp <= highest; lp += 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - 10,
            top: ly - 0.3,
            child: pw.Container(
              width: 20,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    // Accidental (sharp or flat)
    if (note.alter != 0) {
      widgets.add(
        pw.Positioned(
          left: x - 18,
          top: y - 8,
          child: pw.Text(
            note.alter > 0 ? '♯' : '♭',
            style: const pw.TextStyle(
              fontSize: 16,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    // Note head
    final noteHeadWidth = 8.0;
    final noteHeadHeight = 5.0;
    final filled = note.type != 'whole' && note.type != 'half';

    widgets.add(
      pw.Positioned(
        left: x - noteHeadWidth / 2,
        top: y - noteHeadHeight / 2,
        child: pw.Transform.rotate(
          angle: -0.20,
          child: pw.Container(
            width: noteHeadWidth,
            height: noteHeadHeight,
            decoration: pw.BoxDecoration(
              color: filled ? pdfColor : null,
              border: filled ? null : pw.Border.all(
                color: pdfColor,
                width: 1.5,
              ),
              borderRadius: pw.BorderRadius.circular(noteHeadWidth / 2),
            ),
          ),
        ),
      ),
    );

    // Stem
    if (note.type != 'whole') {
      final stemUp = pos < 5;
      final stemLength = ls * 3.4;
      
      widgets.add(
        pw.Positioned(
          left: stemUp ? x + noteHeadWidth / 2 - 0.6 : x - noteHeadWidth / 2 - 0.6,
          top: stemUp ? y - stemLength : y,
          child: pw.Container(
            width: 1.2,
            height: stemLength,
            color: pdfColor,
          ),
        ),
      );
    }

    // Note label - positioned below when _labelsBelow is true
    if (_showLetter || _showSolfege) {
      String label = '';
      if (_showLetter && _showSolfege) {
        label = '${note.step}\n${note.solfegeName}';
      } else if (_showLetter) {
        label = note.step;
        if (note.alter == 1) label += '#';
        if (note.alter == -1) label += 'b';
      } else if (_showSolfege) {
        label = note.solfegeName;
      }

      if (_labelsBelow) {
        // Position label below the note
        final stemUp = pos < 5;
        final stemLength = ls * 3.4;
        final labelY = stemUp ? y + ls * 2.5 : y + stemLength + ls * 1.2;
        
        widgets.add(
          pw.Positioned(
            left: x - 6,
            top: labelY - 3,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.black,
              ),
            ),
          ),
        );
      } else {
        // Position label inside note head
        final textColor = color.computeLuminance() > 0.35
            ? PdfColors.black
            : PdfColors.white;

        widgets.add(
          pw.Positioned(
            left: x - 4,
            top: y - 4,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 5,
                fontWeight: pw.FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.song.title),
        actions: [
          IconButton(
            icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
            tooltip: _isPlaying ? 'Pause' : 'Play',
            onPressed: _togglePlayback,
          ),
          IconButton(
            icon: Icon(
              _tonePlayer.isMetronomeRunning 
                ? Icons.stop 
                : Icons.av_timer,
            ),
            tooltip: _tonePlayer.isMetronomeRunning 
              ? 'Stop Metronome' 
              : 'Start Metronome',
            onPressed: _toggleMetronome,
          ),
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
        labelsBelow: _labelsBelow,
        coloredLabels: _coloredLabels,
        activeNoteIndex: _activeNoteIndex,
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
