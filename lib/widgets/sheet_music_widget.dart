import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/song.dart';
import '../models/music_note.dart';
import '../models/measure.dart';
import '../models/instrument_color_scheme.dart';
import '../providers/color_scheme_provider.dart';
import '../utils/music_constants.dart';
import '../utils/note_colors.dart';

// ── Staff geometry constants ─────────────────────────────────────────────────

/// Vertical distance (px) between adjacent staff lines.
const double _kLS = 12.0;

/// Note-head y semi-axis (fits within one staff space).
const double _kNRy = _kLS * 0.44; // ≈ 5.3 px

/// Note-head x semi-axis (wider than height so labels fit).
const double _kNRx = _kLS * 0.78; // ≈ 9.4 px

/// Stem length.
const double _kStem = _kLS * 3.4;

/// Horizontal space reserved at the start of each row for the treble clef.
const double _kClefW = 44.0;

/// Space reserved for the time signature (first row only).
const double _kTimeSigW = 22.0;

/// Pixels above the top staff line (head-room for high notes + ledger lines).
const double _kTopMargin = _kLS * 3.2;

/// Height of the staff proper (4 × line-spacing).
const double _kStaffH = _kLS * 4;

/// Pixels below the bottom staff line (room for low notes + note labels).
const double _kBotMargin = _kLS * 3.5;

/// Total pixel height of one staff row.
const double _kRowH = _kTopMargin + _kStaffH + _kBotMargin;

// ── Treble-clef pitch → staff-position mapping ───────────────────────────────

/// Diatonic ordinal of each note step (C = 0 … B = 6).
const Map<String, int> _kDiatonic = {
  'C': 0,
  'D': 1,
  'E': 2,
  'F': 3,
  'G': 4,
  'A': 5,
  'B': 6,
};

/// Returns the treble-clef staff position for a note.
///
///  0 → E4 (bottom staff line)
///  2 → G4 (2nd line)
///  4 → B4 (middle line)
///  6 → D5 (4th line)
///  8 → F5 (top line)
///
/// Negative values are below the staff; values > 8 are above it.
int _staffPos(String step, int octave) =>
    octave * 7 + (_kDiatonic[step] ?? 0) - 30; // 30 = diatonic value of E4

/// Converts a staff position to the y-coordinate within a painter row.
double _posToY(int pos) => _kTopMargin + _kStaffH - pos * _kLS / 2;

// ── Public widget ────────────────────────────────────────────────────────────

/// Displays the full sheet music for a [song] using proper treble-clef
/// staff notation.  Notes are colour-coded via the active [ColorSchemeProvider].
class SheetMusicWidget extends StatelessWidget {
  final Song song;

  /// Index (into [song.allNotes]) of the currently highlighted note.
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
    if (song.measures.isEmpty) {
      return const Center(child: Text('No notes found in this song.'));
    }

    final rows = _buildRows();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Note colour legend ───────────────────────────────────────────
          _ColorLegend(showSolfege: showSolfege),
          const SizedBox(height: 16),

          // ── Staff rows ───────────────────────────────────────────────────
          ...rows.map(
            (row) => _StaffRow(
              row: row,
              activeNoteIndex: activeNoteIndex,
              showSolfege: showSolfege,
              showLetter: showLetter,
              labelsBelow: labelsBelow,
              coloredLabels: coloredLabels,
            ),
          ),
        ],
      ),
    );
  }

  List<_RowData> _buildRows() {
    // Calculate total duration across ALL measures for consistent spacing
    final totalDuration = song.measures.fold(0.0, (sum, m) {
      final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
      final measureDuration = displayNotes.isEmpty ? 1.0 : displayNotes.fold(0.0, (s, n) => s + n.duration);
      return sum + measureDuration;
    });
    
    final rows = <_RowData>[];
    int noteOffset = 0;
    Measure? prevMeasure;
    for (int i = 0; i < song.measures.length; i += measuresPerRow) {
      final end = (i + measuresPerRow).clamp(0, song.measures.length);
      final batch = song.measures.sublist(i, end);
      rows.add(_RowData(
        measures: batch,
        firstNoteIndex: noteOffset,
        isFirstRow: i == 0,
        isLastRow: end == song.measures.length,
        totalSongDuration: totalDuration,
        measuresPerRow: measuresPerRow,
        previousMeasure: prevMeasure,
      ));
      noteOffset += batch.fold(0, (s, m) => s + m.playableNotes.length);
      prevMeasure = batch.last;
    }
    return rows;
  }
}

