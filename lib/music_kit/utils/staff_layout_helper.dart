import '../models/measure.dart';
import '../models/music_note.dart';

/// Centralizes the mathematical logic for laying out musical elements on a staff.
class StaffLayoutHelper {
  /// Width reserved for the time signature if it changes.
  static const double kTimeSigReservedW = 32.0;
  
  /// Internal padding at the start and end of a measure.
  static const double kMeasurePadding = 8.0;

  /// Calculates the horizontal position (X) for a note within a measure.
  ///
  /// [startX] is the absolute X coordinate of the measure's beginning.
  /// [measureWidth] is the total width allocated to this measure.
  /// [hasTimeSig] whether a time signature is displayed at the start of this measure.
  /// [cumulativeDuration] the sum of durations of all previous notes in this measure.
  static double getNoteX({
    required Measure measure,
    required double startX,
    required double measureWidth,
    required bool hasTimeSig,
    required double cumulativeDuration,
    required List<MusicNote> displayNotes,
  }) {
    final double tsReserved = hasTimeSig ? kTimeSigReservedW : 0.0;
    final double usableW = (measureWidth - tsReserved - (kMeasurePadding * 2)).clamp(0.0, measureWidth);
    
    // Logic from staff_painter.dart
    final double durationToBeats = measure.beatType / 4.0;
    final double beatsInMeasure = measure.beats > 0 ? measure.beats.toDouble() : 1.0;
    
    final double totalNoteDurationBeats = displayNotes.fold(0.0, (sum, n) => sum + n.duration) * durationToBeats;
    final double effectiveBeats = (totalNoteDurationBeats > beatsInMeasure) ? totalNoteDurationBeats : beatsInMeasure;
    
    final double beatW = usableW / effectiveBeats;
    final double beatIndex = cumulativeDuration * durationToBeats;
    
    return startX + tsReserved + kMeasurePadding + (beatIndex + 0.5) * beatW;
  }

  /// Calculates the X position for the end of a beam.
  static double getBeamEndX({
    required Measure measure,
    required double startX,
    required double measureWidth,
    required bool hasTimeSig,
    required double cumulativeDuration,
    required double nextNoteOffset,
    required List<MusicNote> displayNotes,
  }) {
    final double tsReserved = hasTimeSig ? kTimeSigReservedW : 0.0;
    final double usableW = (measureWidth - tsReserved - (kMeasurePadding * 2)).clamp(0.0, measureWidth);
    
    final double durationToBeats = measure.beatType / 4.0;
    final double beatsInMeasure = measure.beats > 0 ? measure.beats.toDouble() : 1.0;
    
    final double totalNoteDurationBeats = displayNotes.fold(0.0, (sum, n) => sum + n.duration) * durationToBeats;
    final double effectiveBeats = (totalNoteDurationBeats > beatsInMeasure) ? totalNoteDurationBeats : beatsInMeasure;
    
    final double beatW = usableW / effectiveBeats;
    final double nextBeatIndex = (cumulativeDuration + nextNoteOffset) * durationToBeats;
    
    return startX + tsReserved + kMeasurePadding + (nextBeatIndex + 0.5) * beatW;
  }
}
