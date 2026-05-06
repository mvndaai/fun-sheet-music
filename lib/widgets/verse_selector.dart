import 'package:flutter/material.dart';

class VerseSelector extends StatelessWidget {
  final int currentVerse;
  final int totalVerses;
  final ValueChanged<int> onChanged;

  const VerseSelector({
    super.key,
    required this.currentVerse,
    required this.totalVerses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.remove),
            onPressed: currentVerse > 1 ? () => onChanged(currentVerse - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Verse $currentVerse / ${totalVerses > 0 ? totalVerses : 1}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            iconSize: 20,
            icon: const Icon(Icons.add),
            onPressed: currentVerse < (totalVerses > 1 ? totalVerses : 1) || totalVerses <= 1
                ? () => onChanged(currentVerse + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
