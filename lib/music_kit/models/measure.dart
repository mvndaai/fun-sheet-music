import 'music_note.dart';

/// Represents a measure (bar) of music.
class Measure {
  final int number;
  final List<MusicNote> notes;
  final int beats;
  final int beatType;

  const Measure({
    required this.number,
    required this.notes,
    this.beats = 4,
    this.beatType = 4,
  });

  List<MusicNote> get playableNotes =>
      notes.where((n) => !n.isChordContinuation).toList();
}
