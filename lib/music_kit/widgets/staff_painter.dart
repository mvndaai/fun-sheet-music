import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/music_note.dart';
import '../models/measure.dart';
import '../models/instrument_profile.dart';
import '../sheet_music_constants.dart';
import '../utils/note_colors.dart';
import '../utils/staff_layout_helper.dart';

class StaffRowData {
  final List<Measure> measures;
  final int firstNoteIndex;
  final bool isFirstRow;
  final bool isLastRow;
  final int measuresPerRow;
  final Measure? previousMeasure;

  const StaffRowData({
    required this.measures,
    required this.firstNoteIndex,
    required this.isFirstRow,
    required this.isLastRow,
    required this.measuresPerRow,
    this.previousMeasure,
  });
}

class StaffPainter extends CustomPainter {
  final StaffRowData row;
  final int activeNoteIndex;
  final int? ghostNoteIndex;
  final MusicNote? ghostNote;
  final bool showSolfege;
  final bool showLetter;
  final bool labelsBelow;
  final bool coloredLabels;
  final InstrumentProfile instrument;
  final bool showNoteLabels;
  final BuildContext context;
  final double labelRotation;
  final bool showStaffLines;

  StaffPainter({
    required this.row,
    required this.activeNoteIndex,
    this.ghostNoteIndex,
    this.ghostNote,
    required this.showSolfege,
    required this.showLetter,
    required this.labelsBelow,
    required this.coloredLabels,
    required this.instrument,
    required this.showNoteLabels,
    required this.context,
    this.labelRotation = 0,
    this.showStaffLines = true,
  });

  @override
  bool shouldRepaint(StaffPainter old) =>
      old.activeNoteIndex != activeNoteIndex ||
      old.ghostNoteIndex != ghostNoteIndex ||
      old.ghostNote != ghostNote ||
      old.showSolfege != showSolfege ||
      old.showLetter != showLetter ||
      old.labelsBelow != labelsBelow ||
      old.coloredLabels != coloredLabels ||
      old.context != context ||
      old.row != row ||
      old.instrument != instrument ||
      old.showNoteLabels != showNoteLabels ||
      old.labelRotation != labelRotation ||
      old.showStaffLines != showStaffLines;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final clefColor = isDark ? Colors.white70 : Colors.black87;

    final linePaint = Paint()
      ..color = clefColor.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    double x = _drawClefAndTimeSig(canvas, clefColor);
    final double startX = x;
    final availW = size.width - startX;
    final measureW = availW / row.measuresPerRow;

    // Calculate total staff width first to avoid lines overextending
    double totalStaffW = startX;
    final List<double> measureWidths = [];
    for (final m in row.measures) {
      double w = measureW;
      if (m.isPickup) {
        final durBeats = m.notes.fold(0.0, (s, n) => s + n.duration) * (m.beatType / 4.0);
        final ratio = (durBeats / m.beats).clamp(0.25, 0.5);
        w = measureW * ratio;
      }
      measureWidths.add(w);
      totalStaffW += w;
    }

    if (showStaffLines) {
      _drawStaffLines(canvas, totalStaffW, linePaint);
    }

    int noteOffset = row.firstNoteIndex;
    Measure? currentPrevMeasure = row.previousMeasure;