// ── Internal data container ──────────────────────────────────────────────────

class _RowData {
  final List<Measure> measures;
  final int firstNoteIndex;
  final bool isFirstRow;
  final bool isLastRow;
  final double totalSongDuration;
  final int measuresPerRow;
  final Measure? previousMeasure;

  const _RowData({
    required this.measures,
    required this.firstNoteIndex,
    required this.isFirstRow,
    required this.isLastRow,
    required this.totalSongDuration,
    required this.measuresPerRow,
    this.previousMeasure,
  });
}

// ── Staff row widget ─────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  final _RowData row;
  final int activeNoteIndex;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;

  const _StaffRow({
    required this.row,
    required this.activeNoteIndex,
    required this.showSolfege,
    required this.showLetter,
    required this.labelsBelow,
    required this.coloredLabels,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ColorSchemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: _kRowH,
          width: constraints.maxWidth,
          child: CustomPaint(
            painter: _StaffPainter(
              row: row,
              activeNoteIndex: activeNoteIndex,
              showSolfege: showSolfege,
              showLetter: showLetter,
              labelsBelow: labelsBelow,
              coloredLabels: coloredLabels,
              colorProvider: cp,
              context: context,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom painter ───────────────────────────────────────────────────────────

class _StaffPainter extends CustomPainter {
  final _RowData row;
  final int activeNoteIndex;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final ColorSchemeProvider colorProvider;
  final BuildContext context;

  _StaffPainter({
    required this.row,
    required this.activeNoteIndex,
    required this.showSolfege,
    required this.showLetter,
    required this.labelsBelow,
    required this.coloredLabels,
    required this.colorProvider,
    required this.context,
  }) : super(repaint: colorProvider);

  @override
  bool shouldRepaint(_StaffPainter old) =>
      old.activeNoteIndex != activeNoteIndex ||
      old.showSolfege != showSolfege ||
      old.showLetter != showLetter ||
      old.labelsBelow != labelsBelow ||
      old.coloredLabels != coloredLabels ||
      old.context != context ||
      old.row != row;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use contrast colors
    final clefColor = isDark ? Colors.white70 : Colors.black87;

    // Use contrast colors
    final linePaint = Paint()
      ..color = clefColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    double x = _drawClefAndTimeSig(canvas, clefColor);
    final double startX = x;

    // Make all measures the same width using measuresPerRow (not actual count)
    final availW = size.width - startX;
    final measureW = availW / row.measuresPerRow;
    final actualW = startX + (row.measures.length * measureW);

    _drawStaffLines(canvas, actualW, linePaint);

    int noteOffset = row.firstNoteIndex;
    Measure? currentPrevMeasure = row.previousMeasure;

    for (int mi = 0; mi < row.measures.length; mi++) {
      final m = row.measures[mi];

      // Draw time signature if it changed from previous measure
      if (currentPrevMeasure == null || 
          m.beats != currentPrevMeasure.beats || 
          m.beatType != currentPrevMeasure.beatType) {
        _drawTimeSig(canvas, m.beats, m.beatType, x, clefColor);
        // Note: We might want to adjust 'x' if the time sig takes space, 
        // but for now let's overlay it or simplify.
      }

      _drawMeasureNumber(canvas, m.number, x);
      _drawMeasureNotes(canvas, m, x, measureW, noteOffset, clefColor);
      noteOffset += m.playableNotes.length;
      x += measureW;
      currentPrevMeasure = m;

      // Bar line
      final isLastMeasureInRow = mi == row.measures.length - 1;
      if (isLastMeasureInRow && row.isLastRow) {
        _drawDoubleBarLine(canvas, x, clefColor);
      } else {
        final bp = Paint()
          ..color = clefColor.withValues(alpha: 0.6)
          ..strokeWidth = isLastMeasureInRow ? 2.0 : 1.2;
        canvas.drawLine(
          Offset(x, _kTopMargin),
          Offset(x, _kTopMargin + _kStaffH),
          bp,
        );
      }
    }
  }

  // ── Staff lines ────────────────────────────────────────────────────────────

  void _drawStaffLines(Canvas canvas, double width, Paint p) {
    for (int i = 0; i < 5; i++) {
      final y = _kTopMargin + i * _kLS;
      canvas.drawLine(Offset(0, y), Offset(width, y), p);
    }
  }

  // ── Treble clef + optional time signature ─────────────────────────────────

  /// Draws the clef (and time sig on the first row) and returns the x position
  /// where note content begins.
  double _drawClefAndTimeSig(Canvas canvas, Color color) {
    // '𝄞' (U+1D11E) treble clef — positioned so the G4 curl sits on the G4 line.
    // G4 is at staff position 2 → y = _posToY(2).
    final g4y = _posToY(2);
    // Increased size and adjusted position to be slightly lower than before.
    const clefFontSize = _kLS * 3.8;
    // Moved down: Adjusted offset from 1.35 to 1.1 to shift the larger glyph downwards.
    _drawMusicSymbol(
      canvas,
      '𝄞',
      Offset(2, g4y - clefFontSize * 1.1),
      fontSize: clefFontSize,
      color: color,
    );

    double x = _kClefW;

    if (row.isFirstRow && row.measures.isNotEmpty) {
      // No extra space needed here anymore as the measure loop handles it
    }

    return x;
  }

  // ── Measure number ─────────────────────────────────────────────────────────

  void _drawTimeSig(Canvas canvas, int beats, int beatType, double x, Color color) {
    const tsFontSize = _kLS * 1.55;
    _drawText(
      canvas,
      '$beats',
      Offset(x + 2, _kTopMargin + _kLS * 0.1),
      fontSize: tsFontSize,
      color: color,
      fontWeight: FontWeight.bold,
    );
    _drawText(
      canvas,
      '$beatType',
      Offset(x + 2, _kTopMargin + _kStaffH / 2 + _kLS * 0.1),
      fontSize: tsFontSize,
      color: color,
      fontWeight: FontWeight.bold,
    );
  }

  void _drawMeasureNumber(Canvas canvas, int number, double x) {
    _drawText(
      canvas,
      '$number',
      Offset(x + 2, 1),
      fontSize: 9,
      color: Colors.grey.shade500,
    );
  }

  // ── All notes in one measure ───────────────────────────────────────────────

  void _drawMeasureNotes(
    Canvas canvas,
    Measure m,
    double startX,
    double measureWidth,
    int noteOffset,
    Color clefColor,
  ) {
    final displayNotes =
        m.notes.where((n) => !n.isChordContinuation).toList();
    
    // Calculate total duration for proportional spacing
    final totalDuration = displayNotes.isEmpty 
        ? 1.0 
        : displayNotes.fold(0.0, (sum, n) => sum + n.duration);
    
    // Add padding within the measure for visual clarity.
    // Balanced padding and centering within the note's time slot ensures
    // notes are correctly centered while leaving room for accidentals.
    const leftPadding = 20.0;
    const rightPadding = 20.0;
    final contentWidth = (measureWidth - leftPadding - rightPadding).clamp(0.0, measureWidth);
    
    int playableIdx = 0;
    double cumulativeDuration = 0.0;

    for (int ni = 0; ni < displayNotes.length; ni++) {
      final note = displayNotes[ni];
      
      // Position note in the center of its duration slot within the measure
      final noteX = startX + leftPadding + ((cumulativeDuration + note.duration / 2) / totalDuration) * contentWidth;

      if (note.isRest) {
        _drawRest(canvas, noteX, note.type, clefColor);
      } else {
        final globalIdx = noteOffset + playableIdx;
        final isActive = globalIdx == activeNoteIndex;
        final isPast = activeNoteIndex >= 0 && globalIdx < activeNoteIndex;

        // Beam logic
        bool isBeamed = false;
        if (note.beam != null) {
          if (note.beam == 'begin' || note.beam == 'continue') {
            // Look for the end of this beam
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
              final nextX = startX + leftPadding + ((cumulativeDuration + note.duration + nextNote.duration / 2) / totalDuration) * contentWidth;
              
              final pos = _staffPos(note.step, note.octave);
              final nextPos = _staffPos(nextNote.step, nextNote.octave);
              
              // Decide beam direction (simplified: based on first note)
              final stemUp = pos < 5;
              final y = _posToY(pos);
              final nextY = _posToY(nextPos);
              
              final stemTipY = y + (stemUp ? -_kStem : _kStem);
              final nextStemTipY = nextY + (stemUp ? -_kStem : _kStem);

              _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
                forcedStemUp: stemUp, 
                noFlags: true, 
                stemTipY: stemTipY
              );

              // Get note color for the beam
              final noteColor = colorProvider.colorForNote(
                note.step,
                note.alter,
                octave: note.octave,
                context: context,
              );

              // Draw beam
              final beamPaint = Paint()
                ..color = noteColor.withValues(alpha: isPast ? 0.3 : 0.7)
                ..strokeWidth = 3.5;
              
              final beamStartX = noteX + (stemUp ? _kNRx : -_kNRx);
              final beamEndX = nextX + (stemUp ? _kNRx : -_kNRx);
              
              canvas.drawLine(Offset(beamStartX, stemTipY), Offset(beamEndX, nextStemTipY), beamPaint);
              
              // If it's a 16th or 32nd note, we'd need more beams, but this handles the basic eighth note connection.
            }
          } else if (note.beam == 'end' || note.beam == 'continue') {
            // Already handled by the 'begin' or previous 'continue' note drawing the beam forward.
            // Just need to draw the note itself with the correct stem.
            
            // Find the start of this beam to determine stem direction
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
            
            final stemUp = startNote != null ? _staffPos(startNote.step, startNote.octave) < 5 : _staffPos(note.step, note.octave) < 5;
            final y = _posToY(_staffPos(note.step, note.octave));
            final stemTipY = y + (stemUp ? -_kStem : _kStem);
            
            _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
              forcedStemUp: stemUp, 
              noFlags: true, 
              stemTipY: stemTipY
            );
            isBeamed = true;
          }
        }

        if (!isBeamed) {
          _drawNote(canvas, note, noteX, isActive, isPast, clefColor);
        }

        playableIdx++;
      }
      
      cumulativeDuration += note.duration;
    }
  }

  // ── Single pitched note ────────────────────────────────────────────────────

  void _drawNote(
    Canvas canvas,
    MusicNote note,
    double x,
    bool isActive,
    bool isPast,
    Color clefColor, {
    bool? forcedStemUp,
    bool noFlags = false,
    double? stemTipY,
  }) {
    final pos = _staffPos(note.step, note.octave);
    final y = _posToY(pos);
    final color = colorProvider.colorForNote(
      note.step,
      note.alter,
      octave: note.octave,
      context: context,
    );
    final alpha = isPast ? 0.30 : 1.0;

    _drawLedgerLines(canvas, x, pos, alpha, clefColor);
    _drawAccidental(canvas, note.alter, x, y, alpha, clefColor);
    _drawNoteHead(canvas, note.type, x, y, color, alpha, isActive);
    _drawStem(
      canvas,
      note.type,
      x,
      y,
      pos,
      alpha,
      color,
      clefColor,
      forcedStemUp: forcedStemUp,
      noFlags: noFlags,
      stemTipY: stemTipY,
    );
    if (note.isDotted) _drawDot(canvas, x, y, alpha, clefColor);
    _drawNoteLabel(canvas, note, x, y, pos, color, alpha, clefColor);
  }

  // ── Accidental (sharp / flat) ──────────────────────────────────────────────

  void _drawAccidental(
    Canvas canvas,
    double alter,
    double x,
    double y,
    double alpha,
    Color clefColor,
  ) {
    if (alter == 0) return;
    _drawText(
      canvas,
      alter > 0 ? '♯' : '♭',
      Offset(x - _kNRx * 2 - 4, y - _kLS * 0.95),
      fontSize: _kLS * 1.3,
      color: clefColor.withValues(alpha: alpha),
    );
  }

  // ── Note head ─────────────────────────────────────────────────────────────

  void _drawNoteHead(
    Canvas canvas,
    String type,
    double x,
    double y,
    Color color,
    double alpha,
    bool isActive,
  ) {
    final filled = type != 'whole' && type != 'half';
    final rect = Rect.fromCenter(
      center: Offset(x, y),
      width: _kNRx * 2,
      height: _kNRy * 2,
    );

    // Glow for active note.
    if (isActive) {
      canvas.drawOval(
        rect.inflate(6),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    // Tilt the oval slightly, like real engraved note heads.
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.20);
    canvas.translate(-x, -y);

    if (filled) {
      canvas.drawOval(
        rect,
        Paint()..color = color.withValues(alpha: alpha),
      );
      // White border highlight for active note.
      if (isActive) {
        canvas.drawOval(
          rect,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
      }
    } else {
      // Open note head: coloured outline + very light fill.
      canvas.drawOval(
        rect,
        Paint()..color = color.withValues(alpha: alpha * 0.15),
      );
      canvas.drawOval(
        rect,
        Paint()
          ..color = color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    canvas.restore();
  }

  // ── Stem ──────────────────────────────────────────────────────────────────

  void _drawStem(
    Canvas canvas,
    String type,
    double x,
    double y,
    int pos,
    double alpha,
    Color color,
    Color clefColor, {
    bool? forcedStemUp,
    bool noFlags = false,
    double? stemTipY,
  }) {
    if (type == 'whole') return;

    // Stem goes up for notes below the middle space (B4 = pos 4).
    final stemUp = forcedStemUp ?? (pos < 5);
    final p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.4;

    final sy = stemTipY ?? (stemUp ? y - _kStem : y + _kStem);

    if (stemUp) {
      // Stem up: attach to right side of note head
      final sx = x + _kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), p);
      if (type != 'half' && !noFlags) {
        _drawFlags(canvas, Offset(sx, sy), true, type, alpha, color, clefColor);
      }
    } else {
      // Stem down: attach to left side of note head
      final sx = x - _kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), p);
      if (type != 'half' && !noFlags) {
        _drawFlags(canvas, Offset(sx, sy), false, type, alpha, color, clefColor);
      }
    }
  }

  // ── Flags (eighth, 16th, 32nd) ────────────────────────────────────────────

  void _drawFlags(
    Canvas canvas,
    Offset tip,
    bool stemUp,
    String type,
    double alpha,
    Color color,
    Color clefColor,
  ) {
    final count = switch (type) {
      'eighth' => 1,
      '16th' => 2,
      '32nd' => 3,
      _ => 0,
    };
    if (count == 0) return;

    final p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < count; i++) {
      final shift = stemUp ? i * _kLS * 0.75 : -i * _kLS * 0.75;
      final s = Offset(tip.dx, tip.dy + shift);
      final cp = Offset(s.dx + _kLS * 1.0, s.dy + (stemUp ? _kLS * 0.6 : -_kLS * 0.6));
      final e = Offset(s.dx + _kLS * 0.55, s.dy + (stemUp ? _kLS * 1.5 : -_kLS * 1.5));
      canvas.drawPath(
        Path()
          ..moveTo(s.dx, s.dy)
          ..quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy),
        p,
      );
    }
  }

  // ── Ledger lines ──────────────────────────────────────────────────────────

  void _drawLedgerLines(Canvas canvas, double x, int pos, double alpha, Color clefColor) {
    final p = Paint()
      ..color = clefColor.withValues(alpha: alpha * 0.7)
      ..strokeWidth = 1.2;
    const hw = _kNRx + 4; // half-width, slightly wider than note head

    // Lines below the staff sit at even positions: -2, -4, -6, …
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = _posToY(lp);
        canvas.drawLine(Offset(x - hw, ly), Offset(x + hw, ly), p);
      }
    }

    // Lines above the staff sit at even positions: 10, 12, 14, …
    if (pos > 8) {
      final highest = pos.isEven ? pos : pos - 1;
      for (int lp = 10; lp <= highest; lp += 2) {
        final ly = _posToY(lp);
        canvas.drawLine(Offset(x - hw, ly), Offset(x + hw, ly), p);
      }
    }
  }

  // ── Augmentation dot ──────────────────────────────────────────────────────

  void _drawDot(Canvas canvas, double x, double y, double alpha, Color clefColor) {
    // Dot sits just to the right of the note head, slightly raised.
    // If the note is on a line, nudge the dot into the space above.
    canvas.drawCircle(
      Offset(x + _kNRx + 4, y - _kLS * 0.25),
      2.0,
      Paint()..color = clefColor.withValues(alpha: alpha),
    );
  }

  // ── Rest symbols ──────────────────────────────────────────────────────────

  void _drawRest(Canvas canvas, double x, String type, Color clefColor) {
    switch (type) {
      case 'whole':
        // Whole rest: filled rectangle hanging below the 4th staff line (D5).
        final ly = _posToY(6); // 4th line from bottom
        canvas.drawRect(
          Rect.fromLTWH(x - _kLS * 0.75, ly, _kLS * 1.5, _kLS * 0.55),
          Paint()..color = clefColor.withValues(alpha: 0.7),
        );
        return;
      case 'half':
        // Half rest: filled rectangle sitting on top of the middle staff line (B4).
        final ly = _posToY(4) - _kLS * 0.55;
        canvas.drawRect(
          Rect.fromLTWH(x - _kLS * 0.75, ly, _kLS * 1.5, _kLS * 0.55),
          Paint()..color = clefColor.withValues(alpha: 0.7),
        );
        return;
      default:
        break;
    }

    // Quarter, eighth, 16th, … use Unicode music symbols.
    final sym = switch (type) {
      'quarter' => '𝄽',
      'eighth' => '𝄾',
      '16th' => '𝄿',
      _ => '𝄽',
    };
    // Centre the rest vertically in the staff.
    _drawText(
      canvas,
      sym,
      Offset(x - _kLS * 0.7, _posToY(5) - _kLS * 1.0),
      fontSize: _kLS * 2.1,
      color: clefColor.withValues(alpha: 0.7),
    );
  }

  // ── Note label (centered inside note head or below) ──────────────────────

  void _drawNoteLabel(
    Canvas canvas,
    MusicNote note,
    double x,
    double y,
    int pos,
    Color color,
    double alpha,
    Color clefColor,
  ) {
    if (!colorProvider.showNoteLabels) return;
    if (!showLetter && !showSolfege) return;

    final raw = note.letterName.replaceAll(RegExp(r'\d'), '');
    final label = showSolfege ? note.solfegeName : raw;

    final filled = note.type != 'whole' && note.type != 'half';

    if (labelsBelow) {
      // Draw label below the note with outline for better visibility
      final stemUp = pos < 5;
      final labelY = stemUp ? y + _kLS * 2.5 : y + _kStem + _kLS * 1.2;
      
      if (coloredLabels) {
        // Use note color for label
        _drawTextWithOutline(
          canvas,
          label,
          Offset(x, labelY),
          fontSize: _kLS * 0.85,
          color: color.withValues(alpha: alpha),
          outlineColor: Theme.of(context).canvasColor.withValues(alpha: alpha * 0.8),
          outlineWidth: 1.8,
          fontWeight: FontWeight.bold,
        );
      } else {
        // Use theme-aware foreground color for label
        _drawTextWithOutline(
          canvas,
          label,
          Offset(x, labelY),
          fontSize: _kLS * 0.85,
          color: clefColor.withValues(alpha: alpha),
          outlineColor: Theme.of(context).canvasColor.withValues(alpha: alpha * 0.8),
          outlineWidth: 1.8,
          fontWeight: FontWeight.bold,
        );
      }
    } else {
      // Draw label inside note head (original behavior)
      final textColor = filled
          ? NoteColors.textColorFor(color).withValues(alpha: alpha)
          : color.withValues(alpha: alpha);

      // Fit font size so long labels (e.g. "Sol") still fit inside the oval.
      final fontSize = label.length > 2 ? _kNRy * 0.95 : _kNRy * 1.15;

      _drawTextCentered(
        canvas,
        label,
        Offset(x, y),
        fontSize: fontSize,
        color: textColor,
        fontWeight: FontWeight.bold,
      );
    }
  }

  // ── Double bar line ───────────────────────────────────────────────────────

  void _drawDoubleBarLine(Canvas canvas, double x, Color color) {
    final thin = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    final thick = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..strokeWidth = 2.8;
    canvas.drawLine(Offset(x - 4, _kTopMargin), Offset(x - 4, _kTopMargin + _kStaffH), thin);
    canvas.drawLine(Offset(x, _kTopMargin), Offset(x, _kTopMargin + _kStaffH), thick);
  }

  // ── Text helpers ──────────────────────────────────────────────────────────

  /// Draws music symbols using Noto Music font.
  void _drawMusicSymbol(
    Canvas canvas,
    String symbol,
    Offset topLeft, {
    double fontSize = 12,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: GoogleFonts.notoMusic(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, topLeft);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset topLeft, {
    double fontSize = 12,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
          fontFamily: 'serif',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, topLeft);
  }

  /// Draws text with its centre at [centre].
  void _drawTextCentered(
    Canvas canvas,
    String text,
    Offset centre, {
    double fontSize = 12,
    Color color = Colors.black,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2),
    );
  }

  /// Draws text with outline for better visibility on any background.
  void _drawTextWithOutline(
    Canvas canvas,
    String text,
    Offset centre, {
    double fontSize = 12,
    Color color = Colors.black,
    Color outlineColor = Colors.white,
    double outlineWidth = 1.8,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth
          ..color = outlineColor,
      ),
    );
    
    final textSpanFill = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      ),
    );

    // Draw outline first
    final tpOutline = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();
    
    final offset = Offset(centre.dx - tpOutline.width / 2, centre.dy - tpOutline.height / 2);
    tpOutline.paint(canvas, offset);

    // Draw fill on top
    final tpFill = TextPainter(
      text: textSpanFill,
      textDirection: TextDirection.ltr,
    )..layout();
    tpFill.paint(canvas, offset);
  }
}

