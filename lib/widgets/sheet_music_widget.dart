import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../models/music_note.dart';
import '../models/measure.dart';
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
  final int measuresPerRow;

  const SheetMusicWidget({
    super.key,
    required this.song,
    this.activeNoteIndex = -1,
    this.showSolfege = false,
    this.showLetter = true,
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
          // ── Song header ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (song.composer.isNotEmpty)
                  Text(
                    song.composer,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  ),
              ],
            ),
          ),
          const Divider(),

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
            ),
          ),
        ],
      ),
    );
  }

  List<_RowData> _buildRows() {
    final rows = <_RowData>[];
    int noteOffset = 0;
    for (int i = 0; i < song.measures.length; i += measuresPerRow) {
      final end = (i + measuresPerRow).clamp(0, song.measures.length);
      final batch = song.measures.sublist(i, end);
      rows.add(_RowData(
        measures: batch,
        firstNoteIndex: noteOffset,
        isFirstRow: i == 0,
        isLastRow: end == song.measures.length,
      ));
      noteOffset += batch.fold(0, (s, m) => s + m.playableNotes.length);
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

  const _RowData({
    required this.measures,
    required this.firstNoteIndex,
    required this.isFirstRow,
    required this.isLastRow,
  });
}

// ── Staff row widget ─────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  final _RowData row;
  final int activeNoteIndex;
  final bool showSolfege;
  final bool showLetter;

  const _StaffRow({
    required this.row,
    required this.activeNoteIndex,
    required this.showSolfege,
    required this.showLetter,
  });

  @override
  Widget build(BuildContext context) {
    final cp = context.watch<ColorSchemeProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (_, constraints) => SizedBox(
          height: _kRowH,
          width: constraints.maxWidth,
          child: CustomPaint(
            painter: _StaffPainter(
              row: row,
              activeNoteIndex: activeNoteIndex,
              showSolfege: showSolfege,
              showLetter: showLetter,
              colorProvider: cp,
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
  final ColorSchemeProvider colorProvider;

  _StaffPainter({
    required this.row,
    required this.activeNoteIndex,
    required this.showSolfege,
    required this.showLetter,
    required this.colorProvider,
  }) : super(repaint: colorProvider);

  @override
  bool shouldRepaint(_StaffPainter old) =>
      old.activeNoteIndex != activeNoteIndex ||
      old.showSolfege != showSolfege ||
      old.showLetter != showLetter ||
      old.row != row;

  // ── paint ──────────────────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawStaffLines(canvas, size.width);

    double x = _drawClefAndTimeSig(canvas);

    // Distribute available width evenly among all note/rest slots.
    final slotCounts = row.measures
        .map((m) => math.max(1, m.notes.where((n) => !n.isChordContinuation).length))
        .toList();
    final totalSlots = slotCounts.fold(0, (s, c) => s + c);
    final availW = size.width - x;
    final slotW = totalSlots > 0 ? (availW / totalSlots) : 24.0;

    int noteOffset = row.firstNoteIndex;
    for (int mi = 0; mi < row.measures.length; mi++) {
      final m = row.measures[mi];
      final mSlots = slotCounts[mi];
      final measureW = mSlots * slotW;

      _drawMeasureNumber(canvas, m.number, x);
      _drawMeasureNotes(canvas, m, x, slotW, noteOffset);
      noteOffset += m.playableNotes.length;
      x += measureW;

      // Bar line
      final isLastMeasureInRow = mi == row.measures.length - 1;
      if (isLastMeasureInRow && row.isLastRow) {
        _drawDoubleBarLine(canvas, x);
      } else {
        final bp = Paint()
          ..color = Colors.grey.shade700
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

  void _drawStaffLines(Canvas canvas, double width) {
    final p = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 1.0;
    for (int i = 0; i < 5; i++) {
      final y = _kTopMargin + i * _kLS;
      canvas.drawLine(Offset(0, y), Offset(width, y), p);
    }
  }

  // ── Treble clef + optional time signature ─────────────────────────────────

  /// Draws the clef (and time sig on the first row) and returns the x position
  /// where note content begins.
  double _drawClefAndTimeSig(Canvas canvas) {
    // '𝄞' (U+1D11E) treble clef — positioned so the G4 curl sits on the G4 line.
    // G4 is at staff position 2 → y = _posToY(2).
    final g4y = _posToY(2);
    const clefFontSize = _kLS * 5.8;
    // Place the text so the curl (≈50% from top of glyph) aligns with G4.
    _drawText(
      canvas,
      '𝄞',
      Offset(2, g4y - clefFontSize * 0.52),
      fontSize: clefFontSize,
      color: Colors.grey.shade800,
    );

    double x = _kClefW;

    if (row.isFirstRow && row.measures.isNotEmpty) {
      final beats = row.measures.first.beats;
      final beatType = row.measures.first.beatType;
      const tsFontSize = _kLS * 1.55;
      // Top number (beats) sits in the upper half of the staff.
      _drawText(
        canvas,
        '$beats',
        Offset(x + 2, _kTopMargin + _kLS * 0.1),
        fontSize: tsFontSize,
        color: Colors.grey.shade800,
        fontWeight: FontWeight.bold,
      );
      // Bottom number (beat type) sits in the lower half.
      _drawText(
        canvas,
        '$beatType',
        Offset(x + 2, _kTopMargin + _kStaffH / 2 + _kLS * 0.1),
        fontSize: tsFontSize,
        color: Colors.grey.shade800,
        fontWeight: FontWeight.bold,
      );
      x += _kTimeSigW;
    }

    return x;
  }

  // ── Measure number ─────────────────────────────────────────────────────────

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
    double slotW,
    int noteOffset,
  ) {
    final displayNotes =
        m.notes.where((n) => !n.isChordContinuation).toList();
    int playableIdx = 0;

    for (int ni = 0; ni < displayNotes.length; ni++) {
      final note = displayNotes[ni];
      final noteX = startX + (ni + 0.5) * slotW;

      if (note.isRest) {
        _drawRest(canvas, noteX, note.type);
      } else {
        final globalIdx = noteOffset + playableIdx;
        final isActive = globalIdx == activeNoteIndex;
        final isPast = activeNoteIndex >= 0 && globalIdx < activeNoteIndex;
        _drawNote(canvas, note, noteX, isActive, isPast);
        playableIdx++;
      }
    }
  }

  // ── Single pitched note ────────────────────────────────────────────────────

  void _drawNote(
    Canvas canvas,
    MusicNote note,
    double x,
    bool isActive,
    bool isPast,
  ) {
    final pos = _staffPos(note.step, note.octave);
    final y = _posToY(pos);
    final color = colorProvider.colorForNote(note.step, note.alter, octave: note.octave);
    final alpha = isPast ? 0.30 : 1.0;

    _drawLedgerLines(canvas, x, pos, alpha);
    _drawAccidental(canvas, note.alter, x, y, alpha);
    _drawNoteHead(canvas, note.type, x, y, color, alpha, isActive);
    _drawStem(canvas, note.type, x, y, pos, alpha);
    if (note.isDotted) _drawDot(canvas, x, y, alpha);
    _drawNoteLabel(canvas, note, x, y, color, alpha);
  }

  // ── Accidental (sharp / flat) ──────────────────────────────────────────────

  void _drawAccidental(
    Canvas canvas,
    double alter,
    double x,
    double y,
    double alpha,
  ) {
    if (alter == 0) return;
    _drawText(
      canvas,
      alter > 0 ? '♯' : '♭',
      Offset(x - _kNRx * 2 - 4, y - _kLS * 0.95),
      fontSize: _kLS * 1.3,
      color: Colors.black.withValues(alpha: alpha),
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
  ) {
    if (type == 'whole') return;

    // Stem goes up for notes below the middle space (B4 = pos 4).
    final stemUp = pos < 5;
    final p = Paint()
      ..color = Colors.black.withValues(alpha: alpha)
      ..strokeWidth = 1.4;

    if (stemUp) {
      final sx = x + _kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, y - _kStem), p);
      if (type != 'half') {
        _drawFlags(canvas, Offset(sx, y - _kStem), true, type, alpha);
      }
    } else {
      final sx = x - _kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, y + _kStem), p);
      if (type != 'half') {
        _drawFlags(canvas, Offset(sx, y + _kStem), false, type, alpha);
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
  ) {
    final count = switch (type) {
      'eighth' => 1,
      '16th' => 2,
      '32nd' => 3,
      _ => 0,
    };
    if (count == 0) return;

    final p = Paint()
      ..color = Colors.black.withValues(alpha: alpha)
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

  void _drawLedgerLines(Canvas canvas, double x, int pos, double alpha) {
    final p = Paint()
      ..color = Colors.grey.shade700.withValues(alpha: alpha)
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

  void _drawDot(Canvas canvas, double x, double y, double alpha) {
    // Dot sits just to the right of the note head, slightly raised.
    // If the note is on a line, nudge the dot into the space above.
    canvas.drawCircle(
      Offset(x + _kNRx + 4, y - _kLS * 0.25),
      2.0,
      Paint()..color = Colors.black.withValues(alpha: alpha),
    );
  }

  // ── Rest symbols ──────────────────────────────────────────────────────────

  void _drawRest(Canvas canvas, double x, String type) {
    switch (type) {
      case 'whole':
        // Whole rest: filled rectangle hanging below the 4th staff line (D5).
        final ly = _posToY(6); // 4th line from bottom
        canvas.drawRect(
          Rect.fromLTWH(x - _kLS * 0.75, ly, _kLS * 1.5, _kLS * 0.55),
          Paint()..color = Colors.grey.shade700,
        );
        return;
      case 'half':
        // Half rest: filled rectangle sitting on top of the middle staff line (B4).
        final ly = _posToY(4) - _kLS * 0.55;
        canvas.drawRect(
          Rect.fromLTWH(x - _kLS * 0.75, ly, _kLS * 1.5, _kLS * 0.55),
          Paint()..color = Colors.grey.shade700,
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
      color: Colors.grey.shade700,
    );
  }

  // ── Note label (centered inside note head) ────────────────────────────────

  void _drawNoteLabel(
    Canvas canvas,
    MusicNote note,
    double x,
    double y,
    Color color,
    double alpha,
  ) {
    if (!colorProvider.showNoteLabels) return;
    if (!showLetter && !showSolfege) return;

    final raw = note.letterName.replaceAll(RegExp(r'\d'), '');
    final label = showSolfege ? note.solfegeName : raw;

    final filled = note.type != 'whole' && note.type != 'half';
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

  // ── Double bar line ───────────────────────────────────────────────────────

  void _drawDoubleBarLine(Canvas canvas, double x) {
    final thin = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 1.2;
    final thick = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 2.8;
    canvas.drawLine(Offset(x - 4, _kTopMargin), Offset(x - 4, _kTopMargin + _kStaffH), thin);
    canvas.drawLine(Offset(x, _kTopMargin), Offset(x, _kTopMargin + _kStaffH), thick);
  }

  // ── Text helpers ──────────────────────────────────────────────────────────

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
}

// ── Colour legend ─────────────────────────────────────────────────────────────

/// A compact row showing the colour → note-name mapping for the active scheme.
class _ColorLegend extends StatelessWidget {
  final bool showSolfege;

  const _ColorLegend({this.showSolfege = false});

  static const _naturalNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

  @override
  Widget build(BuildContext context) {
    final scheme = context.watch<ColorSchemeProvider>().activeScheme;
    final showLabels = context.watch<ColorSchemeProvider>().showNoteLabels;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _naturalNotes.map((note) {
        final color = scheme.colors[note] ?? Colors.grey;
        final solfege = MusicConstants.stepToSolfege[note] ?? note;
        final textColor =
            color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
        final label = showSolfege ? '$solfege\n$note' : note;
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: showLabels
              ? Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                )
              : null,
        );
      }).toList(),
    );
  }
}

