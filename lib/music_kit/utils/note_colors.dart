import 'package:flutter/material.dart';

/// Color mappings for musical notes, inspired by children's xylophone colors.
class NoteColors {
  NoteColors._();

  static const Map<String, Color> _noteColorMap = {
    'C': Color(0xFFE53935), // Red
    'C#': Color(0xFFD81B60), // Dark Pink
    'Db': Color(0xFFD81B60), // Dark Pink
    'D': Color(0xFFF57C00), // Orange
    'D#': Color(0xFFE65100), // Dark Orange
    'Eb': Color(0xFFE65100), // Dark Orange
    'E': Color(0xFFFBC02D), // Deep Yellow (Yellow 700)
    'F': Color(0xFF43A047), // Green
    'F#': Color(0xFF2E7D32), // Dark Green
    'Gb': Color(0xFF2E7D32), // Dark Green
    'G': Color(0xFF00ACC1), // Teal/Cyan
    'G#': Color(0xFF00695C), // Dark Teal
    'Ab': Color(0xFF00695C), // Dark Teal
    'A': Color(0xFF1E88E5), // Blue
    'A#': Color(0xFF1565C0), // Dark Blue
    'Bb': Color(0xFF1565C0), // Dark Blue
    'B': Color(0xFF8E24AA), // Purple
  };

  /// Returns the display color for a given note step and alteration.
  static Color forNote(String step, double alter) {
    if (alter == 1) {
      return _noteColorMap['$step#'] ?? _noteColorMap[step] ?? Colors.grey;
    } else if (alter == -1) {
      return _noteColorMap['${step}b'] ?? _noteColorMap[step] ?? Colors.grey;
    }
    return _noteColorMap[step] ?? Colors.grey;
  }

  /// Returns the color for rest notes.
  static const Color restColor = Color(0xFFBDBDBD); // Light grey

  /// Luminance threshold above which black text is readable on the background.
  /// Used by [textColorFor]; duplicating this elsewhere is discouraged.
  static const double textLuminanceThreshold = 0.35;

  /// Returns a color suitable for text on top of the given background color.
  static Color textColorFor(Color background) {
    return background.computeLuminance() > textLuminanceThreshold
        ? Colors.black87
        : Colors.white;
  }

  /// Returns a list of all note colors in chromatic order (for legend display).
  static List<MapEntry<String, Color>> get chromatic => const [
        MapEntry('C', Color(0xFFE53935)),
        MapEntry('C#', Color(0xFFD81B60)),
        MapEntry('D', Color(0xFFF57C00)),
        MapEntry('D#', Color(0xFFE65100)),
        MapEntry('E', Color(0xFFFBC02D)),
        MapEntry('F', Color(0xFF43A047)),
        MapEntry('F#', Color(0xFF2E7D32)),
        MapEntry('G', Color(0xFF00ACC1)),
        MapEntry('G#', Color(0xFF00695C)),
        MapEntry('A', Color(0xFF1E88E5)),
        MapEntry('A#', Color(0xFF1565C0)),
        MapEntry('B', Color(0xFF8E24AA)),
      ];
}
