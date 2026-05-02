import 'dart:math' as math;

/// Musical constants and helper functions.
class MusicConstants {
  MusicConstants._();

  /// Maps note type names to their relative beat durations.
  static const Map<String, double> typeToDuration = {
    '1024th': 1 / 256,
    '512th': 1 / 128,
    '256th': 1 / 64,
    '128th': 1 / 32,
    '64th': 1 / 16,
    '32nd': 1 / 8,
    '16th': 1 / 4,
    'eighth': 1 / 2,
    'quarter': 1.0,
    'half': 2.0,
    'whole': 4.0,
    'breve': 8.0,
    'long': 16.0,
    'maxima': 32.0,
  };

  /// Maps MIDI semitone offsets (0–11) to note names.
  static const List<String> chromaticNotes = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'
  ];

  /// Maps note steps to their solfège syllables (fixed Do).
  static const Map<String, String> stepToSolfege = {
    'C': 'Do',
    'D': 'Re',
    'E': 'Mi',
    'F': 'Fa',
    'G': 'Sol',
    'A': 'La',
    'B': 'Si',
  };

  /// Frequency tolerance for pitch detection (in semitones).
  static const double pitchToleranceSemitones = 0.5;

  /// Returns the closest note name to a given frequency (Hz).
  static String frequencyToNoteName(double frequency) {
    return midiToNoteName(frequencyToMidi(frequency));
  }

  /// Returns the note name for a given MIDI number.
  static String midiToNoteName(int midi) {
    if (midi < 0 || midi > 127) return '';
    final semitone = midi % 12;
    final octave = (midi ~/ 12) - 1;
    return '${chromaticNotes[semitone]}$octave';
  }

  /// Returns the MIDI number for a given frequency.
  static int frequencyToMidi(double frequency) {
    if (frequency <= 0) return -1;
    return (12 * math.log(frequency / 440.0) / math.log(2) + 69).round();
  }

  /// Returns the MIDI number for a given note name (e.g. "C5", "F#4").
  static int noteNameToMidi(String name) {
    if (name.isEmpty) return -1;
    // Parse e.g. "C5", "F#4", "Bb3"
    final match = RegExp(r'^([A-G])([#b])?(-?\d+)$').firstMatch(name);
    if (match == null) return -1;
    final step = match.group(1)!;
    final acc = match.group(2) ?? '';
    final octave = int.tryParse(match.group(3)!) ?? 4;
    const semitones = {
      'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11
    };
    final base = semitones[step] ?? 0;
    final alter = acc == '#' ? 1 : acc == 'b' ? -1 : 0;
    return 12 * (octave + 1) + base + alter;
  }

  /// Returns the frequency (Hz) for a given MIDI number.
  static double midiToFrequency(int midi) {
    if (midi < 0) return 0;
    return 440.0 * math.pow(2.0, (midi - 69) / 12.0).toDouble();
  }

  /// List of instrument emojis.
  static const List<String> instrumentEmojis = [
    '🎹', '🎸', '🎻', '🎷', '🎺', '🪕', '🥁', '🪘', '🪗', '🪈', '📯', '🔔', '🎵', '🎶', '🎼', '🎤', '🎧', '📻', '🎙️', '🎚️', '🎛️', '🔊', '🔉', '🔈', '🔇', '📣', '📢', '🔕', '🌈', '✨', '⭐', '🌟'
  ];

  /// A more comprehensive list of emojis with names for searching.
  static const List<({String char, String name})> allEmojis = [
    // Music
    (char: '🎹', name: 'piano keyboard instrument'),
    (char: '🎸', name: 'guitar instrument music'),
    (char: '🎻', name: 'violin instrument music'),
    (char: '🎷', name: 'saxophone instrument music'),
    (char: '🎺', name: 'trumpet instrument music'),
    (char: '🪕', name: 'banjo instrument music'),
    (char: '🥁', name: 'drum instrument music'),
    (char: '🪘', name: 'long drum instrument music'),
    (char: '🪗', name: 'accordion instrument music'),
    (char: '🪈', name: 'flute instrument music'),
    (char: '📯', name: 'french horn instrument music'),
    (char: '🔔', name: 'bell instrument music'),
    (char: '🎵', name: 'note music'),
    (char: '🎶', name: 'notes music'),
    (char: '🎼', name: 'score music staff'),
    (char: '🎤', name: 'microphone sing music'),
    (char: '🎧', name: 'headphones listen music'),
    (char: '📻', name: 'radio music'),
    (char: '🎙️', name: 'studio microphone music'),
    // Smileys
    (char: '😀', name: 'grinning face happy smile'),
    (char: '😃', name: 'grinning face big eyes happy smile'),
    (char: '😄', name: 'grinning face squinting eyes happy smile'),
    (char: '😁', name: 'beaming face happy smile'),
    (char: '😆', name: 'grinning squinting face happy laugh'),
    (char: '😅', name: 'grinning face sweat happy relief'),
    (char: '😂', name: 'tears of joy laugh'),
    (char: '🤣', name: 'rolling on floor laughing'),
    (char: '😊', name: 'smiling face happy'),
    (char: '😇', name: 'innocent angel smile'),
    (char: '🙂', name: 'slightly smiling face'),
    (char: '🙃', name: 'upside down face'),
    (char: '😉', name: 'winking face'),
    (char: '😌', name: 'relieved face'),
    (char: '😍', name: 'heart eyes love'),
    (char: '🥰', name: 'smiling face with hearts love'),
    (char: '😘', name: 'blowing kiss love'),
    (char: '😋', name: 'yum delicious food'),
    (char: '😛', name: 'tongue face'),
    (char: '😜', name: 'winking tongue face'),
    (char: '🤪', name: 'zany crazy face'),
    (char: '😎', name: 'cool sunglasses'),
    (char: '🤩', name: 'star struck'),
    (char: '🥳', name: 'partying face celebrate'),
    (char: '😏', name: 'smirking face'),
    (char: '😒', name: 'unamused face'),
    (char: '😔', name: 'pensive sad face'),
    (char: '😟', name: 'worried face'),
    (char: '😕', name: 'confused face'),
    (char: '☹️', name: 'frowning face sad'),
    (char: '😲', name: 'astonished surprised face'),
    (char: '😳', name: 'flushed embarrassed face'),
    (char: '🥺', name: 'pleading begging face'),
    (char: '😢', name: 'crying sad face'),
    (char: '😭', name: 'loudly crying sad face'),
    (char: '😱', name: 'screaming scared face'),
    (char: '🥱', name: 'yawning face tired'),
    (char: '😤', name: 'triumph face angry'),
    (char: '😡', name: 'pouting face angry'),
    (char: '🤬', name: 'swearing face angry'),
    (char: '😈', name: 'smiling face with horns devil'),
    (char: '👿', name: 'angry face with horns devil'),
    (char: '💀', name: 'skull death'),
    (char: '💩', name: 'poop'),
    (char: '🤡', name: 'clown face'),
    (char: '👻', name: 'ghost'),
    (char: '👽', name: 'alien'),
    (char: '👾', name: 'alien monster video game'),
    (char: '🤖', name: 'robot face'),
    // Animals
    (char: '🐱', name: 'cat kitten pet'),
    (char: '🐶', name: 'dog puppy pet'),
    (char: '🐺', name: 'wolf'),
    (char: '🦁', name: 'lion'),
    (char: '🐯', name: 'tiger'),
    (char: '🦒', name: 'giraffe'),
    (char: '🦊', name: 'fox'),
    (char: '🐻', name: 'bear'),
    (char: '🐨', name: 'koala'),
    (char: '🐼', name: 'panda'),
    (char: '🐰', name: 'rabbit bunny'),
    (char: '🐹', name: 'hamster'),
    (char: '🐭', name: 'mouse'),
    (char: '🐸', name: 'frog'),
    (char: '🦄', name: 'unicorn magic'),
    (char: '🐲', name: 'dragon magic'),
    (char: '🦖', name: 't-rex dinosaur'),
    (char: '🐢', name: 'turtle'),
    (char: '🐙', name: 'octopus'),
    (char: '🦋', name: 'butterfly insect'),
    (char: '🐝', name: 'honeybee insect'),
    // Nature/Objects
    (char: '🌸', name: 'cherry blossom flower'),
    (char: '🌻', name: 'sunflower'),
    (char: '🌲', name: 'evergreen tree'),
    (char: '🌵', name: 'cactus'),
    (char: '🍎', name: 'red apple fruit'),
    (char: '🍓', name: 'strawberry fruit'),
    (char: '🍕', name: 'pizza food'),
    (char: '🍰', name: 'shortcake dessert food'),
    (char: '⚽', name: 'soccer ball sport'),
    (char: '🏀', name: 'basketball sport'),
    (char: '🎮', name: 'video game controller'),
    (char: '🚀', name: 'rocket ship space'),
    (char: '💡', name: 'light bulb idea'),
    (char: '💎', name: 'gem stone diamond'),
    (char: '🎁', name: 'gift present surprise'),
    (char: '🎈', name: 'balloon celebrate'),
    (char: '🎉', name: 'party popper celebrate'),
    (char: '🌟', name: 'shining star'),
    (char: '✨', name: 'sparkles magic'),
    (char: '❤️', name: 'red heart love'),
    (char: '🔥', name: 'fire hot'),
  ];
}
