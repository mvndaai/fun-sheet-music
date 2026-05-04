import 'package:flutter/services.dart';

class KeyboardUtils {
  KeyboardUtils._();

  /// Returns a descriptive name for a key event, falling back to logical keys
  /// if physical key information is missing or generic (common on Android Chrome).
  static String getEventKeyName(KeyEvent event) {
    String name = event.physicalKey.debugName?.replaceAll(' ', '') ?? '';

    // If physical key is generic or missing, fallback to logical key.
    if (name == 'Key' || name.isEmpty) {
      final logicalName = event.logicalKey.debugName?.replaceAll(' ', '') ?? '';
      if (logicalName.isNotEmpty && logicalName != 'Key') {
        name = logicalName;
      } else if (event.logicalKey.keyLabel.isNotEmpty) {
        name = event.logicalKey.keyLabel;
      }
    }
    
    return name;
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

  /// Formats a mapping string for UI display, e.g., "Shift+KeyA" -> "⇧A"
  static String formatForDisplay(String? mapping) {
    if (mapping == null) return '';
    return mapping
        .replaceAll('Key', '')
        .replaceAll('Control+Shift+', '⌃⇧')
        .replaceAll('Control+', '⌃')
        .replaceAll('Shift+', '⇧')
        .replaceAll('Alt+', '⌥');
  }
}
