import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/instrument_color_scheme.dart';
import '../providers/color_scheme_provider.dart';
import '../widgets/note_color_picker.dart';

/// Screen for managing instrument color schemes.
/// Users can activate built-in or custom schemes, create new ones by copying
/// any existing scheme, edit custom note colors, and delete custom schemes.
class ColorSchemesScreen extends StatelessWidget {
  const ColorSchemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instrument Colors'),
        actions: [
          Consumer<ColorSchemeProvider>(
            builder: (context, provider, _) => IconButton(
              icon: Icon(
                provider.showNoteLabels
                    ? Icons.label
                    : Icons.label_off,
              ),
              tooltip: provider.showNoteLabels
                  ? 'Note labels: ON – tap to turn off'
                  : 'Note labels: OFF – tap to turn on',
              onPressed: () =>
                  provider.setShowNoteLabels(!provider.showNoteLabels),
            ),
          ),
        ],
      ),
      body: Consumer<ColorSchemeProvider>(
        builder: (context, provider, _) {
          final schemes = provider.allSchemes;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Note-label toggle banner
              _LabelToggleBanner(provider: provider),

              Expanded(
                child: ListView.separated(
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
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context),
        icon: const Icon(Icons.add),
        label: const Text('New Scheme'),
      ),
    );
  }

  Future<void> _createNew(BuildContext context) async {
    final provider = context.read<ColorSchemeProvider>();
    final name = await _promptName(context, initial: '');
    if (name == null) return;
    final scheme = await provider.createCustom(name: name.trim());
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
        title: const Text('Delete scheme'),
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

  Future<String?> _promptName(BuildContext context, {required String initial}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: initial),
    );
  }
}

// ── Simple name-entry dialog with proper controller disposal ─────────────

class _NameDialog extends StatefulWidget {
  final String initial;
  const _NameDialog({required this.initial});

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scheme name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'e.g. My Blue Xylophone',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ── Banner showing the global note-label toggle ───────────────────────────

class _LabelToggleBanner extends StatelessWidget {
  final ColorSchemeProvider provider;
  const _LabelToggleBanner({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.label_outline, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Note labels',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Switch(
            value: provider.showNoteLabels,
            onChanged: provider.setShowNoteLabels,
          ),
        ],
      ),
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
              Radio<bool>(
                value: true,
                groupValue: isActive,
                onChanged: (_) => onActivate(),
              ),
              const SizedBox(width: 4),
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
                          value: 'edit', child: Text('Edit colors')),
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
    return Wrap(
      spacing: 4,
      children: kNoteKeys.map((note) {
        final color = scheme.colors[note] ?? Colors.grey;
        return Tooltip(
          message: note,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1),
            ),
          ),
        );
      }).toList(),
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
  late String _name;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _colors = Map.from(widget.scheme.colors);
    _name = widget.scheme.name;
  }

  Future<void> _save() async {
    final updated = widget.scheme.copyWith(name: _name, colors: _colors);
    await context.read<ColorSchemeProvider>().updateCustom(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      setState(() => _dirty = false);
    }
  }

  Future<void> _rename() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(initial: _name),
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _name = result.trim();
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: _rename,
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
        itemCount: kNoteKeys.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final note = kNoteKeys[index];
          final color = _colors[note] ?? Colors.grey;
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
              '#${color.value.toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.color_lens_outlined),
            onTap: () async {
              final picked = await showNoteColorPicker(
                context,
                current: color,
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
