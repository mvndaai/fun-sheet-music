import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/sound_profile.dart';
import '../providers/sound_provider.dart';
import '../widgets/name_icon_emoji_dialog.dart';
import 'sound_setup_screen.dart';

class SoundsScreen extends StatelessWidget {
  const SoundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Sets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Sound Set',
            onPressed: () => _createNew(context),
          ),
        ],
      ),
      body: Consumer<SoundProvider>(
        builder: (context, provider, _) {
          final profiles = provider.allProfiles;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _SoundCard(
                profile: profile,
                isActive: provider.activeId == profile.id,
                onActivate: () => provider.setActive(profile.id),
                onClone: () => provider.cloneProfile(profile),
                onConfigure: () => _openSetup(context, profile),
                onDelete: profile.isBuiltIn ? null : () => _confirmDelete(context, profile, provider),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createNew(BuildContext context) async {
    final provider = context.read<SoundProvider>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const NameIconEmojiDialog(
        initialName: '',
        initialIcon: null,
        initialEmoji: null,
        title: 'New sound set',
        nameHint: 'e.g. My Custom Sounds',
      ),
    );
    if (result == null) return;
    final name = result['name'] ?? '';
    final icon = result['icon'] ?? '';
    final emoji = result['emoji'] ?? '';
    final profile = await provider.createCustom(
      name: name.trim(),
      icon: icon.isNotEmpty ? icon.trim() : null,
      emoji: emoji.isNotEmpty ? emoji.trim() : null,
    );
    if (context.mounted) {
      await _openSetup(context, profile);
    }
  }

  Future<void> _openSetup(BuildContext context, SoundProfile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoundSetupScreen(profile: profile)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SoundProfile profile, SoundProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete sound set'),
        content: Text('Delete "${profile.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await provider.deleteCustom(profile.id);
  }
}

class _SoundCard extends StatelessWidget {
  final SoundProfile profile;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClone;
  final VoidCallback onConfigure;
  final VoidCallback? onDelete;

  const _SoundCard({
    required this.profile,
    required this.isActive,
    required this.onActivate,
    required this.onClone,
    required this.onConfigure,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onActivate,
        leading: Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Row(
          children: [
            Text(profile.emoji ?? '🔊', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(profile.name, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Theme.of(context).colorScheme.primary : null)),
          ],
        ),
        subtitle: Text('${profile.noteSounds.length} custom sounds'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) {
            if (v == 'configure') onConfigure();
            if (v == 'clone') onClone();
            if (v == 'delete') onDelete?.call();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'configure', child: Text('Configure')),
            const PopupMenuItem(value: 'clone', child: Text('Clone')),
            if (onDelete != null) const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
