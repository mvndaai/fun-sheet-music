import 'dart:math' as math;
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

  final bool extendLines;

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
    this.extendLines = false,
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
      old.row != row ||
      old.instrument != instrument ||
      old.showNoteLabels != showNoteLabels ||
      old.labelRotation != labelRotation ||
      old.showStaffLines != showStaffLines ||
      old.extendLines != extendLines;

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseClefColor = isDark ? Colors.white70 : Colors.black87;
    
    // If there are real measures in this row, draw clef full opacity.
    // In game mode, we use buffer placeholders, so we check if any real measures exist.
    final bool hasRealMeasures = row.measures.any((m) => !m.isPlaceholder);
    final clefColor = hasRealMeasures ? baseClefColor : baseClefColor.withValues(alpha: 0.1);

    double x = _drawClefAndTimeSig(canvas, clefColor);
    final double startX = x;
    final availW = size.width - startX;
    final measureW = availW / row.measuresPerRow;

    // Calculate total staff width first to avoid lines overextending
    final List<double> measureWidths = [];
    Measure? currentPrevMeasureForW = row.previousMeasure;
    for (final m in row.measures) {
      double w = measureW;
      final bool hasTimeSig = (currentPrevMeasureForW == null || 
          m.beats != currentPrevMeasureForW.beats || 
          m.beatType != currentPrevMeasureForW.beatType);

      if (m.isPickup) {
        final durBeats = m.notes.fold(0.0, (s, n) => s + n.duration) * (m.beatType / 4.0);
        // Increase min ratio for pickups to prevent crowding, especially with few notes.
        final minRatio = (m.notes.length <= 2) ? 0.4 : 0.3;
        final ratio = (durBeats / m.beats).clamp(minRatio, 0.6);
        w = measureW * ratio;
      }
      
      // Ensure enough space for time signature + breathing room for notes
      if (hasTimeSig) {
        const minWForTimeSig = StaffLayoutHelper.kTimeSigReservedW + 
                               (StaffLayoutHelper.kMeasurePadding * 2) + 
                               (kNRx * 5); // Clef/ts + padding + comfortable note space
        if (w < minWForTimeSig) w = minWForTimeSig;
      }

      measureWidths.add(w);
      currentPrevMeasureForW = m;
    }

    if (showStaffLines) {
      final bool firstIsPlaceholder = row.measures.isNotEmpty && row.measures.first.isPlaceholder;
      final clefStaffPaint = Paint()
        ..color = baseClefColor.withValues(alpha: firstIsPlaceholder ? 0.05 : 0.4)
        ..strokeWidth = 1.0;
      for (int i = 0; i < 5; i++) {
        final y = kTopMargin + i * kLS;
        canvas.drawLine(Offset(extendLines ? -2000 : 0, y), Offset(startX, y), clefStaffPaint);
      }
    }

    int noteOffset = row.firstNoteIndex;
    Measure? currentPrevMeasure = row.previousMeasure;

    for (int mi = 0; mi < row.measures.length; mi++) {
      final m = row.measures[mi];
      final currentMeasureW = measureWidths[mi];

      if (showStaffLines) {
        final measureStaffPaint = Paint()
          ..color = baseClefColor.withValues(alpha: m.isPlaceholder ? 0.05 : 0.4)
          ..strokeWidth = 1.0;
        for (int i = 0; i < 5; i++) {
          final y = kTopMargin + i * kLS;
          canvas.drawLine(Offset(x, y), Offset(x + currentMeasureW, y), measureStaffPaint);
        }
      }

      final bool hasTimeSig = (currentPrevMeasure == null || 
          m.beats != currentPrevMeasure.beats || 
          m.beatType != currentPrevMeasure.beatType);

      if (hasTimeSig) {
        _drawTimeSig(canvas, m.beats, m.beatType, x, clefColor);
      }

      if (m.number > 0 && !m.isPlaceholder) {
        _drawMeasureNumber(canvas, m.number, x);
      }
      
      _drawMeasureNotes(canvas, m, mi, measureWidths, size.width, x, currentMeasureW, noteOffset, clefColor, hasTimeSig: hasTimeSig);
      
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
            noteDuration: ghostNote!.duration,
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
      if (isLastMeasureInRow && row.isLastRow && !m.isPlaceholder && showStaffLines) {
        _drawDoubleBarLine(canvas, x, clefColor);
        if (extendLines) {
          final measureStaffPaint = Paint()
            ..color = baseClefColor.withValues(alpha: 0.4)
            ..strokeWidth = 1.0;
          for (int i = 0; i < 5; i++) {
            final y = kTopMargin + i * kLS;
            canvas.drawLine(Offset(x, y), Offset(x + 2000, y), measureStaffPaint);
          }
        }
      } else if (showStaffLines) {
        final bp = Paint()
          ..color = baseClefColor.withValues(alpha: m.isPlaceholder ? 0.05 : 0.6)
          ..strokeWidth = (isLastMeasureInRow && !row.isLastRow) ? 2.0 : 1.2;
        canvas.drawLine(
          Offset(x, kTopMargin),
          Offset(x, kTopMargin + kStaffH),
          bp,
        );
      }
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
    int mi,
    List<double> measureWidths,
    double totalWidth,
    double startX,
    double measureWidth,
    int noteOffset,
    Color clefColor, {
    bool hasTimeSig = false,
  }) {
    final displayNotes = m.notes.where((n) => !n.isChordContinuation).toList();
    final List<({MusicNote note, double x, double y, int pos, Color color, double alpha, double? stemTipY})> labelsToDraw = [];
    
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
        noteDuration: note.duration,
        displayNotes: displayNotes,
      );

      if (note.isRest) {
        if (!note.isPlaceholder) {
          _drawRest(canvas, noteX, note.type, clefColor, isActive: isActive, isPast: isPast, note: note);
        }
      } else {
        final pos = staffPos(note.step, note.octave);
        final y = posToY(pos);
        final color = instrument.colorForNote(
          note.step,
          note.alter,
          octave: note.octave,
          context: context,
        );
        final alpha = isPast ? 0.30 : 1.0;

        bool isBeamed = false;
        if (note.beam != null) {
          // 1. Find the bounds of the current beam group
          int startOfBeam = ni;
          while (startOfBeam > 0 && displayNotes[startOfBeam].beam != 'begin') {
            startOfBeam--;
          }
          int endOfBeam = ni;
          while (endOfBeam < displayNotes.length - 1 && displayNotes[endOfBeam].beam != 'end') {
            endOfBeam++;
          }
          final beamNotes = displayNotes.sublist(startOfBeam, endOfBeam + 1);

          // 2. Determine stem direction: majority rule
          int upCount = 0;
          int downCount = 0;
          int groupMinPos = 1000;
          int groupMaxPos = -1000;
          for (final bn in beamNotes) {
            final p = staffPos(bn.step, bn.octave);
            if (p < 4) { upCount++; } else { downCount++; }
            if (p < groupMinPos) groupMinPos = p;
            if (p > groupMaxPos) groupMaxPos = p;
          }
          // If average position is below middle line (4), stems UP
          bool beamStemUp = (groupMinPos + groupMaxPos) < 8;
          if (upCount != downCount) beamStemUp = upCount > downCount;

          // 3. Calculate X positions for the whole beam group to handle slanting
          double firstNoteX = 0, lastNoteX = 0, tempDur = 0;
          for (int i = 0; i < displayNotes.length; i++) {
            if (i == startOfBeam || i == endOfBeam) {
              final xPos = StaffLayoutHelper.getNoteX(
                measure: m, startX: startX, measureWidth: measureWidth,
                hasTimeSig: hasTimeSig, cumulativeDuration: tempDur,
                noteDuration: displayNotes[i].duration, displayNotes: displayNotes,
              );
              if (i == startOfBeam) firstNoteX = xPos;
              if (i == endOfBeam) lastNoteX = xPos;
            }
            tempDur += displayNotes[i].duration;
          }

          // 4. Calculate slanted beam Y positions
          final firstNotePos = staffPos(beamNotes.first.step, beamNotes.first.octave);
          final lastNotePos = staffPos(beamNotes.last.step, beamNotes.last.octave);
          
          double startBeamY, endBeamY;
          final double slant = ((lastNotePos - firstNotePos) * (kLS / 4)).clamp(-kLS, kLS);

          if (beamStemUp) {
            // Beam is ABOVE. Use highest note (maxPos).
            double refY = posToY(math.max(groupMaxPos, 4)) - kStem;
            startBeamY = refY + slant / 2;
            endBeamY = refY - slant / 2;
          } else {
            // Beam is BELOW. Use lowest note (minPos).
            double refY = posToY(math.min(groupMinPos, 4)) + kStem;
            startBeamY = refY + slant / 2;
            endBeamY = refY - slant / 2;
          }

          // Interpolate current note's beam Y
          double ratio = (lastNoteX == firstNoteX) ? 0 : (noteX - firstNoteX) / (lastNoteX - firstNoteX);
          double currentNoteBeamY = startBeamY + (endBeamY - startBeamY) * ratio;

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
                nextNoteDuration: nextNote.duration,
                displayNotes: displayNotes,
              );
              
              double nextRatio = (lastNoteX == firstNoteX) ? 1 : (nextX - firstNoteX) / (lastNoteX - firstNoteX);
              double nextNoteBeamY = startBeamY + (endBeamY - startBeamY) * nextRatio;

              _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
                forcedStemUp: beamStemUp, 
                noFlags: true, 
                stemTipY: currentNoteBeamY,
                drawLabel: false,
              );
              labelsToDraw.add((note: note, x: noteX, y: y, pos: pos, color: color, alpha: alpha, stemTipY: currentNoteBeamY));

              final beamOutlinePaint = Paint()
                ..color = clefColor.withValues(alpha: (isPast ? 0.3 : 0.7) * 0.4)
                ..strokeWidth = 4.8;
              
              final bStartX = noteX + (beamStemUp ? kNRx : -kNRx);
              final bEndX = nextX + (beamStemUp ? kNRx : -kNRx);
              canvas.drawLine(Offset(bStartX, currentNoteBeamY), Offset(bEndX, nextNoteBeamY), beamOutlinePaint);

              final beamPaint = Paint()
                ..color = color.withValues(alpha: isPast ? 0.3 : 0.7)
                ..strokeWidth = 3.5;
              
              canvas.drawLine(Offset(bStartX, currentNoteBeamY), Offset(bEndX, nextNoteBeamY), beamPaint);

              // 5. Double beam (Level 2)
              if (note.beam2 == 'begin' || note.beam2 == 'continue') {
                int nextBeam2Ni = ni + 1;
                MusicNote? nextBeam2Note;
                double nextBeam2NoteOffset = note.duration;
                while (nextBeam2Ni < displayNotes.length) {
                  final candidate = displayNotes[nextBeam2Ni];
                  if (!candidate.isRest) {
                    if (candidate.beam2 == 'continue' || candidate.beam2 == 'end') {
                      nextBeam2Note = candidate;
                    }
                    break;
                  }
                  nextBeam2NoteOffset += candidate.duration;
                  nextBeam2Ni++;
                }

                if (nextBeam2Note != null) {
                  final nextBeam2X = StaffLayoutHelper.getBeamEndX(
                    measure: m,
                    startX: startX,
                    measureWidth: measureWidth,
                    hasTimeSig: hasTimeSig,
                    cumulativeDuration: cumulativeDuration,
                    nextNoteOffset: nextBeam2NoteOffset,
                    nextNoteDuration: nextBeam2Note.duration,
                    displayNotes: displayNotes,
                  );
                  
                  double next2Ratio = (lastNoteX == firstNoteX) ? 1 : (nextBeam2X - firstNoteX) / (lastNoteX - firstNoteX);
                  double next2BeamY = startBeamY + (endBeamY - startBeamY) * next2Ratio;

                  const double bSpacing = kLS * 0.45;
                  final double b2Y1 = beamStemUp ? currentNoteBeamY + bSpacing : currentNoteBeamY - bSpacing;
                  final double b2Y2 = beamStemUp ? next2BeamY + bSpacing : next2BeamY - bSpacing;
                  final double b2EndX = nextBeam2X + (beamStemUp ? kNRx : -kNRx);

                  canvas.drawLine(Offset(bStartX, b2Y1), Offset(b2EndX, b2Y2), beamOutlinePaint);
                  canvas.drawLine(Offset(bStartX, b2Y1), Offset(b2EndX, b2Y2), beamPaint);
                }
              }
            }
          } else if (note.beam == 'end') {
            _drawNote(canvas, note, noteX, isActive, isPast, clefColor, 
              forcedStemUp: beamStemUp, 
              noFlags: true, 
              stemTipY: currentNoteBeamY,
              drawLabel: false,
            );
            labelsToDraw.add((note: note, x: noteX, y: y, pos: pos, color: color, alpha: alpha, stemTipY: currentNoteBeamY));
            isBeamed = true;
          }
        }

        if (!isBeamed) {
          _drawNote(canvas, note, noteX, isActive, isPast, clefColor, drawLabel: false);
          labelsToDraw.add((note: note, x: noteX, y: y, pos: pos, color: color, alpha: alpha, stemTipY: null));
        }

        // 5. Draw Tie if needed
        if (note.isTied) {
          MusicNote? nextNote;
          double nextNoteX = 0;
          double nextNoteY = 0;
          bool foundNext = false;

          // Look in current measure
          int nextNi = ni + 1;
          double nextNoteOffset = note.duration;
          while (nextNi < displayNotes.length) {
            final candidate = displayNotes[nextNi];
            if (!candidate.isRest) {
              nextNote = candidate;
              nextNoteX = StaffLayoutHelper.getNoteX(
                measure: m,
                startX: startX,
                measureWidth: measureWidth,
                hasTimeSig: hasTimeSig,
                cumulativeDuration: cumulativeDuration + nextNoteOffset,
                noteDuration: nextNote.duration,
                displayNotes: displayNotes,
              );
              nextNoteY = posToY(staffPos(nextNote.step, nextNote.octave));
              foundNext = true;
              break;
            }
            nextNoteOffset += candidate.duration;
            nextNi++;
          }

          // Look in subsequent measures in this row
          if (!foundNext) {
            double searchX = startX + measureWidth;
            for (int futureMi = mi + 1; futureMi < row.measures.length; futureMi++) {
              final futureM = row.measures[futureMi];
              final futureMW = measureWidths[futureMi];
              final futureDisplayNotes = futureM.notes.where((n) => !n.isChordContinuation).toList();
              
              double futureNoteOffset = 0;
              for (final fn in futureDisplayNotes) {
                if (!fn.isRest) {
                  nextNote = fn;
                  nextNoteX = StaffLayoutHelper.getNoteX(
                    measure: futureM,
                    startX: searchX,
                    measureWidth: futureMW,
                    hasTimeSig: false,
                    cumulativeDuration: futureNoteOffset,
                    noteDuration: fn.duration,
                    displayNotes: futureDisplayNotes,
                  );
                  nextNoteY = posToY(staffPos(fn.step, fn.octave));
                  foundNext = true;
                  break;
                }
                futureNoteOffset += fn.duration;
              }
              if (foundNext) break;
              searchX += futureMW;
            }
          }

          // Special case: Tie to ghost note in the editor
          if (!foundNext && ghostNoteIndex != null && ghostNoteIndex! > globalIdx && ghostNote != null && !ghostNote!.isRest) {
            double gX = 0;
            double gY = posToY(staffPos(ghostNote!.step, ghostNote!.octave));
            bool gFound = false;

            // Search all measures in this row to find where the ghost note belongs
            int currentNoteOffset = row.firstNoteIndex;
            double measureX = startX;
            Measure? searchPrevM = row.previousMeasure;
            
            for (int gMi = 0; gMi < row.measures.length; gMi++) {
              final gM = row.measures[gMi];
              final gMW = measureWidths[gMi];
              final int notesInMeasure = gM.notes.length;
              
              if (ghostNoteIndex! >= currentNoteOffset && ghostNoteIndex! <= currentNoteOffset + notesInMeasure) {
                final int localIdx = ghostNoteIndex! - currentNoteOffset;
                final bool hasTS = (searchPrevM == null || gM.beats != searchPrevM.beats || gM.beatType != searchPrevM.beatType);
                
                final gDisplayNotes = gM.notes.where((n) => !n.isChordContinuation).toList();
                double durBefore = 0;
                for (int i = 0; i < localIdx && i < gM.notes.length; i++) {
                  if (!gM.notes[i].isChordContinuation) {
                    durBefore += gM.notes[i].duration;
                  }
                }
                
                gX = StaffLayoutHelper.getNoteX(
                  measure: gM,
                  startX: measureX,
                  measureWidth: gMW,
                  hasTimeSig: hasTS,
                  cumulativeDuration: durBefore,
                  noteDuration: ghostNote!.duration,
                  displayNotes: gDisplayNotes,
                );
                gFound = true;
                break;
              }
              currentNoteOffset += notesInMeasure;
              measureX += gMW;
              searchPrevM = gM;
            }

            if (gFound) {
              nextNoteX = gX;
              nextNoteY = gY;
              foundNext = true;
            }
          }

          final bool goUp = pos >= 5;
          if (foundNext) {
            _drawTie(canvas, Offset(noteX, y), Offset(nextNoteX, nextNoteY), color, alpha, goUp: goUp);
          } else {
            // Tie goes to next row
            // We project it further past the edge to make it look "printed on both rows"
            _drawTie(canvas, Offset(noteX, y), Offset(totalWidth + 50, y), color, alpha, isEndPartial: true, goUp: goUp);
          }
        }

        // 6. Tie from previous row
        if (note.isTiedToPrevious) {
          bool foundPrev = false;
          // Look backwards in this row to see if the start of the tie is visible here
          for (int pastMi = mi; pastMi >= 0; pastMi--) {
            final pastM = row.measures[pastMi];
            final pastNotes = pastM.notes.where((n) => !n.isChordContinuation).toList();
            final startIdx = (pastMi == mi) ? ni - 1 : pastNotes.length - 1;
            for (int pastNi = startIdx; pastNi >= 0; pastNi--) {
              if (!pastNotes[pastNi].isRest) {
                foundPrev = true;
                break;
              }
            }
            if (foundPrev) break;
          }

          if (!foundPrev && !row.isFirstRow) {
            final bool goUp = pos >= 5;
            // Coming from previous row, enter from the left margin
            _drawTie(canvas, Offset(-50, y), Offset(noteX, y), color, alpha, isStartPartial: true, goUp: goUp);
          }
        }
      }
      cumulativeDuration += note.duration;
    }

    for (final l in labelsToDraw) {
      _drawNoteLabel(canvas, l.note, l.x, l.y, l.pos, l.color, l.alpha, clefColor, stemTipY: l.stemTipY);
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
    bool drawLabel = true,
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
    _drawNoteHead(canvas, note.type, x, y, color, alpha, isActive, clefColor: clefColor);
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
    if (note.isDotted) _drawDot(canvas, x, y, alpha, color, clefColor);
    if (drawLabel) {
      _drawNoteLabel(canvas, note, x, y, pos, color, alpha, clefColor, stemTipY: stemTipY);
    }
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

  void _drawNoteHead(Canvas canvas, String type, double x, double y, Color color, double alpha, bool isActive, {required Color clefColor}) {
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
      
      // Add a subtle outline to help visibility of light colors like yellow on white backgrounds
      canvas.drawOval(
        rect,
        Paint()
          ..color = clefColor.withValues(alpha: alpha * 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );

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
      
      // Also add a subtle darker outline for unfilled notes
      canvas.drawOval(
        rect,
        Paint()
          ..color = clefColor.withValues(alpha: alpha * 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.5,
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
    
    // Draw outline for the stem
    final pOutline = Paint()
      ..color = clefColor.withValues(alpha: alpha * 0.35)
      ..strokeWidth = 2.4;
      
    final p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.4;
    final sy = stemTipY ?? (stemUp ? y - kStem : y + kStem);

    if (stemUp) {
      final sx = x + kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), pOutline);
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), p);
      if (type != 'half' && !noFlags) {
        _drawFlags(canvas, Offset(sx, sy), true, type, alpha, color, clefColor);
      }
    } else {
      final sx = x - kNRx;
      canvas.drawLine(Offset(sx, y), Offset(sx, sy), pOutline);
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

    // Draw outline for flags
    final pOutline = Paint()
      ..color = clefColor.withValues(alpha: alpha * 0.35)
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    final p = Paint()
      ..color = color.withValues(alpha: alpha)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < count; i++) {
      final shift = stemUp ? i * kLS * 0.75 : -i * kLS * 0.75;
      final s = Offset(tip.dx, tip.dy + shift);
      final cp = Offset(s.dx + kLS * 1.0, s.dy + (stemUp ? kLS * 0.6 : -kLS * 0.6));
      final e = Offset(s.dx + kLS * 0.55, s.dy + (stemUp ? kLS * 1.5 : -kLS * 1.5));
      path.moveTo(s.dx, s.dy);
      path.quadraticBezierTo(cp.dx, cp.dy, e.dx, e.dy);
    }
    canvas.drawPath(path, pOutline);
    canvas.drawPath(path, p);
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

  void _drawDot(Canvas canvas, double x, double y, double alpha, Color color, Color clefColor) {
    final center = Offset(x + kNRx + 4, y - kLS * 0.25);
    // Draw outline for the dot
    canvas.drawCircle(center, 2.6, Paint()..color = clefColor.withValues(alpha: alpha * 0.3));
    canvas.drawCircle(center, 2.0, Paint()..color = color.withValues(alpha: alpha));
  }

  void _drawRest(Canvas canvas, double x, String type, Color clefColor, {bool isActive = false, bool isPast = false, MusicNote? note}) {
    final alpha = isPast ? 0.3 : 0.7;
    final color = isActive ? Colors.orange : clefColor.withValues(alpha: alpha);
    
    final hasDot = note != null && note.dot > 0;

    switch (type) {
      case 'breve':
        final ly = posToY(5) - kLS * 0.5;
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.4, ly, kLS * 0.8, kLS * 1.0), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.5, ly + kLS * 0.5, alpha, color, clefColor);
        return;
      case 'whole':
        final ly = posToY(6);
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.75, ly, kLS * 1.5, kLS * 0.55), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.75, ly + kLS * 0.25, alpha, color, clefColor);
        return;
      case 'half':
        final ly = posToY(4) - kLS * 0.55;
        canvas.drawRect(Rect.fromLTWH(x - kLS * 0.75, ly, kLS * 1.5, kLS * 0.55), Paint()..color = color);
        if (hasDot) _drawDot(canvas, x + kLS * 0.75, ly + kLS * 0.25, alpha, color, clefColor);
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
      _drawDot(canvas, x + kLS * 0.4, y + kLS * 0.8, alpha, color, clefColor);
    }
  }

  void _drawNoteLabel(Canvas canvas, MusicNote note, double x, double y, int pos, Color color, double alpha, Color clefColor, {double? stemTipY}) {
    if (!showNoteLabels) return;
    if (!showLetter && !showSolfege) return;
    final raw = note.letterName.replaceAll(RegExp(r'\d'), '');
    final label = showSolfege ? note.solfegeName : raw;
    final filled = note.type != 'whole' && note.type != 'half' && note.type != 'breve';

    if (labelsBelow) {
      final stemUp = pos < 5;
      final double effectiveStemTipY = stemTipY ?? (stemUp ? y - kStem : y + kStem);
      final labelY = stemUp ? y + kLS * 2.5 : effectiveStemTipY + kLS * 1.2;
      
      // Ensure the label color has enough contrast with the background
      final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
      Color labelColor = coloredLabels ? color.withValues(alpha: alpha) : clefColor.withValues(alpha: alpha);
      
      if (coloredLabels) {
        final luminance = color.computeLuminance();
        if (!isDarkTheme && luminance > 0.7) {
          // Too light for white background, use a darkened version
          labelColor = Color.alphaBlend(Colors.black54, color).withValues(alpha: alpha);
        } else if (isDarkTheme && luminance < 0.15) {
          // Too dark for black background, use a lightened version
          labelColor = Color.alphaBlend(Colors.white54, color).withValues(alpha: alpha);
        }
      }

      _drawTextWithOutline(
        canvas, label, Offset(x, labelY), fontSize: kLS * 0.85,
        color: labelColor,
        outlineColor: Theme.of(context).canvasColor.withValues(alpha: alpha * 0.8),
        outlineWidth: 1.8, fontWeight: FontWeight.bold,
      );
    } else {
      final textColor = filled ? NoteColors.textColorFor(color).withValues(alpha: alpha) : color.withValues(alpha: alpha);
      
      // For hollow notes (half/whole), if the note color is too light/dark for the theme, 
      // adjust the text color for better readability against the hollow center.
      Color finalTextColor = textColor;
      if (!filled) {
        final isDarkTheme = Theme.of(context).brightness == Brightness.dark;
        final luminance = color.computeLuminance();
        if (!isDarkTheme && luminance > 0.7) finalTextColor = Colors.black87.withValues(alpha: alpha);
        if (isDarkTheme && luminance < 0.2) finalTextColor = Colors.white70.withValues(alpha: alpha);
      }
      
      final fontSize = label.length > 2 ? kNRy * 0.95 : kNRy * 1.15;
      _drawTextCentered(canvas, label, Offset(x, y), fontSize: fontSize, color: finalTextColor, fontWeight: FontWeight.bold);
    }
  }

  void _drawTie(Canvas canvas, Offset start, Offset end, Color color, double alpha, {bool isStartPartial = false, bool isEndPartial = false, bool goUp = false}) {
    final p = Paint()
      ..color = color.withValues(alpha: alpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    // Offset slightly from the center of the note head
    final yOffset = goUp ? -5.0 : 5.0;
    final startPt = Offset(start.dx + (isStartPartial ? 0 : 5), start.dy + yOffset);
    final endPt = Offset(end.dx - (isEndPartial ? 0 : 5), end.dy + yOffset);

    path.moveTo(startPt.dx, startPt.dy);

    final midX = (startPt.dx + endPt.dx) / 2;
    final dist = (endPt.dx - startPt.dx).abs();
    
    // Partial ties should look like they are continuing from/to another row
    // so we make them flatter and project them further.
    double curveDepth;
    if (isStartPartial || isEndPartial) {
      curveDepth = (dist * 0.15).clamp(4.0, 10.0);
    } else {
      curveDepth = (dist * 0.22).clamp(7.0, 18.0);
    }

    final actualCurveDepth = goUp ? -curveDepth : curveDepth;

    path.quadraticBezierTo(midX, startPt.dy + actualCurveDepth, endPt.dx, endPt.dy);
    canvas.drawPath(path, p);
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
    // Avoid hardcoding 'serif' which can trigger font-not-found warnings.
    // Use Noto Sans to match the rest of the app's theme.
    final tp = TextPainter(
      text: TextSpan(
        text: text, 
        style: GoogleFonts.notoSans(
          fontSize: fontSize, 
          color: color, 
          fontWeight: fontWeight,
        ),
      ), 
      textDirection: TextDirection.ltr,
    )..layout();
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
