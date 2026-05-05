import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../main.dart' show showToast;
import '../widgets/legend_circle.dart';
import '../widgets/legend_piano.dart';
import '../widgets/name_icon_emoji_dialog.dart';
import 'instrument_setup_screen.dart';

/// Screen for managing instrument profiles.
class InstrumentsScreen extends StatelessWidget {
  final bool isEmbedded;
  const InstrumentsScreen({super.key, this.isEmbedded = false});

  @override
  Widget build(BuildContext context) {
    final content = Consumer<InstrumentProvider>(
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
              onConfigure: () => openSetup(context, scheme, SetupMode.visuals),
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
    );

    if (isEmbedded) return content;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Instrument',
            onPressed: () => createNew(context),
          ),
          IconButton(
            icon: const Icon(Icons.library_music),
            tooltip: 'Search Library',
            onPressed: () => openLibrary(context),
          ),
        ],
      ),
      body: content,
    );
  }

  static Future<void> openLibrary(BuildContext context) async {
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
      showToast('Could not open GitHub', isError: true);
    }
  }

  static Future<void> createNew(BuildContext context) async {
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
      await openSetup(context, scheme, SetupMode.visuals);
    }
  }

  static Future<void> openSetup(
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

  static Future<Map<String, String>?> _promptNameIconEmoji(
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
        title: 'Instrument info',
        nameHint: 'e.g. My Blue Xylophone',
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Instrument Library', style: Theme.of(context).textTheme.titleLarge),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
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
                              showToast('Imported ${scheme.name}');
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
