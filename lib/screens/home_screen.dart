import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../models/song.dart';
import '../widgets/tag_chip.dart';
import 'sheet_music_screen.dart';
import 'upload_screen.dart';

/// Home screen showing the song library with tag-based filtering.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().loadSongs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 Music Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add song',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UploadScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<SongProvider>(
        builder: (context, provider, _) {
          if (provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  Text(provider.error!),
                  TextButton(
                    onPressed: () => provider.loadSongs(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Tag filter bar
              if (provider.allTags.isNotEmpty) _TagFilterBar(provider: provider),
              // Song list
              Expanded(
                child: provider.filteredSongs.isEmpty
                    ? _EmptyState(
                        hasFilter: provider.selectedTag.isNotEmpty,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: provider.filteredSongs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final song = provider.filteredSongs[index];
                          return _SongCard(song: song);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadScreen()),
        ),
        icon: const Icon(Icons.upload_file),
        label: const Text('Add Song'),
      ),
    );
  }
}

class _TagFilterBar extends StatelessWidget {
  final SongProvider provider;
  const _TagFilterBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          TagChip(
            tag: 'All',
            selected: provider.selectedTag.isEmpty,
            onTap: () => provider.selectTag(''),
          ),
          const SizedBox(width: 6),
          ...provider.allTags.map((tag) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TagChip(
                  tag: tag,
                  selected: provider.selectedTag == tag,
                  onTap: () => provider.selectTag(
                    provider.selectedTag == tag ? '' : tag,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  const _SongCard({required this.song});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SongProvider>();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: const Icon(Icons.music_note),
        ),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (song.composer.isNotEmpty)
              Text(song.composer, style: const TextStyle(fontSize: 12)),
            if (song.tags.isNotEmpty)
              Wrap(
                spacing: 4,
                children: song.tags
                    .map((t) => TagChip(tag: t, onTap: () => provider.selectTag(t)))
                    .toList(),
              ),
          ],
        ),
        isThreeLine: song.tags.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'view') {
              _openSheet(context, song);
            } else if (value == 'tags') {
              _editTags(context, song);
            } else if (value == 'delete') {
              _confirmDelete(context, song);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('View Sheet Music')),
            const PopupMenuItem(value: 'tags', child: Text('Edit Tags')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openSheet(context, song),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, Song song) async {
    final provider = context.read<SongProvider>();
    final fullSong = await provider.loadFullSong(song.id);
    if (fullSong != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SheetMusicScreen(song: fullSong),
        ),
      );
    }
  }

  Future<void> _editTags(BuildContext context, Song song) async {
    final provider = context.read<SongProvider>();
    final result = await showDialog<List<String>>(
      context: context,
      builder: (_) => TagEditorDialog(
        currentTags: song.tags,
        availableTags: provider.allTags,
      ),
    );
    if (result != null) {
      await provider.updateTags(song.id, result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Song song) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Song'),
        content: Text('Are you sure you want to delete "${song.title}"?'),
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
    if (confirm == true && context.mounted) {
      await context.read<SongProvider>().deleteSong(song.id);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  const _EmptyState({this.hasFilter = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hasFilter ? Icons.filter_list_off : Icons.music_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            hasFilter
                ? 'No songs with this tag'
                : 'No songs yet.\nTap + to add your first song!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.read<SongProvider>().selectTag(''),
              child: const Text('Clear filter'),
            ),
          ],
        ],
      ),
    );
  }
}
