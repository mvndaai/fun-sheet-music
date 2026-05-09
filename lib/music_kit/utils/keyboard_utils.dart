import 'package:flutter/services.dart';

class KeyboardUtils {
  KeyboardUtils._();

  /// Returns a descriptive name for a key event.
  /// Uses keyLabel for consistency across platforms (Web, Android, iOS, Desktop).
  static String getEventKeyName(KeyEvent event) {
    // Use keyLabel which is consistent across all platforms
    // Returns lowercase: "a", "1", "shift", etc.
    final label = event.logicalKey.keyLabel;
    if (label.isNotEmpty) {
      // Normalize to uppercase for letter keys
      if (RegExp(r'^[a-z]$').hasMatch(label)) {
        return label.toUpperCase();
      }
      return label;
    }
    
    // Fallback to debugName if keyLabel is empty (rare)
    return event.physicalKey.debugName?.replaceAll(' ', '') ?? 
           event.logicalKey.debugName?.replaceAll(' ', '') ?? '';
  }

  /// Returns the internal mapping string, e.g., "Shift+KeyA" or "KeyA"
  static String getMappingName(KeyEvent event) {
    final keyName = getEventKeyName(event);
    final isControl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (isControl && HardwareKeyboard.instance.isShiftPressed) return 'Control+Shift+$keyName';
    if (isControl) return 'Control+$keyName';
    if (HardwareKeyboard.instance.isShiftPressed) return 'Shift+$keyName';
    if (HardwareKeyboard.instance.isAltPressed) return 'Alt+$keyName';
    return keyName;
  }

  /// Formats a mapping string for UI display, e.g., "Shift+A" -> "⇧A"
  static String formatForDisplay(String? mapping) {
    if (mapping == null) return '';
    return mapping
        .replaceAll('Control+Shift+', '⌃⇧')
        .replaceAll('Control+', '⌃')
        .replaceAll('Shift+', '⇧')
        .replaceAll('Alt+', '⌥');
  }
}
