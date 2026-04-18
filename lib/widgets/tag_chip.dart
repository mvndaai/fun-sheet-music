import 'package:flutter/material.dart';

/// A chip widget for displaying and selecting tags.
class TagChip extends StatelessWidget {
  final String tag;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TagChip({
    super.key,
    required this.tag,
    this.selected = false,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        label: Text(
          tag,
          style: TextStyle(
            color: selected
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        deleteIcon: onDelete != null
            ? Icon(
                Icons.close,
                size: 16,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              )
            : null,
        onDeleted: onDelete,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}

/// A dialog for editing tags.
class TagEditorDialog extends StatefulWidget {
  final List<String> currentTags;
  final List<String> availableTags;

  const TagEditorDialog({
    super.key,
    required this.currentTags,
    required this.availableTags,
  });

  @override
  State<TagEditorDialog> createState() => _TagEditorDialogState();
}

class _TagEditorDialogState extends State<TagEditorDialog> {
  late List<String> _tags;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.currentTags);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Tags'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Existing suggestions
            if (widget.availableTags.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Existing tags',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: widget.availableTags.map((t) {
                  final selected = _tags.contains(t);
                  return FilterChip(
                    label: Text(t),
                    selected: selected,
                    onSelected: (v) {
                      setState(() {
                        if (v) {
                          _tags.add(t);
                        } else {
                          _tags.remove(t);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 20),
            ],
            // Current tags
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _tags.map((t) {
                return TagChip(
                  tag: t,
                  onDelete: () => setState(() => _tags.remove(t)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            // Add new tag
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Add new tag...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _addTag(_controller.text),
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: _addTag,
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
          onPressed: () => Navigator.pop(context, _tags),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
