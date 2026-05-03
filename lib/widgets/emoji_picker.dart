import 'package:flutter/material.dart';
import '../music_kit/utils/music_constants.dart';

/// A reusable emoji picker widget with search.
class EmojiPicker extends StatefulWidget {
  final String selectedEmoji;
  final ValueChanged<String> onEmojiSelected;
  final double height;

  const EmojiPicker({
    super.key,
    required this.selectedEmoji,
    required this.onEmojiSelected,
    this.height = 200,
  });

  @override
  State<EmojiPicker> createState() => _EmojiPickerState();
}

class _EmojiPickerState extends State<EmojiPicker> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredEmojis = MusicConstants.allEmojis
        .where((e) => e.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search...',
            isDense: true,
            prefixIcon: Icon(Icons.search, size: 16),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: 8),
        Container(
          height: widget.height,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: filteredEmojis.map((emojiRecord) {
                  final emoji = emojiRecord.char;
                  final isSelected = widget.selectedEmoji == emoji;
                  return GestureDetector(
                    onTap: () => widget.onEmojiSelected(emoji),
                    child: Tooltip(
                      message: emojiRecord.name,
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
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
