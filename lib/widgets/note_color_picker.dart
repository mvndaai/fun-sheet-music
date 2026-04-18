import 'package:flutter/material.dart';

/// A simple preset color palette dialog.
///
/// Call [showNoteColorPicker] to let the user pick one color from a curated
/// grid, then receive the chosen [Color] in the returned Future.
Future<Color?> showNoteColorPicker(
  BuildContext context, {
  required Color current,
  String? label,
}) {
  return showDialog<Color>(
    context: context,
    builder: (_) => _NoteColorPickerDialog(current: current, label: label),
  );
}

class _NoteColorPickerDialog extends StatefulWidget {
  final Color current;
  final String? label;
  const _NoteColorPickerDialog({required this.current, this.label});

  @override
  State<_NoteColorPickerDialog> createState() => _NoteColorPickerDialogState();
}

class _NoteColorPickerDialogState extends State<_NoteColorPickerDialog> {
  late Color _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.label != null ? 'Color for ${widget.label}' : 'Pick a color'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preview
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 36,
              decoration: BoxDecoration(
                color: _selected,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(height: 12),
            // Color grid
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _palette.map((color) {
                    final isSelected = _selected == color;
                    return GestureDetector(
                      onTap: () => setState(() => _selected = color),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _selected),
          child: const Text('Select'),
        ),
      ],
    );
  }
}

/// A hand-curated palette of distinct, saturated colors suitable for note circles.
const List<Color> _palette = [
  // Reds
  Color(0xFFD50000), Color(0xFFFF1744), Color(0xFFFF6D00),
  Color(0xFFE91E63), Color(0xFFAD1457), Color(0xFFD81B60),
  // Oranges / Yellows
  Color(0xFFF57C00), Color(0xFFFF8F00), Color(0xFFFFAB00),
  Color(0xFFFFD600), Color(0xFFFDD835), Color(0xFFFFFF00),
  // Greens
  Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047),
  Color(0xFF76FF03), Color(0xFF00E676), Color(0xFF69F0AE),
  // Blues / Teals
  Color(0xFF006064), Color(0xFF00838F), Color(0xFF00ACC1),
  Color(0xFF039BE5), Color(0xFF1565C0), Color(0xFF1E88E5),
  Color(0xFF00B0FF), Color(0xFF0D47A1), Color(0xFF2979FF),
  // Purples / Pinks
  Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF8E24AA),
  Color(0xFFAB47BC), Color(0xFFCE93D8), Color(0xFFD500F9),
  Color(0xFF9C27B0), Color(0xFF7B1FA2), Color(0xFF651FFF),
  // Browns / Neutrals
  Color(0xFF795548), Color(0xFF8D6E63), Color(0xFF9E9E9E),
  Color(0xFF546E7A), Color(0xFF78909C), Color(0xFFB0BEC5),
  Color(0xFF212121), Color(0xFF424242), Color(0xFF757575),
  Color(0xFFFFFFFF), Color(0xFFF5F5F5), Color(0xFFBDBDBD),
];
