import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/instrument_color_scheme.dart';
import '../providers/color_scheme_provider.dart';
import '../utils/music_constants.dart';
import '../widgets/note_color_picker.dart';
import '../widgets/add_key_wizard.dart';
import '../widgets/tuning_wizard.dart';

/// Screen for managing instrument color schemes.
class ColorSchemesScreen extends StatelessWidget {
  const ColorSchemesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Search Library',
            onPressed: () => _openLibrary(context),
          ),
        ],
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
                onClone: () => provider.cloneScheme(scheme),
                onEdit: scheme.isBuiltIn
                    ? null
                    : () => _openEditor(context, scheme, provider),
                onDelete: scheme.isBuiltIn
                    ? null
                    : () => _confirmDelete(context, scheme, provider),
                onShare: (scheme.isBuiltIn || scheme.isImported)
                    ? null
                    : () => _shareScheme(context, scheme),
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

  Future<void> _openLibrary(BuildContext context) async {
    final provider = context.read<ColorSchemeProvider>();
    final library = await provider.loadLibrary();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LibrarySearchSheet(library: library),
    );
  }

  Future<void> _shareScheme(BuildContext context, InstrumentColorScheme scheme) async {
    final json = jsonEncode(scheme.toJson());
    final title = 'New Instrument: ${scheme.name}';
    final body = 'Please add this instrument to the built-in library.\n\n```json\n$json\n```';

    final url = Uri.parse(
      'https://github.com/mvndaai/flutter-music/issues/new'
      '?title=${Uri.encodeComponent(title)}'
      '&body=${Uri.encodeComponent(body)}'
      '&labels=new-instrument',
    );

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open GitHub')),
        );
      }
    }
  }

  Future<void> _createNew(BuildContext context) async {
    final provider = context.read<ColorSchemeProvider>();
    final result = await _promptNameIconEmoji(context, initialName: '', initialIcon: '', initialEmoji: '🎹');
    if (result == null) return;
    final name = result['name'] ?? '';
    final icon = result['icon'] ?? '';
    final emoji = result['emoji'] ?? '';
    final scheme = await provider.createCustom(
      name: name.trim(),
      icon: icon.trim(),
      emoji: emoji.trim(),
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

  Future<Map<String, String>?> _promptNameIconEmoji(
    BuildContext context, {
    required String initialName,
    required String initialIcon,
    required String initialEmoji,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _NameIconEmojiDialog(
        initialName: initialName,
        initialIcon: initialIcon,
        initialEmoji: initialEmoji,
      ),
    );
  }
}

class _LibrarySearchSheet extends StatefulWidget {
  final List<InstrumentColorScheme> library;
  const _LibrarySearchSheet({required this.library});

  @override
  State<_LibrarySearchSheet> createState() => _LibrarySearchSheetState();
}

class _LibrarySearchSheetState extends State<_LibrarySearchSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.library
        .where((s) => s.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Instrument Library', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by name...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: filtered.isEmpty
                ? const Center(child: Text('No instruments found'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final scheme = filtered[index];
                      return ListTile(
                        leading: _InstrumentIcon(scheme: scheme, size: 32),
                        title: Text(scheme.name),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await context.read<ColorSchemeProvider>().importScheme(scheme);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Imported ${scheme.name}')),
                              );
                            }
                          },
                          child: const Text('Import'),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _InstrumentIcon extends StatelessWidget {
  final InstrumentColorScheme scheme;
  final double size;
  const _InstrumentIcon({required this.scheme, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (scheme.emoji != null && scheme.emoji!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            scheme.emoji!,
            style: TextStyle(fontSize: size * 0.8),
          ),
        ),
      );
    }

    if (scheme.icon != null && scheme.icon!.isNotEmpty) {
      return Image.network(
        scheme.icon!,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(Icons.music_note, size: size),
      );
    }

    return Icon(Icons.music_note, size: size);
  }
}

// ── Name, Icon & Emoji dialog ───────────────────────────────────────────

class _NameIconEmojiDialog extends StatefulWidget {
  final String initialName;
  final String? initialIcon;
  final String? initialEmoji;
  const _NameIconEmojiDialog({
    required this.initialName,
    this.initialIcon,
    this.initialEmoji,
  });

  @override
  State<_NameIconEmojiDialog> createState() => _NameIconEmojiDialogState();
}

