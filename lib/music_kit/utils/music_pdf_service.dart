import 'dart:math' as math;
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
    required bool landscape,
  }) async {
    await printSongs(
      songs: [song],
      colorScheme: colorScheme,
      showSolfege: showSolfege,
      showLetter: showLetter,
      labelsBelow: labelsBelow,
      coloredLabels: coloredLabels,
      measuresPerRow: measuresPerRow,
      landscape: landscape,
    );
  }

  static Future<void> printSongs({
    required List<Song> songs,
    required InstrumentProfile colorScheme,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
    required int measuresPerRow,
    required bool landscape,
  }) async {
    // Load fonts that support Unicode and symbols
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();
    final musicFont = await PdfGoogleFonts.notoMusicRegular();
    final emojiFont = await PdfGoogleFonts.notoColorEmojiRegular();

    await Printing.layoutPdf(
      name: songs.length == 1
          ? songs.first.title.replaceAll(RegExp(r'[^\w\s-]'), '')
          : 'Batch_Print_${DateTime.now().millisecondsSinceEpoch}',
      onLayout: (PdfPageFormat format) async {
        final actualFormat = landscape ? format.landscape : format;

        final doc = pw.Document(
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
            fontFallback: [emojiFont, musicFont],
          ),
        );

        bool hasPages = false;
        for (final song in songs) {
          if (song.measures.isEmpty) continue;

          hasPages = true;
          // We use the same ratios as kLS but potentially a different base scale for PDF
          const double ls = 10.0; // Standardize PDF line spacing
          const double staffHeight = ls * 4;
          const double topMargin = ls * 2.5; // Reduced from 4
          const double bottomMargin = ls * 2.5; // Reduced from 4
          const double rowHeight = topMargin + staffHeight + bottomMargin;
          const double clefWidth = kClefW * (ls / kLS);
          const double headerHeight = 50; // Reduced from 80

          final pageWidth = actualFormat.availableWidth;
          final pageHeight = actualFormat.availableHeight;

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
                pageFormat: actualFormat,
                build: (pw.Context ctx) {
                  return pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (pageStart == 0) ...[
                              pw.Row(
                                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: pw.CrossAxisAlignment.end,
                                children: [
                                  pw.Text(
                                    song.title,
                                    style: pw.TextStyle(
                                      fontSize: 18,
                                      fontWeight: pw.FontWeight.bold,
                                    ),
                                  ),
                                  if (song.composer.isNotEmpty)
                                    pw.Text(
                                      song.composer,
                                      style: const pw.TextStyle(fontSize: 10),
                                    ),
                                ],
                              ),
                              pw.SizedBox(height: 4),
                              pw.Divider(thickness: 0.5),
                              pw.SizedBox(height: 4),
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
        }

        if (!hasPages) {
          doc.addPage(
            pw.Page(
              pageFormat: actualFormat,
              build: (_) => pw.Center(
                child: pw.Text('No notes found in selected songs.'),
              ),
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
    final double standardMeasureWidth = availWidth / measuresPerRow;
    
    // Pre-calculate measure widths to handle pickups and crowding
    final List<double> measureWidths = [];
    double totalRowW = startX;
    Measure? currentPrevMeasureForW = previousMeasure;
    for (final m in measures) {
      double w = standardMeasureWidth;
      final bool hasTimeSig = (currentPrevMeasureForW == null || 
          m.beats != currentPrevMeasureForW.beats || 
          m.beatType != currentPrevMeasureForW.beatType);

      if (m.isPickup) {
        final durBeats = m.notes.fold(0.0, (s, n) => s + n.duration) * (m.beatType / 4.0);
        final ratio = (durBeats / m.beats).clamp(0.4, 0.6); 
        w = standardMeasureWidth * ratio;
      }
      
      if (hasTimeSig) {
        final pdfNRx = kNRx * (ls / kLS);
        final minW = StaffLayoutHelper.kTimeSigReservedW + 
                     (StaffLayoutHelper.kMeasurePadding * 2) + 
                     (pdfNRx * 5);
        if (w < minW) w = minW;
      }
      measureWidths.add(w);
      totalRowW += w;
      currentPrevMeasureForW = m;
    }

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
                width: totalRowW,
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
            measureWidths: measureWidths,
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
    required List<double> measureWidths,
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
    final labelWidgets = <pw.Widget>[];
    double x = clefWidth;

    Measure? currentPrevMeasure = previousMeasure;

    for (int mi = 0; mi < measures.length; mi++) {
      final measure = measures[mi];
      final measureWidth = measureWidths[mi];

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
      final bool hasTimeSig = measure.beats != currentPrevMeasure.beats ||
          measure.beatType != currentPrevMeasure.beatType;

      double cumulativeDuration = 0.0;
      for (int ni = 0; ni < displayNotes.length; ni++) {
        final note = displayNotes[ni];
        final noteX = StaffLayoutHelper.getNoteX(
          measure: measure,
          startX: x,
          measureWidth: measureWidth,
          hasTimeSig: hasTimeSig,
          cumulativeDuration: cumulativeDuration,
          noteDuration: note.duration,
          displayNotes: displayNotes,
        );

        if (!note.isRest) {
          final pos = staffPos(note.step, note.octave);
          final y = topMargin + staffHeight - pos * ls / 2;
          final color = colorScheme.colorForNote(
            note.step,
            note.alter,
            octave: note.octave,
            brightness: Brightness.light,
          );
          final pdfColor = PdfColor(color.r, color.g, color.b);

          bool isBeamed = false;
          if (note.beam != null) {
            // 1. Find all notes in this beam group to determine a consistent direction and beam line
            int startOfBeam = ni;
            while (startOfBeam > 0 && displayNotes[startOfBeam].beam != 'begin') {
              startOfBeam--;
            }
            
            int endOfBeam = ni;
            while (endOfBeam < displayNotes.length - 1 && displayNotes[endOfBeam].beam != 'end') {
              endOfBeam++;
            }

            final beamNotes = displayNotes.sublist(startOfBeam, endOfBeam + 1);
            
            // 2. Determine stem direction: majority rule with tie-break towards furthest from center
            int upCount = 0;
            int downCount = 0;
            double maxDist = 0;
            bool distPrefersUp = true;
            
            for (final bn in beamNotes) {
              final p = staffPos(bn.step, bn.octave);
              if (p < 4) {upCount++; }else {downCount++;}
              final dist = (p - 4).abs().toDouble();
              if (dist > maxDist) {
                maxDist = dist;
                distPrefersUp = p < 4;
              }
            }
            final bool beamStemUp = (upCount == downCount) ? distPrefersUp : (upCount > downCount);

            // 3. Determine beam Y positions
            final stemLength = ls * 3.4;
            double beamY;
            if (beamStemUp) {
              int minPos = 100;
              for (final bn in beamNotes) {
                final p = staffPos(bn.step, bn.octave);
                if (p < minPos) minPos = p;
              }
              final basePos = math.max(minPos, 4);
              beamY = topMargin + staffHeight - basePos * ls / 2 - stemLength;
            } else {
              int maxPos = -100;
              for (final bn in beamNotes) {
                final p = staffPos(bn.step, bn.octave);
                if (p > maxPos) maxPos = p;
              }
              final basePos = math.min(maxPos, 4);
              beamY = topMargin + staffHeight - basePos * ls / 2 + stemLength;
            }

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
                  nextNoteDuration: nextNote.duration,
                  displayNotes: displayNotes,
                );

                widgets.addAll(_buildNote(
                  note: note,
                  x: noteX,
                  topMargin: topMargin,
                  staffHeight: staffHeight,
                  ls: ls,
                  colorScheme: colorScheme,
                  musicFont: musicFont,
                  forcedStemUp: beamStemUp,
                  noFlags: true,
                  stemTipY: beamY,
                  drawLabel: false,
                ));

                if (showLetter || showSolfege) {
                  labelWidgets.add(_buildNoteLabel(
                    note: note,
                    x: noteX,
                    y: y,
                    pos: pos,
                    ls: ls,
                    pdfColor: pdfColor,
                    colorLuminance: color.computeLuminance(),
                    showSolfege: showSolfege,
                    showLetter: showLetter,
                    labelsBelow: labelsBelow,
                    coloredLabels: coloredLabels,
                    stemTipY: beamY,
                  ));
                }

                final beamStartX = noteX + (beamStemUp ? (ls * 0.78) : -(ls * 0.78));
                final beamEndX = nextX + (beamStemUp ? (ls * 0.78) : -(ls * 0.78));

                widgets.add(
                  pw.Positioned(
                    left: 0,
                    top: 0,
                    child: pw.CustomPaint(
                      size: const PdfPoint(0, 0),
                      painter: (PdfGraphics canvas, PdfPoint size) {
                        // Draw a subtle outline for the beam to improve visibility of light colors
                        canvas.setStrokeColor(PdfColors.grey400);
                        canvas.setLineWidth(4.8);
                        canvas.drawLine(beamStartX, -beamY, beamEndX, -beamY);
                        canvas.strokePath();

                        canvas.setStrokeColor(pdfColor);
                        canvas.setLineWidth(3.5);
                        canvas.drawLine(beamStartX, -beamY, beamEndX, -beamY);
                        canvas.strokePath();
                      },
                    ),
                  ),
                );
              }
            } else if (note.beam == 'end') {
              widgets.addAll(_buildNote(
                note: note,
                x: noteX,
                topMargin: topMargin,
                staffHeight: staffHeight,
                ls: ls,
                colorScheme: colorScheme,
                musicFont: musicFont,
                forcedStemUp: beamStemUp,
                noFlags: true,
                stemTipY: beamY,
                drawLabel: false,
              ));
              if (showLetter || showSolfege) {
                labelWidgets.add(_buildNoteLabel(
                  note: note,
                  x: noteX,
                  y: y,
                  pos: pos,
                  ls: ls,
                  pdfColor: pdfColor,
                  colorLuminance: color.computeLuminance(),
                  showSolfege: showSolfege,
                  showLetter: showLetter,
                  labelsBelow: labelsBelow,
                  coloredLabels: coloredLabels,
                  stemTipY: beamY,
                ));
              }
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
              drawLabel: false,
            ));
            if (showLetter || showSolfege) {
              labelWidgets.add(_buildNoteLabel(
                note: note,
                x: noteX,
                y: y,
                pos: pos,
                ls: ls,
                pdfColor: pdfColor,
                colorLuminance: color.computeLuminance(),
                showSolfege: showSolfege,
                showLetter: showLetter,
                labelsBelow: labelsBelow,
                coloredLabels: coloredLabels,
                stemTipY: null,
              ));
            }
          }
        } else {
          widgets.addAll(_buildRest(
            note: note,
            x: noteX,
            topMargin: topMargin,
            staffHeight: staffHeight,
            ls: ls,
            musicFont: musicFont,
          ));
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

    return [...widgets, ...labelWidgets];
  }

  static List<pw.Widget> _buildNote({
    required MusicNote note,
    required double x,
    required double topMargin,
    required double staffHeight,
    required double ls,
    required InstrumentProfile colorScheme,
    required pw.Font musicFont,
    bool? forcedStemUp,
    bool noFlags = false,
    double? stemTipY,
    bool drawLabel = true,
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

    final noteHeadWidth = ls * 1.2; // Reduced from 1.56 to prevent overlap
    final noteHeadHeight = ls * 0.9; // Adjusted for better proportions

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
          child: pw.CustomPaint(
            size: PdfPoint(noteHeadWidth, noteHeadHeight),
            painter: (PdfGraphics canvas, PdfPoint size) {
              if (filled) {
                canvas.setFillColor(pdfColor);
                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
                canvas.fillPath();
                
                // Add a subtle outline to help visibility of light colors like yellow on white backgrounds
                canvas.setStrokeColor(PdfColors.grey400);
                canvas.setLineWidth(0.8);
                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
                canvas.strokePath();
              } else {
                canvas.setStrokeColor(pdfColor);
                canvas.setLineWidth(1.5);
                // Draw clean ellipse for open notes
                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2 - 0.75, size.y / 2 - 0.75);
                canvas.strokePath();

                // Also add a subtle darker outline for unfilled notes
                canvas.setStrokeColor(PdfColors.grey200);
                canvas.setLineWidth(0.5);
                canvas.drawEllipse(size.x / 2, size.y / 2, size.x / 2, size.y / 2);
                canvas.strokePath();
              }
            },
          ),
        ),
      ),
    );

    if (note.type != 'whole') {
      final stemUp = forcedStemUp ?? (pos < 5);
      final defaultStemLength = ls * 3.4;
      
      double calculatedStemLength;
      double top;
      
      if (stemTipY != null) {
        calculatedStemLength = (y - stemTipY).abs();
        top = stemUp ? stemTipY : y;
      } else {
        calculatedStemLength = defaultStemLength;
        top = stemUp ? y - defaultStemLength : y;
      }

      final stemX = stemUp ? x + noteHeadWidth / 2 - 0.6 : x - noteHeadWidth / 2 - 0.6;

      // Draw stem with outline
      widgets.add(
        pw.Positioned(
          left: 0,
          top: 0,
          child: pw.CustomPaint(
            size: const PdfPoint(0, 0),
            painter: (PdfGraphics canvas, PdfPoint size) {
              // Stem outline
              canvas.setStrokeColor(PdfColors.grey400);
              canvas.setLineWidth(2.4);
              canvas.drawLine(stemX, -top, stemX, -(top + calculatedStemLength));
              canvas.strokePath();

              // Stem fill
              canvas.setStrokeColor(pdfColor);
              canvas.setLineWidth(1.2);
              canvas.drawLine(stemX, -top, stemX, -(top + calculatedStemLength));
              canvas.strokePath();
            },
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
          final tipY = stemTipY ?? (stemUp ? y - defaultStemLength : y + defaultStemLength);
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
                    final startX = flagX;
                    final startY = -currentFlagY;
                    final ey = stemUp ? -ls * 1.3 : ls * 1.3;
                    final cpY = stemUp ? -ls * 0.5 : ls * 0.5;

                    // Flag outline
                    canvas.setStrokeColor(PdfColors.grey400);
                    canvas.setLineWidth(2.8);
                    canvas.moveTo(startX, startY);
                    canvas.curveTo(
                      startX + ls * 0.8, startY + cpY,
                      startX + ls * 0.5, startY + ey,
                      startX + ls * 0.5, startY + ey
                    );
                    canvas.strokePath();

                    // Flag fill
                    canvas.setStrokeColor(pdfColor);
                    canvas.setLineWidth(1.0);
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

    if (note.dot > 0) {
      widgets.add(_buildDot(x + noteHeadWidth / 2 + 2, y - ls * 0.2, pdfColor));
    }

    return widgets;
  }

  static pw.Widget _buildNoteLabel({
    required MusicNote note,
    required double x,
    required double y,
    required int pos,
    required double ls,
    required PdfColor pdfColor,
    required double colorLuminance,
    required bool showSolfege,
    required bool showLetter,
    required bool labelsBelow,
    required bool coloredLabels,
    required double? stemTipY,
  }) {
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
      final actualStemLength = stemTipY != null ? (y - stemTipY).abs() : ls * 3.4;
      final labelY = stemUp ? y + ls * 2.5 : y + actualStemLength + ls * 1.2;

      return pw.Positioned(
        left: x - 6,
        top: labelY - 3,
        child: pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: coloredLabels ? pdfColor : PdfColors.black,
          ),
        ),
      );
    } else {
      final textColor = colorLuminance > 0.35 ? PdfColors.black : PdfColors.white;

      return pw.Positioned(
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
      );
    }
  }

  static List<pw.Widget> _buildRest({
    required MusicNote note,
    required double x,
    required double topMargin,
    required double staffHeight,
    required double ls,
    required pw.Font musicFont,
  }) {
    final widgets = <pw.Widget>[];
    final type = note.type;
    final bool hasDot = note.dot > 0;

    switch (type) {
      case 'breve':
        final ly = topMargin + staffHeight - 5 * ls / 2 - ls * 0.5;
        widgets.add(
          pw.Positioned(
            left: x - ls * 0.4,
            top: ly,
            child: pw.Container(
              width: ls * 0.8,
              height: ls * 1.0,
              color: PdfColors.black,
            ),
          ),
        );
        if (hasDot) {
          widgets.add(_buildDot(x + ls * 0.5, ly + ls * 0.5, PdfColors.black));
        }
        break;
      case 'whole':
        final ly = topMargin + staffHeight - 6 * ls / 2;
        widgets.add(
          pw.Positioned(
            left: x - ls * 0.75,
            top: ly,
            child: pw.Container(
              width: ls * 1.5,
              height: ls * 0.55,
              color: PdfColors.black,
            ),
          ),
        );
        if (hasDot) {
          widgets.add(_buildDot(x + ls * 0.75, ly + ls * 0.25, PdfColors.black));
        }
        break;
      case 'half':
        final ly = topMargin + staffHeight - 4 * ls / 2 - ls * 0.55;
        widgets.add(
          pw.Positioned(
            left: x - ls * 0.75,
            top: ly,
            child: pw.Container(
              width: ls * 1.5,
              height: ls * 0.55,
              color: PdfColors.black,
            ),
          ),
        );
        if (hasDot) {
          widgets.add(_buildDot(x + ls * 0.75, ly + ls * 0.25, PdfColors.black));
        }
        break;
      default:
        final sym = switch (type) {
          'quarter' => '\u{1D13D}',
          'eighth' => '\u{1D13E}',
          '16th' => '\u{1D13F}',
          '32nd' => '\u{1D140}',
          '64th' => '\u{1D141}',
          _ => '\u{1D13D}'
        };
        final ry = topMargin + staffHeight - 5 * ls / 2 - ls * 1.0;
        widgets.add(
          pw.Positioned(
            left: x - ls * 0.7,
            top: ry,
            child: pw.Text(
              sym,
              style: pw.TextStyle(
                font: musicFont,
                fontSize: ls * 2.1,
                color: PdfColors.black,
              ),
            ),
          ),
        );
        if (hasDot) {
          widgets.add(_buildDot(x + ls * 0.4, ry + ls * 0.8, PdfColors.black));
        }
        break;
    }

    return widgets;
  }

  static pw.Widget _buildDot(double x, double y, PdfColor color) {
    return pw.Positioned(
      left: x,
      top: y,
      child: pw.CustomPaint(
        size: const PdfPoint(4, 4),
        painter: (PdfGraphics canvas, PdfPoint size) {
          // Dot outline
          canvas.setStrokeColor(PdfColors.grey400);
          canvas.drawEllipse(2, 2, 1.4, 1.4);
          canvas.strokePath();

          // Dot fill
          canvas.setStrokeColor(color);
          canvas.setFillColor(color);
          canvas.drawEllipse(2, 2, 1.2, 1.2);
          canvas.fillPath();
        },
      ),
    );
  }
}
