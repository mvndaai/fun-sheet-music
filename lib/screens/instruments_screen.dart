import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/models/legend_style.dart';
import '../widgets/legend_circle.dart';
import '../widgets/legend_piano.dart';
import 'instrument_setup_screen.dart';

/// Screen for managing instrument profiles.
class InstrumentsScreen extends StatelessWidget {
  const InstrumentsScreen({super.key});

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
      body: Consumer<InstrumentProvider>(
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
                onConfigure: () => _openSetup(context, scheme, SetupMode.visuals),
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
    final provider = context.read<InstrumentProvider>();
    final library = await provider.loadLibrary();
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _LibrarySearchSheet(library: library),
    );
  }

  Future<void> _shareScheme(BuildContext context, InstrumentProfile scheme) async {
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
    final provider = context.read<InstrumentProvider>();
    final result = await _promptNameIconEmoji(context, initialName: '', initialIcon: null, initialEmoji: null);
    if (result == null) return;
    final name = result['name'] ?? '';
    final icon = result['icon'] ?? '';
    final emoji = result['emoji'] ?? '';
    final scheme = await provider.createCustom(
      name: name.trim(),
      icon: icon.isNotEmpty ? icon.trim() : null,
      emoji: emoji.isNotEmpty ? emoji.trim() : null,
    );
    if (context.mounted) {
      await _openSetup(context, scheme, SetupMode.visuals);
    }
  }

  Future<void> _openSetup(
    BuildContext context,
    InstrumentProfile scheme,
    SetupMode mode,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstrumentSetupScreen(scheme: scheme, initialMode: mode),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    InstrumentProfile scheme,
    InstrumentProvider provider,
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
    required String? initialIcon,
    required String? initialEmoji,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => NameIconEmojiDialog(
        initialName: initialName,
        initialIcon: initialIcon,
        initialEmoji: initialEmoji,
      ),
    );
  }
}

class _LibrarySearchSheet extends StatefulWidget {
  final List<InstrumentProfile> library;
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
                        leading: InstrumentIcon(scheme: scheme, size: 32),
                        title: Text(scheme.name),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await context.read<InstrumentProvider>().importScheme(scheme);
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

class InstrumentIcon extends StatelessWidget {
  final InstrumentProfile scheme;
  final double size;
  const InstrumentIcon({super.key, required this.scheme, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (scheme.emoji != null && scheme.emoji!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              scheme.emoji!,
              style: TextStyle(fontSize: size),
            ),
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

enum _IconType { emoji, character, url }

class NameIconEmojiDialog extends StatefulWidget {
  final String initialName;
  final String? initialIcon;
  final String? initialEmoji;
  const NameIconEmojiDialog({
    super.key,
    required this.initialName,
    this.initialIcon,
    this.initialEmoji,
  });

  @override
  State<NameIconEmojiDialog> createState() => _NameIconEmojiDialogState();
}

class _NameIconEmojiDialogState extends State<NameIconEmojiDialog> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName);
  late final TextEditingController _iconController =
      TextEditingController(text: widget.initialIcon);
  late final TextEditingController _characterController =
      TextEditingController(text: widget.initialEmoji);
  late String _selectedEmoji = MusicConstants.instrumentEmojis.contains(widget.initialEmoji)
      ? widget.initialEmoji!
      : '🎹';
  late _IconType _iconType;

  @override
  void initState() {
    super.initState();
    if (widget.initialIcon != null && widget.initialIcon!.isNotEmpty) {
      _iconType = _IconType.url;
    } else if (widget.initialEmoji != null && widget.initialEmoji!.isNotEmpty) {
      if (MusicConstants.instrumentEmojis.contains(widget.initialEmoji)) {
        _iconType = _IconType.emoji;
      } else {
        _iconType = _IconType.character;
      }
    } else {
      _iconType = _IconType.emoji;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _characterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Instrument info'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
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
              DropdownButtonFormField<_IconType>(
                value: _iconType,
                decoration: const InputDecoration(
                  labelText: 'Icon Type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: _IconType.emoji, child: Text('Select Emoji')),
                  DropdownMenuItem(value: _IconType.character, child: Text('Input Character')),
                  DropdownMenuItem(value: _IconType.url, child: Text('Image URL')),
                ],
                onChanged: (v) => setState(() => _iconType = v!),
              ),
              const SizedBox(height: 16),
              if (_iconType == _IconType.emoji) ...[
                const Text('Choose an Emoji:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 190,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      primary: true,
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
              ] else if (_iconType == _IconType.character) ...[
                TextField(
                  controller: _characterController,
                  decoration: const InputDecoration(
                    labelText: 'Character',
                    hintText: 'A, B, C...',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 2,
                ),
              ] else if (_iconType == _IconType.url) ...[
                TextField(
                  controller: _iconController,
                  decoration: const InputDecoration(
                    labelText: 'Icon URL',
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            String emoji = '';
            String icon = '';
            if (_iconType == _IconType.emoji) {
              emoji = _selectedEmoji;
            } else if (_iconType == _IconType.character) {
              emoji = _characterController.text;
            } else if (_iconType == _IconType.url) {
              icon = _iconController.text;
            }
            Navigator.pop(context, {
              'name': _nameController.text,
              'icon': icon,
              'emoji': emoji,
            });
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

// ── Scheme card ───────────────────────────────────────────────────────────

class _SchemeCard extends StatelessWidget {
  final InstrumentProfile scheme;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClone;
  final VoidCallback onConfigure;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;

  const _SchemeCard({
    required this.scheme,
    required this.isActive,
    required this.onActivate,
    required this.onClone,
    required this.onConfigure,
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
              InstrumentIcon(scheme: scheme, size: 32),
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
                  if (v == 'configure') onConfigure();
                  if (v == 'clone') onClone();
                  if (v == 'delete') onDelete?.call();
                  if (v == 'share') onShare?.call();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'configure', child: Text('Configure')),
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
  final InstrumentProfile scheme;
  const _ColorSwatchRow({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstrumentProvider>();
    final showSolfege = provider.showSolfege;
    final showLabels = provider.showNoteLabels;
    final style = provider.legendStyle;

    if (style == LegendStyle.piano) {
      return LegendPiano(
        instrument: scheme,
        showSolfege: showSolfege,
        showLabels: showLabels,
        keyWidth: 20,
        keyHeight: 32,
      );
    }

    // List of note names that have explicit colors and are not hidden
    final coloredNotes = kNoteKeys.where((n) => 
      scheme.colors.containsKey(n) && !scheme.hiddenKeys.contains(n)
    );
    
    // For overrides, we also check if the base chromatic note is disabled.
    final overrideKeys = scheme.octaveOverrides.keys.where((key) {
      final match = RegExp(r'^([A-G][#b]?)').firstMatch(key);
      if (match == null) return true;
      final baseNote = match.group(1)!;
      return !scheme.hiddenKeys.contains(baseNote);
    }).toList()..sort();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        ...coloredNotes.map((note) => LegendCircle(
              label: note,
              color: scheme.colors[note]!,
              showSolfege: showSolfege,
              showLabels: showLabels,
              size: 20,
            )),
        ...overrideKeys.map((key) => LegendCircle(
              label: key,
              color: scheme.octaveOverrides[key]!,
              showSolfege: showSolfege,
              showLabels: showLabels,
              size: 20,
            )),
      ],
    );
  }
}
