import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/keyboard_profile.dart';
import '../providers/keyboard_provider.dart';
import '../widgets/name_icon_emoji_dialog.dart';
import 'keyboard_setup_screen.dart';

class KeyboardsScreen extends StatelessWidget {
  const KeyboardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keyboards & Sounds'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Keyboard',
            onPressed: () => _createNew(context),
          ),
        ],
      ),
      body: Consumer<KeyboardProvider>(
        builder: (context, provider, _) {
          final profiles = provider.allProfiles;
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return _KeyboardCard(
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
    final provider = context.read<KeyboardProvider>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const NameIconEmojiDialog(
        initialName: '',
        initialIcon: null,
        initialEmoji: null,
        title: 'New keyboard',
        nameHint: 'e.g. My Custom Keyboard',
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

  Future<void> _openSetup(BuildContext context, KeyboardProfile profile) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => KeyboardSetupScreen(profile: profile)),
    );
  }

  Future<void> _confirmDelete(BuildContext context, KeyboardProfile profile, KeyboardProvider provider) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete keyboard'),
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

class _KeyboardCard extends StatelessWidget {
  final KeyboardProfile profile;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onClone;
  final VoidCallback onConfigure;
  final VoidCallback? onDelete;

  const _KeyboardCard({
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
            // Using InstrumentIcon but passing a temporary profile-like object
            Text(profile.emoji ?? '⌨️', style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(profile.name, style: TextStyle(fontWeight: FontWeight.bold, color: isActive ? Theme.of(context).colorScheme.primary : null)),
          ],
        ),
        subtitle: Text('${profile.keyboardOverrides.length} keys, ${profile.noteSounds.length} sounds'),
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