class _NameIconEmojiDialogState extends State<_NameIconEmojiDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _iconController =
      TextEditingController(text: widget.initialIcon);
  late String _selectedEmoji = widget.initialEmoji ?? '🎹';

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
      content: SizedBox(
        width: 320, // Explicit width for the dialog content
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const Text('Choose an Emoji:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 190, // Approx 3.5 rows
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MusicConstants.instrumentEmojis.map((emoji) {
                      final isSelected = _selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : null,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(emoji,
                                style: const TextStyle(fontSize: 24)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _iconController,
              decoration: const InputDecoration(
                labelText: 'Icon URL (fallback)',
                hintText: 'https://...',
                border: OutlineInputBorder(),
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
          onPressed: () => Navigator.pop(context, {
            'name': _nameController.text,
            'icon': _iconController.text,
            'emoji': _selectedEmoji,
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
  final VoidCallback onClone;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const _SchemeCard({
    required this.scheme,
    required this.isActive,
    required this.onActivate,
    required this.onClone,
    this.onEdit,
    this.onDelete,
    this.onShare,
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
              _InstrumentIcon(scheme: scheme, size: 32),
              const SizedBox(width: 12),
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
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit?.call();
                  if (v == 'clone') onClone();
                  if (v == 'delete') onDelete?.call();
                  if (v == 'share') onShare?.call();
                },
                itemBuilder: (_) => [
                  if (onEdit != null)
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'clone', child: Text('Clone')),
                  if (onShare != null)
                    const PopupMenuItem(
                        value: 'share', child: Text('Share (Submit to Library)')),
                  if (onDelete != null)
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
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
  late Set<String> _disabledKeys;
  late Map<String, String> _tuningOverrides;
  late String _name;
  late String? _icon;
  late String? _emoji;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _colors = Map.from(widget.scheme.colors);
    _octaveOverrides = Map.from(widget.scheme.octaveOverrides);
    _disabledKeys = Set.from(widget.scheme.disabledKeys);
    _tuningOverrides = Map.from(widget.scheme.tuningOverrides);
    _name = widget.scheme.name;
    _icon = widget.scheme.icon;
    _emoji = widget.scheme.emoji;
  }

  Future<void> _save() async {
    final updated = widget.scheme.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      disabledKeys: _disabledKeys,
      tuningOverrides: _tuningOverrides,
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
      builder: (_) => _NameIconEmojiDialog(
        initialName: _name,
        initialIcon: _icon ?? '',
        initialEmoji: _emoji ?? '🎹',
      ),
    );
    if (result != null) {
      final name = result['name'] ?? '';
      final icon = result['icon'] ?? '';
      final emoji = result['emoji'] ?? '';
      setState(() {
        _name = name.trim();
        _icon = icon.trim();
        _emoji = emoji.trim();
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

  Future<void> _tuneInstrument() async {
    // Collect all keys that can be tuned:
    // 1. All standard 12 chromatic notes (at a reasonable octave like 4)
    // 2. All octave overrides
    final chromaticBase = kNoteKeys
        .where((n) => !_disabledKeys.contains(n))
        .map((n) => '${n}4')
        .toList();
    final overrides = _octaveOverrides.keys.toList();

    // Use a Set to avoid duplicates and sort by pitch
    final allNotesToTune = <String>{...chromaticBase, ...overrides}.toList()
      ..sort((a, b) => MusicConstants.noteNameToMidi(a)
          .compareTo(MusicConstants.noteNameToMidi(b)));

    if (allNotesToTune.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No keys available to tune')),
      );
      return;
    }

    final currentScheme = widget.scheme.copyWith(
      name: _name,
      icon: _icon,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      tuningOverrides: _tuningOverrides,
    );

    final result = await showTuningWizard(
      context,
      notesToTune: allNotesToTune,
      initialOverrides: _tuningOverrides,
      colorProvider: (noteName) {
        // Parse noteName (e.g. "C4", "F#4")
        final match = RegExp(r'^([A-G])([#b])?(-?\d+)$').firstMatch(noteName);
        if (match == null) return Colors.grey;
        final step = match.group(1)!;
        final acc = match.group(2) ?? '';
        final octaveStr = match.group(3);
        final octave = octaveStr != null ? int.tryParse(octaveStr) : null;
        final alter = acc == '#' ? 1.0 : (acc == 'b' ? -1.0 : 0.0);

        return currentScheme.colorForNote(
          step,
          alter,
          octave: octave,
          context: context,
        );
      },
    );

    if (result != null) {
      setState(() {
        _tuningOverrides = result.tuningOverrides;
        _dirty = true;
      });
    }
  }

  Widget _buildChromaticRow(int index, InstrumentColorScheme currentScheme) {
    final note = kNoteKeys[index];
    final color = _colors[note] ?? currentScheme.colorForNote(note, 0, context: context);
    final isDisabled = _disabledKeys.contains(note);
    
    // Check if there is a tuning override for the base note (using octave 4 as reference)
    final tunedTo = _tuningOverrides['${note}4'];
    
    final textColor = color.computeLuminance() > 0.35
        ? Colors.black87
        : Colors.white;

    return Opacity(
      opacity: isDisabled ? 0.4 : 1.0,
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
          isDisabled
              ? 'Disabled for this instrument'
              : '#${color.toARGB32().toRadixString(16).toUpperCase().padLeft(8, '0').substring(2)}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: !isDisabled,
              onChanged: (val) {
                setState(() {
                  if (val) {
                    _disabledKeys.remove(note);
                  } else {
                    _disabledKeys.add(note);
                  }
                  _dirty = true;
                });
              },
            ),
            const Icon(Icons.color_lens_outlined),
          ],
        ),
        onTap: isDisabled
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
                    _dirty = true;
                  });
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
    );
    final overrideKeys = _octaveOverrides.keys.toList()..sort();
    final hasOverrides = overrideKeys.isNotEmpty;
    final n = overrideKeys.length;

    // Item layout:
    // 0: "My Keys" header
    // 1..n: Overrides
    // n+1: "Add Key" button
    // n+2: "Default Colors" header + first chromatic row
    // n+3..n+13: remaining chromatic rows
    final totalItems = 1 + n + 1 + 12;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            _InstrumentIcon(scheme: currentScheme, size: 28),
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
          // No divider after headers or the Add button
          if (i == 0 || i == n + 1) return const SizedBox.shrink();
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          // ── 1. My Keys section header ──────────────────────────────────
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

          // ── 2. Override rows ───────────────────────────────────────────
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

          // ── 3. Add key button ──────────────────────────────────────────
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

          // ── 4. Chromatic note rows ─────────────────────────────────────
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
