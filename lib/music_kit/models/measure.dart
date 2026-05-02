import 'music_note.dart';

/// Represents a measure (bar) of music.
class Measure {
  final int number;
  final List<MusicNote> notes;
  final int beats;
  final int beatType;
  final bool isPickup;

  const Measure({
    required this.number,
    required this.notes,
    this.beats = 4,
    this.beatType = 4,
    this.isPickup = false,
  });

  List<MusicNote> get playableNotes =>
      notes.where((n) => !n.isChordContinuation && !n.isRest).toList();

  List<MusicNote> get allDisplayNotes =>
      notes.where((n) => !n.isChordContinuation).toList();

  Measure copyWith({
    int? number,
    List<MusicNote>? notes,
    int? beats,
    int? beatType,
    bool? isPickup,
  }) {
    return Measure(
      number: number ?? this.number,
      notes: notes ?? this.notes,
      beats: beats ?? this.beats,
      beatType: beatType ?? this.beatType,
      isPickup: isPickup ?? this.isPickup,
    );
  }
}