    for (int mi = 0; mi < row.measures.length; mi++) {
      final m = row.measures[mi];
      final currentMeasureW = measureWidths[mi];

      final bool hasTimeSig = (currentPrevMeasure == null || 
          m.beats != currentPrevMeasure.beats || 
          m.beatType != currentPrevMeasure.beatType);

      if (hasTimeSig) {
        _drawTimeSig(canvas, m.beats, m.beatType, x, clefColor);
      }

      if (m.number > 0) {
        _drawMeasureNumber(canvas, m.number, x);
      }
      
      _drawMeasureNotes(canvas, m, x, currentMeasureW, noteOffset, clefColor, hasTimeSig: hasTimeSig);
      
      // Draw ghost note if it belongs to this measure
      if (ghostNoteIndex != null && ghostNote != null) {
        final localGhostIndex = ghostNoteIndex! - noteOffset;
        final bool isLastMeasureInSong = row.isLastRow && mi == row.measures.length - 1;
        
        // Draw if it's inside the measure, or at the very end of the song
        if (localGhostIndex >= 0 && (localGhostIndex < m.notes.length || (isLastMeasureInSong && localGhostIndex == m.notes.length))) {
          final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
          
          double cumulativeDurationBeforeGhost = 0;
          for (int i = 0; i < localGhostIndex; i++) {
            if (!m.notes[i].isChordContinuation) {
              cumulativeDurationBeforeGhost += m.notes[i].duration;
            }
          }
          
          final ghostX = StaffLayoutHelper.getNoteX(
            measure: m,
            startX: x,
            measureWidth: currentMeasureW,
            hasTimeSig: hasTimeSig,
            cumulativeDuration: cumulativeDurationBeforeGhost,
            displayNotes: displayNotes,
          );
          
          if (ghostNote!.isRest) {
            _drawRest(canvas, ghostX, ghostNote!.type, clefColor, note: ghostNote, isActive: true);
          } else {
            _drawNote(canvas, ghostNote!, ghostX, false, false, clefColor, opacity: 0.3);
          }
        }
      }

      noteOffset += m.notes.length;
      x += currentMeasureW;
      currentPrevMeasure = m;

      final isLastMeasureInRow = mi == row.measures.length - 1;
      if (isLastMeasureInRow && row.isLastRow && showStaffLines) {
        _drawDoubleBarLine(canvas, x, clefColor);
      } else if (showStaffLines) {
        final bp = Paint()
          ..color = clefColor.withValues(alpha: 0.6)
          ..strokeWidth = isLastMeasureInRow ? 2.0 : 1.2;
        canvas.drawLine(
          Offset(x, kTopMargin),
          Offset(x, kTopMargin + kStaffH),
          bp,
        );
      }
    }
  }

  void _drawStaffLines(Canvas canvas, double width, Paint p) {
    for (int i = 0; i < 5; i++) {
      final y = kTopMargin + i * kLS;
      canvas.drawLine(Offset(0, y), Offset(width, y), p);
    }
  }

  double _drawClefAndTimeSig(Canvas canvas, Color color) {
    final g4y = posToY(2);
    const clefFontSize = kLS * 3.8;
    _drawMusicSymbol(
      canvas,
      '𝄞',
      Offset(2, g4y - clefFontSize * 1.1),
      fontSize: clefFontSize,
      color: color,
    );
    return kClefW;
  }

  void _drawTimeSig(Canvas canvas, int beats, int beatType, double x, Color color) {
    const tsFontSize = kLS * 1.55;
    _drawText(
      canvas,
      '$beats',
      Offset(x + 2, kTopMargin + kLS * 0.1),
      fontSize: tsFontSize,
      color: color,
      fontWeight: FontWeight.bold,
    );
    _drawText(
      canvas,
      '$beatType',
      Offset(x + 2, kTopMargin + kStaffH / 2 + kLS * 0.1),
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

  void _drawMeasureNotes(
    Canvas canvas,
    Measure m,
    double startX,
    double measureWidth,
    int noteOffset,
    Color clefColor, {
    bool hasTimeSig = false,
  }) {
    final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
    
    double cumulativeDuration = 0.0;
    for (int ni = 0; ni < displayNotes.length; ni++) {
      final note = displayNotes[ni];
      final globalIdx = noteOffset + ni;
      final isActive = globalIdx == activeNoteIndex;
      final isPast = activeNoteIndex >= 0 && globalIdx < activeNoteIndex;
      
      final noteX = StaffLayoutHelper.getNoteX(
        measure: m,
        startX: startX,
        measureWidth: measureWidth,
        hasTimeSig: hasTimeSig,
        cumulativeDuration: cumulativeDuration,
        displayNotes: displayNotes,
      );

      if (note.isRest) {
        _drawRest(canvas, noteX, note.type, clefColor, isActive: isActive, isPast: isPast, note: note);
      } else {
        bool isBeamed = false;
        if (note.beam != null) {
          // Find the direction for this entire beam group
          int startOfBeam = ni;
          while (startOfBeam > 0 && displayNotes[startOfBeam].beam != 'begin') {
            startOfBeam--;
          }
          final beamStartNote = displayNotes[startOfBeam];
          // Determine stem direction based on the first note of the beam
          // Standard rule: furthest from middle line, but first-note is a good simple proxy
          final beamStemUp = staffPos(beamStartNote.step, beamStartNote.octave) < 4;

          if (note.beam == 'begin' || note.beam == 'continue') {
            int nextNi = ni + 1;
            MusicNote? nextNote;
            double nextNoteOffset = note.duration;
            while (nextNi < displayNotes.length) {
              final candidate = displayNotes[nextNi];
              if (!candidate.isRest) {
                nextNote = candidate;
                break;
              }
              nextNoteOffset += candidate.duration;
              nextNi++;
            }

            if (nextNote != null && (nextNote.beam == 'continue' || nextNote.beam == 'end')) {
              isBeamed = true;
              final nextX = StaffLayoutHelper.getBeamEndX(
                measure: m,
                startX: startX,
                measureWidth: measureWidth,
                hasTimeSig: hasTimeSig,
                cumulativeDuration: cumulativeDuration,
                nextNoteOffset: nextNoteOffset,
                displayNotes: displayNotes,
              );
              
              final y = posToY(staffPos(note.step, note.octave));
              final nextY = posToY(staffPos(nextNote.step, nextNote.octave));
              final stemTipY = y + (beamStemUp ? -kStem : kStem);
              final nextStemTipY = nextY + (beamStemUp ? -kStem : kStem);

              _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
                forcedStemUp: beamStemUp, 
                noFlags: true, 
                stemTipY: stemTipY
              );

              final noteColor = instrument.colorForNote(
                note.step,
                note.alter,
                octave: note.octave,
                context: context,
              );

              final beamPaint = Paint()
                ..color = noteColor.withValues(alpha: isPast ? 0.3 : 0.7)
                ..strokeWidth = 3.5;
              
              final beamStartX = noteX + (beamStemUp ? kNRx : -kNRx);
              final beamEndX = nextX + (beamStemUp ? kNRx : -kNRx);
              canvas.drawLine(Offset(beamStartX, stemTipY), Offset(beamEndX, nextStemTipY), beamPaint);
            }
          } else if (note.beam == 'end') {
            final y = posToY(staffPos(note.step, note.octave));
            final stemTipY = y + (beamStemUp ? -kStem : kStem);
            _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
              forcedStemUp: beamStemUp,
              noFlags: true, 
              stemTipY: stemTipY
            );
            isBeamed = true;
          }
        }

        if (!isBeamed) {
          _drawNote(canvas, note, noteX, isActive, isPast, clefColor);
        }
      }
      cumulativeDuration += note.duration;
    }
  }

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
    double opacity = 1.0,
  }) {
    final pos = staffPos(note.step, note.octave);
    final y = posToY(pos);
    final color = instrument.colorForNote(
      note.step,
      note.alter,
      octave: note.octave,
      context: context,
    );
    final alpha = (isPast ? 0.30 : 1.0) * opacity;

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
    if (note.isDotted) _drawDot(canvas, x, y, alpha, color);
    _drawNoteLabel(canvas, note, x, y, pos, color, alpha, clefColor);
  }

  void _drawAccidental(Canvas canvas, double alter, double x, double y, double alpha, Color clefColor) {
    if (alter == 0) return;
    _drawText(
      canvas,
      alter > 0 ? '♯' : '♭',
      Offset(x - kNRx * 2 - 4, y - kLS * 0.95),
      fontSize: kLS * 1.3,
      color: clefColor.withValues(alpha: alpha),
    );
  }

  void _drawNoteHead(Canvas canvas, String type, double x, double y, Color color, double alpha, bool isActive) {
    final filled = type != 'whole' && type != 'half' && type != 'breve';
    final rect = Rect.fromCenter(center: Offset(x, y), width: kNRx * 2, height: kNRy * 2);

    if (isActive) {
      canvas.drawOval(
        rect.inflate(6),
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    if (type == 'breve') {
      final p = Paint()
        ..color = color.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawOval(rect, Paint()..color = color.withValues(alpha: alpha * 0.15));
      canvas.drawOval(rect, p);
      // Breve vertical bars
      canvas.drawLine(Offset(x - kNRx - 2, y - kNRy), Offset(x - kNRx - 2, y + kNRy), p);
      canvas.drawLine(Offset(x + kNRx + 2, y - kNRy), Offset(x + kNRx + 2, y + kNRy), p);
      return;
    }

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-0.20);
    canvas.translate(-x, -y);

    if (filled) {
      canvas.drawOval(rect, Paint()..color = color.withValues(alpha: alpha));
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
      canvas.drawOval(rect, Paint()..color = color.withValues(alpha: alpha * 0.15));
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
    if (type == 'whole' || type == 'breve') return;
    final stemUp = forcedStemUp ?? (pos < 5);
    final p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.4;
    final sy = stemTipY ?? (stemUp ? y - kStem : y + kStem);

    if (stemUp) {
      final sx = x + kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), p);
      if (type != 'half' && !noFlags) {
        _drawFlags(canvas, Offset(sx, sy), true, type, alpha, color, clefColor);
      }
    } else {
      final sx = x - kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), p);
      if (type != 'half' && !noFlags) {
        _drawFlags(canvas, Offset(sx, sy), false, type, alpha, color, clefColor);
      }
    }
  }

  void _drawFlags(Canvas canvas, Offset tip, bool stemUp, String type, double alpha, Color color, Color clefColor) {
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
      final shift = stemUp ? i * kLS * 0.75 : -i * kLS * 0.75;
      final s = Offset(tip.dx, tip.dy + shift);
      final cp = Offset(s.dx + kLS * 1.0, s.dy + (stemUp ? kLS * 0.6 : -kLS * 0.6));
      final e = Offset(s.dx + kLS * 0.55, s.dy + (stemUp ? kLS * 1.5 : -kLS * 1.5));
      canvas.drawPath(Path()..moveTo(s.dx, s.dy)..quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy), p);
    }
  }

  void _drawLedgerLines(Canvas canvas, double x, int pos, double alpha, Color clefColor) {
    final p = Paint()..color = clefColor.withValues(alpha: alpha * 0.7)..strokeWidth = 1.2;
    const hw = kNRx + 4;
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = posToY(lp);
        canvas.drawLine(Offset(x - hw, ly), Offset(x + hw, ly), p);
      }
    }
    if (pos > 8) {
      final highest = pos.isEven ? pos : pos - 1;
      for (int lp = 10; lp <= highest; lp += 2) {
        final ly = posToY(lp);
        canvas.drawLine(Offset(x - hw, ly), Offset(x + hw, ly), p);
      }
    }
  }

  void _drawDot(Canvas canvas, double x, double y, double alpha, Color color) {
    canvas.drawCircle(Offset(x + kNRx + 4, y - kLS * 0.25), 2.0, Paint()..color = color.withValues(alpha: alpha));
  }

  void _drawRest(Canvas canvas, double x, String type, Color clefColor, {bool isActive = false, bool isPast = false, MusicNote? note}) {
    final alpha = isPast ? 0.3 : 0.7;
    final color = isActive ? Colors.orange : clefColor.withValues(alpha: alpha);
    
    final hasDot = note != null && note.dot > 0;

    switch (type) {
      case 'breve':
        final ly = posToY(5) - kLS * 0.5;
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.4, ly, kLS * 0.8, kLS * 1.0), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.5, ly + kLS * 0.5, alpha, color);
        return;
      case 'whole':
        final ly = posToY(6);
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.75, ly, kLS * 1.5, kLS * 0.55), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.75, ly + kLS * 0.25, alpha, color);
        return;
      case 'half':
        final ly = posToY(4) - kLS * 0.55;
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.75, ly, kLS * 1.5, kLS * 0.55), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.75, ly + kLS * 0.25, alpha, color);
        return;
      default:
        break;
    }
    
    final sym = switch (type) {
      'quarter' => '𝄽',
      'eighth' => '𝄾',
      '16th' => '𝄿',
      '32nd' => '𝅀',
      '64th' => '𝅁',
      _ => '𝄽'
    };
    final y = posToY(5) - kLS * 1.0;
    _drawText(canvas, sym, Offset(x - kLS * 0.7, y), fontSize: kLS * 2.1, color: color);

    if (hasDot) {
      _drawDot(canvas, x + kLS * 0.4, y + kLS * 0.8, alpha, color);
    }
  }

  void _drawNoteLabel(Canvas canvas, MusicNote note, double x, double y, int pos, Color color, double alpha, Color clefColor) {
    if (!showNoteLabels) return;
    if (!showLetter && !showSolfege) return;
    final raw = note.letterName.replaceAll(RegExp(r'\d'), '');
    final label = showSolfege ? note.solfegeName : raw;
    final filled = note.type != 'whole' && note.type != 'half' && note.type != 'breve';

    if (labelsBelow) {
      final stemUp = pos < 5;
      final labelY = stemUp ? y + kLS * 2.5 : y + kStem + kLS * 1.2;
      _drawTextWithOutline(
        canvas, label, Offset(x, labelY), fontSize: kLS * 0.85,
        color: coloredLabels ? color.withValues(alpha: alpha) : clefColor.withValues(alpha: alpha),
        outlineColor: Theme.of(context).canvasColor.withValues(alpha: alpha * 0.8),
        outlineWidth: 1.8, fontWeight: FontWeight.bold,
      );
    } else {
      final textColor = filled ? NoteColors.textColorFor(color).withValues(alpha: alpha) : color.withValues(alpha: alpha);
      final fontSize = label.length > 2 ? kNRy * 0.95 : kNRy * 1.15;
      _drawTextCentered(canvas, label, Offset(x, y), fontSize: fontSize, color: textColor, fontWeight: FontWeight.bold);
    }
  }

  void _drawDoubleBarLine(Canvas canvas, double x, Color color) {
    final thin = Paint()..color = color.withValues(alpha: 0.6)..strokeWidth = 1.2;
    final thick = Paint()..color = color.withValues(alpha: 0.8)..strokeWidth = 2.8;
    canvas.drawLine(Offset(x - 4, kTopMargin), Offset(x - 4, kTopMargin + kStaffH), thin);
    canvas.drawLine(Offset(x, kTopMargin), Offset(x, kTopMargin + kStaffH), thick);
  }

  void _drawMusicSymbol(Canvas canvas, String symbol, Offset topLeft, {double fontSize = 12, Color color = Colors.black, FontWeight fontWeight = FontWeight.normal}) {
    final tp = TextPainter(text: TextSpan(text: symbol, style: GoogleFonts.notoMusic(fontSize: fontSize, color: color, fontWeight: fontWeight)), textDirection: TextDirection.ltr)..layout();
    if (labelRotation != 0) {
      canvas.save();
      final center = Offset(topLeft.dx + tp.width / 2, topLeft.dy + tp.height / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(labelRotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, topLeft);
    }
  }

  void _drawText(Canvas canvas, String text, Offset topLeft, {double fontSize = 12, Color color = Colors.black, FontWeight fontWeight = FontWeight.normal}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight, fontFamily: 'serif')), textDirection: TextDirection.ltr)..layout();
    if (labelRotation != 0) {
      canvas.save();
      final center = Offset(topLeft.dx + tp.width / 2, topLeft.dy + tp.height / 2);
      canvas.translate(center.dx, center.dy);
      canvas.rotate(labelRotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, topLeft);
    }
  }

  void _drawTextCentered(Canvas canvas, String text, Offset centre, {double fontSize = 12, Color color = Colors.black, FontWeight fontWeight = FontWeight.normal}) {
    final tp = TextPainter(text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight)), textDirection: TextDirection.ltr)..layout();
    if (labelRotation != 0) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(labelRotation);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    } else {
      tp.paint(canvas, Offset(centre.dx - tp.width / 2, centre.dy - tp.height / 2));
    }
  }

  void _drawTextWithOutline(Canvas canvas, String text, Offset centre, {double fontSize = 12, Color color = Colors.black, Color outlineColor = Colors.white, double outlineWidth = 1.8, FontWeight fontWeight = FontWeight.normal}) {
    final textSpan = TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: fontWeight, foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = outlineWidth..color = outlineColor));
    final textSpanFill = TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight));
    final tpOutline = TextPainter(text: textSpan, textDirection: TextDirection.ltr)..layout();
    final tpFill = TextPainter(text: textSpanFill, textDirection: TextDirection.ltr)..layout();
    
    final offsetInside = Offset(-tpOutline.width / 2, -tpOutline.height / 2);
    final offsetOutside = Offset(centre.dx - tpOutline.width / 2, centre.dy - tpOutline.height / 2);

    if (labelRotation != 0) {
      canvas.save();
      canvas.translate(centre.dx, centre.dy);
      canvas.rotate(labelRotation);
      tpOutline.paint(canvas, offsetInside);
      tpFill.paint(canvas, offsetInside);
      canvas.restore();
    } else {
      tpOutline.paint(canvas, offsetOutside);
      tpFill.paint(canvas, offsetOutside);
    }
  }
}
