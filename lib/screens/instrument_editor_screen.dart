import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../widgets/note_color_picker.dart';
import '../widgets/instrument_setup/add_key_wizard.dart';
import 'instrument_setup_screen.dart';
import 'instruments_screen.dart'; // For _InstrumentIcon and _NameIconEmojiDialog which should probably also be moved or made public

/// Screen for editing an instrument's colors, tuning, and metadata.
class InstrumentEditorScreen extends StatefulWidget {
  final InstrumentProfile scheme;
  const InstrumentEditorScreen({super.key, required this.scheme});

  @override
  State<InstrumentEditorScreen> createState() => _InstrumentEditorScreenState();
}

class _InstrumentEditorScreenState extends State<InstrumentEditorScreen> {
  late Map<String, Color> _colors;
  late Map<String, Color> _octaveOverrides;
  late Set<String> _hiddenKeys;
  late Map<String, String> _tuningOverrides;
  late String _name;
  late String? _icon;
  late String? _emoji;

  @override
  void initState() {
    super.initState();
    _colors = Map.from(widget.scheme.colors);
    _octaveOverrides = Map.from(widget.scheme.octaveOverrides);
    _hiddenKeys = Set.from(widget.scheme.hiddenKeys);
    _tuningOverrides = Map.from(widget.scheme.tuningOverrides);
    _name = widget.scheme.name;
    _icon = widget.scheme.icon;
    _emoji = widget.scheme.emoji;
  }

  Future<void> _save() async {
    final updated = widget.scheme.withIconOnly(
      icon: _icon,
      emoji: _emoji,
    ).copyWith(
      name: _name,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      hiddenKeys: _hiddenKeys,
      tuningOverrides: _tuningOverrides,
    );
    await context.read<InstrumentProvider>().updateCustom(updated);
  }

  Future<void> _editInfo() async {
    // This depends on _NameIconEmojiDialog from instruments_screen.dart
    // For now I'll assume it's made public or I'll move it here.
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => NameIconEmojiDialog(
        initialName: _name,
        initialIcon: _icon,
        initialEmoji: _emoji,
      ),
    );
    if (result != null) {
      final name = result['name'] ?? '';
      final icon = result['icon'] ?? '';
      final emoji = result['emoji'] ?? '';
      setState(() {
        _name = name.trim();
        _icon = icon.isNotEmpty ? icon.trim() : null;
        _emoji = emoji.isNotEmpty ? emoji.trim() : null;
      });
      _save();
    }
  }

  Future<void> _addKeyWizard() async {
    final result = await showAddKeyWizard(context);
    if (result == null) return;
    setState(() {
      _octaveOverrides[result.noteKey] = result.color;
    });
    _save();
  }

  Future<void> _tuneInstrument() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstrumentSetupScreen(
          scheme: widget.scheme.copyWith(
            name: _name,
            icon: _icon,
            colors: _colors,
            octaveOverrides: _octaveOverrides,
          ),
          initialMode: SetupMode.tuning,
        ),
      ),
    );
  }

  Widget _buildChromaticRow(int index, InstrumentProfile currentScheme) {
    final note = kNoteKeys[index];
    final color = _colors[note] ?? currentScheme.colorForNote(note, 0, context: context);
    final isHidden = _hiddenKeys.contains(note);
    
    // Check if there is a tuning override for the base note (using octave 4 as reference)
    final tunedTo = _tuningOverrides['${note}4'];
    
    final textColor = color.computeLuminance() > 0.35
        ? Colors.black87
        : Colors.white;

    return Opacity(
      opacity: isHidden ? 0.4 : 1.0,
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              note,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Text(note),
            if (tunedTo != null && tunedTo != '${note}4') ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                tunedTo,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.tune, size: 14, color: Colors.grey),
            ],
          ],
        ),
        subtitle: Text(
          isHidden
              ? 'Hidden for this instrument'
              : '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: !isHidden,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _hiddenKeys.remove(note);
                  } else {
                    _hiddenKeys.add(note);
                  }
                });
                _save();
              },
            ),
            const Icon(Icons.color_lens_outlined),
          ],
        ),
        onTap: isHidden
            ? null
            : () async {
                final picked = await showNoteColorPicker(
                  context,
                  current: color,
                  label: note,
                );
                if (picked != null) {
                  setState(() {
                    _colors[note] = picked;
                  });
                  _save();
                }
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentScheme = widget.scheme.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      hiddenKeys: _hiddenKeys,
      tuningOverrides: _tuningOverrides,
    );
    final overrideKeys = _octaveOverrides.keys.toList()..sort();
    final hasOverrides = overrideKeys.isNotEmpty;
    final n = overrideKeys.length;

    final totalItems = 1 + n + 1 + 12;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            InstrumentIcon(scheme: currentScheme, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(_name)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Tune all keys',
            onPressed: _tuneInstrument,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit name and icon',
            onPressed: _editInfo,
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: totalItems,
        separatorBuilder: (_, i) {
          if (i == 0 || i == n + 1) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
              child: Row(
                children: [
                  const Icon(Icons.piano_outlined, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'My Keys',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  if (!hasOverrides)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        '(none yet – tap "Add Key" to get started)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            );
          }

          if (index > 0 && index <= n) {
            final key = overrideKeys[index - 1];
            final color = _octaveOverrides[key]!;
            final tunedTo = _tuningOverrides[key];
            final textColor = color.computeLuminance() > 0.35
                ? Colors.black87
                : Colors.white;
            return ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    key,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              title: Row(
                children: [
                  Text(key),
                  if (tunedTo != null && tunedTo != key) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      tunedTo,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.tune, size: 14, color: Colors.grey),
                  ],
                ],
              ),
              subtitle: Text(
                '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.color_lens_outlined),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Remove override',
                    onPressed: () {
                      setState(() {
                        _octaveOverrides.remove(key);
                      });
                      _save();
                    },
                  ),
                ],
              ),
              onTap: () async {
                final picked = await showNoteColorPicker(
                  context,
                  current: color,
                  label: key,
                );
                if (picked != null) {
                  setState(() {
                    _octaveOverrides[key] = picked;
                  });
                  _save();
                }
              },
            );
          }

          if (index == n + 1) {
            return ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.add),
              ),
              title: const Text('Add Key…'),
              subtitle: const Text(
                'Hit a key on your instrument to detect its note, then choose a color',
                style: TextStyle(fontSize: 12),
              ),
              onTap: _addKeyWizard,
            );
          }

          final chromaticIndex = index - (n + 2);
          if (chromaticIndex == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 32),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Default Colors',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                _buildChromaticRow(chromaticIndex, currentScheme),
              ],
            );
          }
          return _buildChromaticRow(chromaticIndex, currentScheme);
        },
      ),
    );
  }
}
