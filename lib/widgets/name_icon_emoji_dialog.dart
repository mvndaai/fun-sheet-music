import 'package:flutter/material.dart';
import '../music_kit/utils/music_constants.dart';
import 'emoji_picker.dart';

enum _IconType { emoji, character, url }

/// A reusable dialog for editing name, icon, and emoji.
/// Used by both instruments and keyboards.
class NameIconEmojiDialog extends StatefulWidget {
  final String initialName;
  final String? initialIcon;
  final String? initialEmoji;
  final String title;
  final String nameHint;

  const NameIconEmojiDialog({
    super.key,
    required this.initialName,
    this.initialIcon,
    this.initialEmoji,
    this.title = 'Info',
    this.nameHint = 'e.g. My Custom Item',
  });

  @override
  State<NameIconEmojiDialog> createState() => _NameIconEmojiDialogState();
}

class _NameIconEmojiDialogState extends State<NameIconEmojiDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _iconController;
  late final TextEditingController _characterController;
  late String _selectedEmoji;
  late _IconType _iconType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _iconController = TextEditingController(text: widget.initialIcon);
    _characterController = TextEditingController(text: widget.initialEmoji);
    _selectedEmoji = MusicConstants.allEmojis.any((e) => e.char == widget.initialEmoji)
        ? widget.initialEmoji!
        : '🎹';

    // Determine initial icon type
    if (widget.initialIcon != null && widget.initialIcon!.isNotEmpty) {
      _iconType = _IconType.url;
    } else if (widget.initialEmoji != null && widget.initialEmoji!.isNotEmpty) {
      if (MusicConstants.allEmojis.any((e) => e.char == widget.initialEmoji)) {
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
      title: Text(widget.title),
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
                decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: widget.nameHint,
                  border: const OutlineInputBorder(),
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
                const Text('Emoji', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                EmojiPicker(
                  selectedEmoji: _selectedEmoji,
                  onEmojiSelected: (emoji) => setState(() => _selectedEmoji = emoji),
                  height: 190,
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
