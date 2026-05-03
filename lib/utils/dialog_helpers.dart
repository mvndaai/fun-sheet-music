import 'package:flutter/material.dart';

/// Helper methods for common dialog patterns.
class DialogHelpers {
  DialogHelpers._();

  /// Standard Cancel/OK button actions for dialogs.
  static List<Widget> cancelOk({
    required BuildContext context,
    required VoidCallback onOk,
    VoidCallback? onCancel,
    String okText = 'OK',
    String cancelText = 'Cancel',
  }) {
    return [
      TextButton(
        onPressed: onCancel ?? () => Navigator.pop(context),
        child: Text(cancelText),
      ),
      ElevatedButton(
        onPressed: onOk,
        child: Text(okText),
      ),
    ];
  }

  /// Standard Cancel/Delete button actions for delete confirmation dialogs.
  static List<Widget> cancelDelete({
    required BuildContext context,
    required VoidCallback onDelete,
    VoidCallback? onCancel,
    String deleteText = 'Delete',
  }) {
    return [
      TextButton(
        onPressed: onCancel ?? () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        onPressed: onDelete,
        child: Text(deleteText, style: const TextStyle(color: Colors.white)),
      ),
    ];
  }
}
