import 'package:flutter/material.dart' show Brightness;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/song.dart';
import '../models/music_note.dart';
import '../models/measure.dart';
import '../models/instrument_profile.dart';
import '../sheet_music_constants.dart';
import 'staff_layout_helper.dart';
import 'music_constants.dart';
import '../../config/app_config.dart';

class MusicPdfService {
  static Future<void> printSong({
    required Song song,
    required InstrumentProfile colorScheme,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
    required int measuresPerRow,
  }) async {
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

        // We use the same ratios as kLS but potentially a different base scale for PDF
        const double ls = 10.0; // Standardize PDF line spacing
        const double staffHeight = ls * 4;
        const double topMargin = ls * 4;
        const double bottomMargin = ls * 4;
        const double rowHeight = topMargin + staffHeight + bottomMargin;
        const double clefWidth = kClefW * (ls / kLS);
        const double headerHeight = 80;

        final pageWidth = format.availableWidth;
        final pageHeight = format.availableHeight;

        // Split measures into rows
        final List<List<Measure>> rows = [];
        for (int i = 0; i < song.measures.length; i += measuresPerRow) {
          rows.add(
            song.measures.sublist(
              i,
              (i + measuresPerRow).clamp(0, song.measures.length),
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
                              child: _buildStaffRow(
                                measures: rowMeasures,
                                colorScheme: colorScheme,
                                width: pageWidth,
                                ls: ls,
                                topMargin: topMargin,
                                staffHeight: staffHeight,
                                clefWidth: clefWidth,
                                isFirstRow: isFirstRow,
                                isLastRow: isLastRow,
                                measuresPerRow: measuresPerRow,
                                musicFont: musicFont,
                                previousMeasure: rowIndex > 0 ? rows[rowIndex - 1].last : null,
                                showSolfege: showSolfege,
                                showLetter: showLetter,
                                labelsBelow: labelsBelow,
                                coloredLabels: coloredLabels,
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
                          AppConfig.title,
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Row(
                          children: [
                            pw.Text(
                              'Instrument: ${colorScheme.name} ',
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                            if (colorScheme.emoji != null)
                              pw.Text(
                                colorScheme.emoji!,
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

  static pw.Widget _buildStaffRow({
    required List<Measure> measures,
    required InstrumentProfile colorScheme,
    required double width,
    required double ls,
    required double topMargin,
    required double staffHeight,
    required double clefWidth,
    required bool isFirstRow,
    required bool isLastRow,
    required int measuresPerRow,
    required pw.Font musicFont,
    required Measure? previousMeasure,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
  }) {
    final double startX = clefWidth;
    final double availWidth = width - startX;
    final double measureWidth = availWidth / measuresPerRow;
    final double actualWidth = startX + (measures.length * measureWidth);

    return pw.SizedBox(
      height: topMargin + staffHeight + topMargin,
      width: width,
      child: pw.Stack(
        children: [
          // Staff lines
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

          // Treble clef
          pw.Positioned(
            left: 2,
            top: topMargin - ls * 1.35,
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
            measures: measures,
            colorScheme: colorScheme,
            width: width,
            ls: ls,
            topMargin: topMargin,
            staffHeight: staffHeight,
            clefWidth: clefWidth,
            isFirstRow: isFirstRow,
            isLastRow: isLastRow,
            measuresPerRow: measuresPerRow,
            musicFont: musicFont,
            previousMeasure: previousMeasure,
            showSolfege: showSolfege,
            showLetter: showLetter,
            labelsBelow: labelsBelow,
            coloredLabels: coloredLabels,
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildMeasuresContent({
    required List<Measure> measures,
    required InstrumentProfile colorScheme,
    required double width,
    required double ls,
    required double topMargin,
    required double staffHeight,
    required double clefWidth,
    required bool isFirstRow,
    required bool isLastRow,
    required int measuresPerRow,
    required pw.Font musicFont,
    required Measure? previousMeasure,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
  }) {
    final widgets = <pw.Widget>[];
    double x = clefWidth;

    final availWidth = width - x;
    final measureWidth = availWidth / measuresPerRow;

    Measure? currentPrevMeasure = previousMeasure;

    for (int mi = 0; mi < measures.length; mi++) {
      final measure = measures[mi];

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

      final displayNotes =
          measure.notes.where((n) => !n.isChordContinuation).toList();
      
      final bool hasTimeSig = currentPrevMeasure == null ||
          (measure.beats != currentPrevMeasure.beats ||
              measure.beatType != currentPrevMeasure.beatType);

      final noteHeadWidth = ls * 1.56; // Matching kNRx * 2 / kLS ratio

      double cumulativeDuration = 0.0;
      for (int ni = 0; ni < displayNotes.length; ni++) {
        final note = displayNotes[ni];
        final noteX = StaffLayoutHelper.getNoteX(
          measure: measure,
          startX: x,
          measureWidth: measureWidth,
          hasTimeSig: hasTimeSig,
          cumulativeDuration: cumulativeDuration,
          displayNotes: displayNotes,
        );

        if (!note.isRest) {
          bool isBeamed = false;
          if (note.beam != null) {
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
                  measure: measure,
                  startX: x,
                  measureWidth: measureWidth,
                  hasTimeSig: hasTimeSig,
                  cumulativeDuration: cumulativeDuration,
                  nextNoteOffset: nextNoteOffset,
                  displayNotes: displayNotes,
                );

                final pos = staffPos(note.step, note.octave);
                final nextPos = staffPos(nextNote.step, nextNote.octave);

                final stemUp = pos < 5;
                final y = topMargin + staffHeight - pos * ls / 2;
                final nextY = topMargin + staffHeight - nextPos * ls / 2;

                final stemLength = ls * 3.4;
                final stemTipY = y + (stemUp ? -stemLength : stemLength);
                final nextStemTipY = nextY + (stemUp ? -stemLength : stemLength);

                widgets.addAll(_buildNote(
                  note: note,
                  x: noteX,
                  topMargin: topMargin,
                  staffHeight: staffHeight,
                  ls: ls,
                  colorScheme: colorScheme,
                  musicFont: musicFont,
                  forcedStemUp: stemUp,
                  noFlags: true,
                  showSolfege: showSolfege,
                  showLetter: showLetter,
                  labelsBelow: labelsBelow,
                  coloredLabels: coloredLabels,
                ));

                final color = colorScheme.colorForNote(
                  note.step,
                  note.alter,
                  octave: note.octave,
                  brightness: Brightness.light,
                );
                final pdfColor = PdfColor(color.r, color.g, color.b);

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

              final stemUp = startNote != null
                ? staffPos(startNote.step, startNote.octave) < 5
                : staffPos(note.step, note.octave) < 5;

              widgets.addAll(_buildNote(
                note: note,
                x: noteX,
                topMargin: topMargin,
                staffHeight: staffHeight,
                ls: ls,
                colorScheme: colorScheme,
                musicFont: musicFont,
                forcedStemUp: stemUp,
                noFlags: true,
                showSolfege: showSolfege,
                showLetter: showLetter,
                labelsBelow: labelsBelow,
                coloredLabels: coloredLabels,
              ));
              isBeamed = true;
            }
          }

          if (!isBeamed) {
            widgets.addAll(_buildNote(
              note: note,
              x: noteX,
              topMargin: topMargin,
              staffHeight: staffHeight,
              ls: ls,
              colorScheme: colorScheme,
              musicFont: musicFont,
              showSolfege: showSolfege,
              showLetter: showLetter,
              labelsBelow: labelsBelow,
              coloredLabels: coloredLabels,
            ));
          }
        }
        cumulativeDuration += note.duration;
      }

      x += measureWidth;

      final isLastMeasure = mi == measures.length - 1;
      if (isLastMeasure && isLastRow) {
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

  static List<pw.Widget> _buildNote({
    required MusicNote note,
    required double x,
    required double topMargin,
    required double staffHeight,
    required double ls,
    required InstrumentProfile colorScheme,
    required pw.Font musicFont,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
    bool? forcedStemUp,
    bool noFlags = false,
  }) {
    final widgets = <pw.Widget>[];

    final pos = staffPos(note.step, note.octave);
    final y = topMargin + staffHeight - pos * ls / 2;

    final color = colorScheme.colorForNote(
      note.step,
      note.alter,
      octave: note.octave,
      brightness: Brightness.light,
    );
    final pdfColor = PdfColor(color.r, color.g, color.b);

    final noteHeadWidth = ls * 1.56;
    final noteHeadHeight = ls * 0.88;

    // Ledger lines
    if (pos < 0) {
      final lowest = pos.isEven ? pos : pos + 1;
      for (int lp = -2; lp >= lowest; lp -= 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - noteHeadWidth * 0.7,
            top: ly - 0.3,
            child: pw.Container(
              width: noteHeadWidth * 1.4,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    if (pos > 8) {
      final highest = pos.isEven ? pos : pos - 1;
      for (int lp = 10; lp <= highest; lp += 2) {
        final ly = topMargin + staffHeight - lp * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - noteHeadWidth * 0.7,
            top: ly - 0.3,
            child: pw.Container(
              width: noteHeadWidth * 1.4,
              height: 0.6,
              color: PdfColors.grey700,
            ),
          ),
        );
      }
    }

    if (note.alter != 0) {
      widgets.add(
        pw.Positioned(
          left: x - noteHeadWidth * 1.2,
          top: y - ls * 0.8,
          child: pw.Text(
            note.alter > 0 ? '\u{266F}' : '\u{266D}',
            style: pw.TextStyle(
              fontSize: ls * 1.6,
              color: PdfColors.black,
            ),
          ),
        ),
      );
    }

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

      if (!noFlags) {
        final flagCount = switch (note.type) {
          'eighth' => 1,
          '16th' => 2,
          '32nd' => 3,
          _ => 0,
        };

        if (flagCount > 0) {
          final tipY = stemUp ? y - stemLength : y + stemLength;
          final flagX = stemUp ? x + noteHeadWidth / 2 - 0.6 : x - noteHeadWidth / 2 - 0.6;

          for (int i = 0; i < flagCount; i++) {
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
                    final startX = flagX;
                    final startY = -currentFlagY;
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

    if (showLetter || showSolfege) {
      String label = '';
      if (showLetter && showSolfege) {
        label = '${note.step}\n${note.solfegeName}';
      } else if (showLetter) {
        label = note.step;
        if (note.alter == 1) label += '#';
        if (note.alter == -1) label += 'b';
      } else if (showSolfege) {
        label = note.solfegeName;
      }

      if (labelsBelow) {
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
}
