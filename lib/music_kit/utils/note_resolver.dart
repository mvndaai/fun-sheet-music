import '../models/music_note.dart';
import '../models/instrument_profile.dart';
import 'music_constants.dart';
import 'note_map_lookup.dart';

/// Handles resolving musical notes considering enharmonics, octaves, and instrument-specific tunings.
class NoteResolver {
  NoteResolver._();

  /// Resolves the target note name that the app should listen for or display,
  /// accounting for instrument-specific [activeScheme] tuning overrides.
  static String resolveTargetNote({
    required MusicNote note,
    required InstrumentProfile activeScheme,
  }) {
    final specificNote = note.letterName; // e.g. "C5"

    // Use consistent lookup pattern for tuning overrides
    final tuningResult = NoteMapLookup.lookup<String>(
      noteName: specificNote,
      primaryMap: activeScheme.tuningOverrides,
      isEmpty: (value) => value.isEmpty,
    );
    
    if (tuningResult != null) return tuningResult;

    // Fallback to octave 4 mapping with interval shift (for transposing instruments)
    final step = NoteMapLookup.normalizeToSharps(note.step);
    final base4 = '${step}4';
    
    final mapped4 = activeScheme.tuningOverrides[base4];
    if (mapped4 != null) {
      // Apply the same interval shift to the current note's octave
      final originalMidi4 = MusicConstants.noteNameToMidi(base4);
      final mappedMidi4 = MusicConstants.noteNameToMidi(mapped4);
      if (originalMidi4 > 0 && mappedMidi4 > 0) {
        final shift = mappedMidi4 - originalMidi4;
        return MusicConstants.midiToNoteName(note.midiNumber + shift);
      }
    }

    return specificNote;
  }
}
