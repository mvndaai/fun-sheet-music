import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instrument_color_scheme.dart';
import '../providers/color_scheme_provider.dart';
import '../widgets/note_color_picker.dart';
import '../widgets/add_key_wizard.dart';

/// Screen for managing instrument color schemes.
/// Users can activate built-in or custom schemes, create new ones by copying
/// any existing scheme, edit custom note colors, and delete custom schemes.
class ColorSchemesScreen extends StatelessWidget {
  const ColorSchemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruments'),
      ),
      body: Consumer<ColorSchemeProvider>(
        builder: (context, provider, _) {
          final schemes = provider.allSchemes;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: schemes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final scheme = schemes[index];
              return _SchemeCard(
                scheme: scheme,
                isActive: provider.activeId == scheme.id,
                onActivate: () => provider.setActive(scheme.id),
                onEdit: scheme.isBuiltIn
                    ? null
                    : () => _openEditor(context, scheme, provider),
                onDelete: scheme.isBuiltIn
                    ? null
                    : () => _confirmDelete(context, scheme, provider),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context),
        icon: const Icon(Icons.add),
        label: const Text('New'),
      ),
    );
  }

  Future<void> _createNew(BuildContext context) async {
    final provider = context.read<ColorSchemeProvider>();
    final result = await _promptNameAndIcon(context, initialName: '', initialIcon: '');
    if (result == null) return;
    final name = result['name'] ?? '';
    final icon = result['icon'] ?? '';
    final scheme = await provider.createCustom(
      name: name.trim(),
      icon: icon.trim(),
    );
    if (context.mounted) {
      await _openEditor(context, scheme, provider);
    }
  }

  Future<void> _openEditor(
    BuildContext context,
    InstrumentColorScheme scheme,
    ColorSchemeProvider provider,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SchemeEditorScreen(scheme: scheme),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InstrumentColorScheme scheme,
    ColorSchemeProvider provider,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete instrument'),
        content: Text('Delete "${scheme.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteCustom(scheme.id);
  }

  Future<Map<String, String>?> _promptNameAndIcon(
    BuildContext context, {
    required String initialName,
    required String initialIcon,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _NameIconDialog(
        initialName: initialName,
        initialIcon: initialIcon,
      ),
    );
  }
}

// ── Name & Icon dialog ───────────────────────────────────────────────────

class _NameIconDialog extends StatefulWidget {
  final String initialName;
  final String? initialIcon;
  const _NameIconDialog({required this.initialName, this.initialIcon});

  @override
  State<_NameIconDialog> createState() => _NameIconDialogState();
}

class _NameIconDialogState extends State<_NameIconDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _iconController =
      TextEditingController(text: widget.initialIcon);

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Instrument info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. My Blue Xylophone',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _iconController,
            decoration: const InputDecoration(
              labelText: 'Icon URL (optional)',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, {
            'name': _nameController.text,
            'icon': _iconController.text,
          }),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ── Scheme card ───────────────────────────────────────────────────────────

class _SchemeCard extends StatelessWidget {
  final InstrumentColorScheme scheme;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _SchemeCard({
    required this.scheme,
    required this.isActive,
    required this.onActivate,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onActivate,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              // Active indicator
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isActive ? Theme.of(context).colorScheme.primary : null,
              ),
              const SizedBox(width: 8),
              if (scheme.icon != null && scheme.icon!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Image.network(
                    scheme.icon!,
                    width: 32,
                    height: 32,
                    errorBuilder: (_, __, ___) => const Icon(Icons.music_note, size: 32),
                  ),
                )
              else
                const Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(Icons.music_note, size: 32),
                ),
              // Color swatch row
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scheme.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _ColorSwatchRow(scheme: scheme),
                  ],
                ),
              ),
              // Actions
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') onEdit?.call();
                    if (v == 'delete') onDelete?.call();
                  },
                  itemBuilder: (_) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                          value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(
                          value: 'delete', child: Text('Delete')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatchRow extends StatelessWidget {
  final InstrumentColorScheme scheme;
  const _ColorSwatchRow({required this.scheme});

  @override
  Widget build(BuildContext context) {
    // List of note names that have explicit colors or overrides
    final coloredNotes = kNoteKeys.where((n) => scheme.colors.containsKey(n));
    final overrideKeys = scheme.octaveOverrides.keys.toList()..sort();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...coloredNotes.map((note) {
          final color = scheme.colors[note]!;
          return _SwatchCircle(label: note, color: color);
        }),
        ...overrideKeys.map((key) {
          final color = scheme.octaveOverrides[key]!;
          return _SwatchCircle(label: key, color: color);
        }),
      ],
    );
  }
}