// ── Colour legend ─────────────────────────────────────────────────────────────

/// A compact row showing the colour → note-name mapping for the active scheme.
class _ColorLegend extends StatelessWidget {
  final bool showSolfege;

  const _ColorLegend({this.showSolfege = false});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ColorSchemeProvider>();
    final scheme = provider.activeScheme;
    final showLabels = provider.showNoteLabels;

    // Filter to only show notes that have explicit colors or overrides
    final coloredNotes = kNoteKeys.where((n) => scheme.colors.containsKey(n));
    final overrideKeys = scheme.octaveOverrides.keys.toList()..sort();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...coloredNotes.map((note) {
          final color = scheme.colors[note]!;
          return _LegendCircle(
            label: note,
            color: color,
            showSolfege: showSolfege,
            showLabels: showLabels,
          );
        }),
        ...overrideKeys.map((key) {
          final color = scheme.octaveOverrides[key]!;
          return _LegendCircle(
            label: key,
            color: color,
            showSolfege: showSolfege,
            showLabels: showLabels,
          );
        }),
      ],
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
    // Extract base note for solfege lookup (e.g., 'C5' -> 'C')
    final baseNote = label.replaceAll(RegExp(r'[0-9]'), '');
    final solfege = MusicConstants.stepToSolfege[baseNote] ?? baseNote;
    final textColor =
        color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

    String displayLabel = label;
    if (showSolfege) {
      displayLabel = showSolfege ? '$solfege\n$label' : label;
    }

    return Tooltip(
      message: label,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
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

