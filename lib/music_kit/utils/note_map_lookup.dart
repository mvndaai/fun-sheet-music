/// Utility for consistent note-based map lookups with fallback logic.
/// 
/// Implements a standardized lookup order:
/// 1. Exact match with octave (e.g., "C#5")
/// 2. Step-only "default" (e.g., "C#" without octave - applies to all octaves)
/// 3. Standard/fallback map - same pattern
class NoteMapLookup {
  NoteMapLookup._();

  /// Normalizes flats to sharps (Db -> C#)
  static String normalizeToSharps(String note) {
    return note
        .replaceAll('Db', 'C#')
        .replaceAll('Eb', 'D#')
        .replaceAll('Gb', 'F#')
        .replaceAll('Ab', 'G#')
        .replaceAll('Bb', 'A#');
  }

  /// Performs a consistent lookup in a map with fallback logic.
  /// 
  /// [noteName] - The note to look up (e.g., "C#5", "Db4")
  /// [primaryMap] - The primary map to search first
  /// [fallbackMap] - Optional fallback map to search if not found in primary
  /// [isEmpty] - Function to check if a value is considered empty/invalid
  static T? lookup<T>({
    required String noteName,
    required Map<String, T> primaryMap,
    Map<String, T>? fallbackMap,
    bool Function(T value)? isEmpty,
  }) {
    // Normalize to sharps for consistent lookup (Db -> C#)
    final normalized = normalizeToSharps(noteName);
    final isEmptyFn = isEmpty ?? (T value) => false;

    // Extract step (note without octave)
    final step = normalized.replaceAll(RegExp(r'\d'), '');

    // Try primary map first
    final result = _tryLookup(
      normalized: normalized,
      step: step,
      map: primaryMap,
      isEmpty: isEmptyFn,
    );
    if (result != null) return result;

    // Try fallback map if provided
    if (fallbackMap != null) {
      return _tryLookup(
        normalized: normalized,
        step: step,
        map: fallbackMap,
        isEmpty: isEmptyFn,
      );
    }

    return null;
  }

  /// Internal helper to try lookups in order
  static T? _tryLookup<T>({
    required String normalized,
    required String step,
    required Map<String, T> map,
    required bool Function(T) isEmpty,
  }) {
    // 1. Exact match (e.g., "C#5")
    final exact = map[normalized];
    if (exact != null && !isEmpty(exact)) return exact;

    // 2. Step-only "default" (e.g., "C#" - applies to all octaves)
    final stepOnly = map[step];
    if (stepOnly != null && !isEmpty(stepOnly)) return stepOnly;

    return null;
  }
}