class _SwatchCircle extends StatelessWidget {
  final String label;
  final Color color;
  const _SwatchCircle({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
    );
  }
}

// ── Scheme editor screen ──────────────────────────────────────────────────

class _SchemeEditorScreen extends StatefulWidget {
  final InstrumentColorScheme scheme;
  const _SchemeEditorScreen({required this.scheme});

  @override
  State<_SchemeEditorScreen> createState() => _SchemeEditorScreenState();
}

class _SchemeEditorScreenState extends State<_SchemeEditorScreen> {
  late Map<String, Color> _colors;
  late Map<String, Color> _octaveOverrides;
  late String _name;
  late String? _icon;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _colors = Map.from(widget.scheme.colors);
    _octaveOverrides = Map.from(widget.scheme.octaveOverrides);
    _name = widget.scheme.name;
    _icon = widget.scheme.icon;
  }

  Future<void> _save() async {
    final updated = widget.scheme.copyWith(
      name: _name,
      icon: _icon,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
    );
    await context.read<ColorSchemeProvider>().updateCustom(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      setState(() => _dirty = false);
    }
  }

  Future<void> _editInfo() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _NameIconDialog(
        initialName: _name,
        initialIcon: _icon ?? '',
      ),
    );
    if (result != null) {
      final name = result['name'] ?? '';
      final icon = result['icon'] ?? '';
      setState(() {
        _name = name.trim();
        _icon = icon.trim();
        _dirty = true;
      });
    }
  }

  Future<void> _addKeyWizard() async {
    final result = await showAddKeyWizard(context);
    if (result == null) return;
    setState(() {
      _octaveOverrides[result.noteKey] = result.color;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final overrideKeys = _octaveOverrides.keys.toList()..sort();
    // Total items: 12 chromatic notes + optional section header + overrides + add-button row
    final hasOverrides = overrideKeys.isNotEmpty;
    // Item layout:
    //   0 .. 11            → chromatic note rows
    //   12                 → "Octave overrides" header
    //   13 .. 13+n-1       → override rows
    //   13+n               → "Add override" row
    final totalItems = 12 + 1 + overrideKeys.length + 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit name and icon',
            onPressed: _editInfo,
          ),
          if (_dirty)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save',
              onPressed: _save,
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: totalItems,
        separatorBuilder: (_, i) {
          // No divider before/after the section header row.
          if (i == 11 || i == 12) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          // ── Chromatic note rows ────────────────────────────────────────
          if (index < 12) {
            final note = kNoteKeys[index];
            final color = widget.scheme.colorForNote(note, 0, context: context);
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
                    note,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              title: Text(note),
              subtitle: Text(
                '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.color_lens_outlined),
              onTap: () async {
                // If it's pure black or white, it might be the default "theme-aware" color.
                // We pass the actual stored color (or black as default) to the picker.
                final storedColor = _colors[note] ?? Colors.black;
                final picked = await showNoteColorPicker(
                  context,
                  current: storedColor,
                  label: note,
                );
                if (picked != null) {
                  setState(() {
                    _colors[note] = picked;
                    _dirty = true;
                  });
                }
              },
            );
          }

          // ── Keys section header ────────────────────────────────────────
          if (index == 12) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
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

          // ── Override rows ──────────────────────────────────────────────
          final overrideIndex = index - 13;
          if (overrideIndex >= 0 && overrideIndex < overrideKeys.length) {
            final key = overrideKeys[overrideIndex];
            final color = _octaveOverrides[key]!;
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
              title: Text(key),
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
                        _dirty = true;
                      });
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
                    _dirty = true;
                  });
                }
              },
            );
          }

          // ── Add key button ─────────────────────────────────────────────
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
        },
      ),
      floatingActionButton: _dirty
          ? FloatingActionButton.extended(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            )
          : null,
    );
  }
}
