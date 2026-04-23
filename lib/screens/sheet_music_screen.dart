import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/measure.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/song.dart';
import '../providers/color_scheme_provider.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_constants.dart';
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
    _stopPlayback(isDisposing: true);
    _tonePlayer.dispose();
    super.dispose();
  }
  
  void _toggleMetronome() {
    if (_tonePlayer.isMetronomeRunning) {
      _tonePlayer.stopMetronome();
    } else {
      final provider = context.read<ColorSchemeProvider>();
      _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
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
  
  void _stopPlayback({bool isDisposing = false}) {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
    _activeNoteIndex = -1;
    _currentNoteIndexInPlayback = 0;
    if (isDisposing) return;
    if (mounted) {
      setState(() {});
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
          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(sheetCtx).viewInsets.bottom + 24,
            ),
            child: Consumer<ColorSchemeProvider>(
              builder: (context, provider, _) => SingleChildScrollView(
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
                    value: provider.showLetter,
                    onChanged: (v) => provider.setShowLetter(v),
                  ),

                  // Solfège toggle
                  SwitchListTile(
                    title: const Text('Solfège'),
                    subtitle:
                        const Text('Show solfège names on notes (Do, Re, Mi…)'),
                    value: provider.showSolfege,
                    onChanged: (v) => provider.setShowSolfege(v),
                  ),

                  // Labels below toggle
                  SwitchListTile(
                    title: const Text('Labels Below Notes'),
                    subtitle:
                        const Text('Show labels under notes instead of inside'),
                    value: provider.labelsBelow,
                    onChanged: (v) => provider.setLabelsBelow(v),
                  ),

                  // Colored labels toggle
                  SwitchListTile(
                    title: const Text('Colored Labels'),
                    subtitle:
                        const Text('Match label color to note color'),
                    value: provider.coloredLabels,
                    onChanged: (v) => provider.setColoredLabels(v),
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
                        setSheetState(() => _tempo = v);
                        setState(() => _tempo = v);
                        // Restart metronome if running
                        if (_tonePlayer.isMetronomeRunning) {
                          final provider = context.read<ColorSchemeProvider>();
                          _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Metronome Sound
                  ListTile(
                    title: const Text('Metronome Sound'),
                    trailing: DropdownButton<String>(
                      value: provider.metronomeSound,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: 'tick',
                          child: Text('Tick'),
                        ),
                        DropdownMenuItem(
                          value: 'beep',
                          child: Text('Beep'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          provider.setMetronomeSound(v);
                          // Restart metronome if running to apply change
                          if (_tonePlayer.isMetronomeRunning) {
                            _tonePlayer.startMetronome(_tempo, sound: v);
                          }
                        }
                      },
                    ),
                  ),

                  const Divider(height: 24),
                  ListTile(
                    title: const Text('Measures per row'),
                    trailing: DropdownButton<int>(
                      value: provider.measuresPerRow,
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
                          provider.setMeasuresPerRow(v);
                        }
                      },
                    ),
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
            ),
          );
        },
      ),
    );
  }

  Future<void> _printSong() async {
    final provider = context.read<ColorSchemeProvider>();
    final song = widget.song;

    // Load fonts that support Unicode and symbols
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final musicFont = await PdfGoogleFonts.notoMusicRegular();
    final emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();

    await Printing.layoutPdf(
      name: song.title,
      onLayout: (PdfPageFormat format) async {
        final doc = pw.Document(
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
            fontFallback: [emojiFont, musicFont],
          ),
        );

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
        for (int i = 0; i < song.measures.length; i += provider.measuresPerRow) {
          rows.add(
            song.measures.sublist(
              i,
              (i + provider.measuresPerRow).clamp(0, song.measures.length),
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
                    pw.Expanded(
                      child: pw.Column(
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
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _buildStaffRow(
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
                                    rowIndex > 0 ? rows[rowIndex - 1].last : null,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    // Footer
                    pw.Divider(),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          MusicConstants.appName,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Instrument: ${provider.activeScheme.name} ',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                            if (provider.activeScheme.emoji != null)
                              pw.Text(
                                provider.activeScheme.emoji!,
                                style: const pw.TextStyle(fontSize: 9),
                              ),
                          ],
                        ),
                      ],
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
    Measure? previousMeasure,
  ) {
    // Calculate actual width occupied by measures in this row
    final double startX = clefWidth;
    final double availWidth = width - startX;
    final double measureWidth = availWidth / provider.measuresPerRow;
    // Cap the lines at the actual number of measures in this row
    final double actualWidth = startX + (measures.length * measureWidth);

    return pw.SizedBox(
      height: topMargin + staffHeight + topMargin,
      width: width,
      child: pw.Stack(
        children: [
          // Staff lines (5 horizontal lines)
          ...List.generate(5, (i) {
            return pw.Positioned(
              left: 0,
              top: topMargin + i * ls,
              child: pw.Container(
                width: actualWidth,
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
              '\u{1D11E}',
              style: pw.TextStyle(
                font: musicFont,
                fontSize: ls * 3.2,
                color: PdfColors.black,
              ),
            ),
          ),

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
            musicFont,
            context,
            previousMeasure,
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
    pw.Font musicFont,
    BuildContext context,
    Measure? previousMeasure,
  ) {
    final widgets = <pw.Widget>[];
    double x = clefWidth;

    // Make all measures the same width using measuresPerRow (not actual count)
    final availWidth = width - x;
    final measureWidth = availWidth / provider.measuresPerRow;

    Measure? currentPrevMeasure = previousMeasure;

    for (int mi = 0; mi < measures.length; mi++) {
      final measure = measures[mi];

      // Time signature if it changed
      if (currentPrevMeasure == null || 
          measure.beats != currentPrevMeasure.beats || 
          measure.beatType != currentPrevMeasure.beatType) {
        widgets.addAll([
          pw.Positioned(
            left: x + 2,
            top: topMargin + ls * 0.2,
            child: pw.Text(
              '${measure.beats}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
          pw.Positioned(
            left: x + 2,
            top: topMargin + staffHeight / 2 + ls * 0.2,
            child: pw.Text(
              '${measure.beatType}',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey800,
              ),
            ),
          ),
        ]);
      }
      currentPrevMeasure = measure;

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
      final contentWidth = (measureWidth - leftPadding - rightPadding).clamp(0.0, measureWidth);
      
      double cumulativeDuration = 0.0;
      for (int ni = 0; ni < displayNotes.length; ni++) {
        final note = displayNotes[ni];
        
        // Position note in the center of its duration slot within the measure (matching screen behavior)
        final noteX = x + leftPadding + ((cumulativeDuration + note.duration / 2) / noteTotalDuration) * contentWidth;

        if (note.isRest) {
           // TODO: Implement rest drawing for PDF if needed
        } else {
          // Beaming logic for PDF
          bool isBeamed = false;
          if (note.beam != null) {
            if (note.beam == 'begin' || note.beam == 'continue') {
              // Look for the next note in this beam
              int nextNi = ni + 1;
              MusicNote? nextNote;
              while (nextNi < displayNotes.length) {
                final candidate = displayNotes[nextNi];
                if (!candidate.isRest) {
                  nextNote = candidate;
                  break;
                }
                nextNi++;
              }

              if (nextNote != null && (nextNote.beam == 'continue' || nextNote.beam == 'end')) {
                isBeamed = true;
                final nextX = x + leftPadding + ((cumulativeDuration + note.duration + nextNote.duration / 2) / noteTotalDuration) * contentWidth;
                
                const diatonic = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
                final pos = note.octave * 7 + (diatonic[note.step] ?? 0) - 30;
                final nextPos = nextNote.octave * 7 + (diatonic[nextNote.step] ?? 0) - 30;
                
                final stemUp = pos < 5;
                final y = topMargin + staffHeight - pos * ls / 2;
                final nextY = topMargin + staffHeight - nextPos * ls / 2;
                
                final stemLength = ls * 3.4;
                final stemTipY = y + (stemUp ? -stemLength : stemLength);
                final nextStemTipY = nextY + (stemUp ? -stemLength : stemLength);

                widgets.addAll(_buildNote(
                  note,
                  noteX,
                  topMargin,
                  staffHeight,
                  ls,
                  provider,
                  musicFont,
                  forcedStemUp: stemUp,
                  noFlags: true,
                ));

                // Draw beam
                final color = provider.colorForNote(
                  note.step,
                  note.alter,
                  octave: note.octave,
                  brightness: Brightness.light,
                );
                final pdfColor = PdfColor(color.r, color.g, color.b);
                
                const noteHeadWidth = 8.0;
                final beamStartX = noteX + (stemUp ? noteHeadWidth / 2 - 0.6 : -noteHeadWidth / 2 + 0.6);
                final beamEndX = nextX + (stemUp ? noteHeadWidth / 2 - 0.6 : -noteHeadWidth / 2 + 0.6);

                widgets.add(
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    child: pw.CustomPaint(
                      size: const PdfPoint(0, 0),
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        canvas.setStrokeColor(pdfColor);
                        canvas.setLineWidth(3.5);
                        canvas.drawLine(beamStartX, -stemTipY, beamEndX, -nextStemTipY);
                        canvas.strokePath();
                      },
                    ),
                  ),
                );
              }
            } else if (note.beam == 'end' || note.beam == 'continue') {
              // Handled by forward drawing, but we still need to draw this note correctly
              int prevNi = ni - 1;
              MusicNote? startNote;
              while (prevNi >= 0) {
                final candidate = displayNotes[prevNi];
                if (!candidate.isRest && candidate.beam == 'begin') {
                  startNote = candidate;
                  break;
                }
                prevNi--;
              }
              
              const diatonic = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
              final stemUp = startNote != null 
                ? (startNote.octave * 7 + (diatonic[startNote.step] ?? 0) - 30) < 5 
                : (note.octave * 7 + (diatonic[note.step] ?? 0) - 30) < 5;

              widgets.addAll(_buildNote(
                note,
                noteX,
                topMargin,
                staffHeight,
                ls,
                provider,
                musicFont,
                forcedStemUp: stemUp,
                noFlags: true,
              ));
              isBeamed = true;
            }
          }

          if (!isBeamed) {
            widgets.addAll(_buildNote(
              note,
              noteX,
              topMargin,
              staffHeight,
              ls,
              provider,
              musicFont,
            ));
          }
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
    pw.Font musicFont, {
    bool? forcedStemUp,
    bool noFlags = false,
  }) {
    final widgets = <pw.Widget>[];

    // Calculate staff position
    const diatonic = {'C': 0, 'D': 1, 'E': 2, 'F': 3, 'G': 4, 'A': 5, 'B': 6};
    final pos = note.octave * 7 + (diatonic[note.step] ?? 0) - 30;
    final y = topMargin + staffHeight - pos * ls / 2;

    final color = provider.colorForNote(
      note.step,
      note.alter,
      octave: note.octave,
      brightness: Brightness.light,
    );
    final pdfColor = PdfColor(color.r, color.g, color.b);

    // Ledger lines (below staff)
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - 6,
            top: ly - 0.3,
            child: pw.Container(
              width: 12,
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
            left: x - 6,
            top: ly - 0.3,
            child: pw.Container(
              width: 12,
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
            note.alter > 0 ? '\u{266F}' : '\u{266D}',
            style: const pw.TextStyle(
              fontSize: 16,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

    // Note head
    const noteHeadWidth = 8.0;
    const noteHeadHeight = 5.0;
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
      final stemUp = forcedStemUp ?? (pos < 5);
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

      // Flags for shorter notes (eighth, 16th, etc.)
      if (!noFlags) {
        final flagCount = switch (note.type) {
          'eighth' => 1,
          '16th' => 2,
          '32nd' => 3,
          _ => 0,
        };

        if (flagCount > 0) {
          // Tip of the stem where flags attach
          final tipY = stemUp ? y - stemLength : y + stemLength;
          final flagX = stemUp ? x + noteHeadWidth / 2 - 0.6 : x - noteHeadWidth / 2 - 0.6;

          for (int i = 0; i < flagCount; i++) {
            // Space between flags
            final flagShift = stemUp ? i * ls * 0.75 : -i * ls * 0.75;
            final currentFlagY = tipY + flagShift;

            widgets.add(
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.CustomPaint(
                  size: const PdfPoint(0, 0),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    canvas.setStrokeColor(pdfColor);
                    canvas.setLineWidth(1.0);
                    
                    // Use absolute coordinates within the row stack.
                    // PDF graphics Y increases upwards, so we negate currentFlagY.
                    final startX = flagX;
                    final startY = -currentFlagY;
                    
                    // Curve AWAY from the stem tip
                    // Stem UP: Flag curves DOWN (Y decreases in page view, so more negative in PDF)
                    // Stem DOWN: Flag curves UP (Y increases in page view, so less negative in PDF)
                    final ey = stemUp ? -ls * 1.3 : ls * 1.3;
                    final cpY = stemUp ? -ls * 0.5 : ls * 0.5;
                    
                    canvas.moveTo(startX, startY);
                    canvas.curveTo(
                      startX + ls * 0.8, startY + cpY, 
                      startX + ls * 0.5, startY + ey, 
                      startX + ls * 0.5, startY + ey
                    );
                    canvas.strokePath();
                  },
                ),
              ),
            );
          }
        }
      }
    }

    // Note label - positioned below when _labelsBelow is true
    if (provider.showLetter || provider.showSolfege) {
      String label = '';
      if (provider.showLetter && provider.showSolfege) {
        label = '${note.step}\n${note.solfegeName}';
      } else if (provider.showLetter) {
        label = note.step;
        if (note.alter == 1) label += '#';
        if (note.alter == -1) label += 'b';
      } else if (provider.showSolfege) {
        label = note.solfegeName;
      }

      if (provider.labelsBelow) {
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
    return Consumer<ColorSchemeProvider>(
      builder: (context, provider, _) => CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyP, control: true):
              _printSong,
          const SingleActivator(LogicalKeyboardKey.keyP, meta: true): _printSong,
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text(widget.song.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.piano_outlined),
                  tooltip: 'Instruments',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ColorSchemesScreen()),
                  ),
                ),
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
              showSolfege: provider.showSolfege,
              showLetter: provider.showLetter,
              labelsBelow: provider.labelsBelow,
              coloredLabels: provider.coloredLabels,
              activeNoteIndex: _activeNoteIndex,
              measuresPerRow: provider.measuresPerRow,
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
          ),
        ),
      ),
    );
  }
}
