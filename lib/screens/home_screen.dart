import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/song_provider.dart';
import '../music_kit/models/song.dart';
import '../widgets/tag_chip.dart';
import 'sheet_music_screen.dart';
import 'upload_screen.dart';
import 'share_screen.dart';
import 'music_editor_screen.dart';
import '../music_kit/utils/music_xml_generator.dart';

/// Home screen showing the song library with tag-based filtering.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<SongProvider>().setSearchQuery(_searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SongProvider>().loadSongs();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎵 My Songs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Get the app / share',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ShareScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Report issue / feedback',
            onPressed: () async {
              final uri = Uri.parse('https://github.com/mvndaai/flutter-music/issues');
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
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
              // Search and Filter bar
              _SearchAndFilterBar(
                provider: provider,
                searchController: _searchController,
              ),
              // Song list
              Expanded(
                child: provider.filteredSongs.isEmpty
                    ? _EmptyState(
                        hasFilter: provider.selectedTags.isNotEmpty || provider.searchQuery.isNotEmpty,
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

class _SearchAndFilterBar extends StatelessWidget {
  final SongProvider provider;
  final TextEditingController searchController;

  const _SearchAndFilterBar({
    required this.provider,
    required this.searchController,
  });

  @override
  Widget build(BuildContext context) {
    final allTags = provider.allTags;
    final selectedTags = provider.selectedTags;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search songs...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => searchController.clear(),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          PopupMenuButton<String>(
            tooltip: 'Filter by tags',
            onSelected: (tag) {
              if (tag == 'clear') {
                provider.clearTags();
              } else {
                provider.toggleTag(tag);
              }
            },
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  value: 'clear',
                  enabled: selectedTags.isNotEmpty,
                  child: const Text('Clear All Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const PopupMenuDivider(),
                ...allTags.map((tag) {
                  final isSelected = selectedTags.contains(tag);
                  return CheckedPopupMenuItem(
                    value: tag,
                    checked: isSelected,
                    child: Text(tag),
                  );
                }),
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Badge(
                label: Text(selectedTags.length.toString()),
                isLabelVisible: selectedTags.isNotEmpty,
                child: const Icon(Icons.filter_list),
              ),
            ),
          ),
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
            Text('${song.composer} • ${song.library}', style: const TextStyle(fontSize: 12)),
            if (song.tags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 4,
                  children: song.tags
                      .map((t) => TagChip(
                            tag: t,
                            onTap: () => provider.toggleTag(t),
                            selected: provider.selectedTags.contains(t),
                          ))
                      .toList(),
                ),
              ),
          ],
        ),
        isThreeLine: song.tags.isNotEmpty,
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'view') {
              _openSheet(context, song);
            } else if (value == 'edit') {
              _editSong(context, song);
            } else if (value == 'share') {
              _shareSong(context, song);
            } else if (value == 'tags') {
              _editTags(context, song);
            } else if (value == 'delete') {
              _confirmDelete(context, song);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('View Sheet Music')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (song.library == 'Created')
              const PopupMenuItem(value: 'share', child: Text('Share (GitHub)')),
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

  Future<void> _editSong(BuildContext context, Song song) async {
    final provider = context.read<SongProvider>();
    final fullSong = await provider.loadFullSong(song.id);
    if (fullSong != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MusicEditorScreen(initialSong: fullSong),
        ),
      );
    }
  }

  Future<void> _shareSong(BuildContext context, Song song) async {
    final provider = context.read<SongProvider>();
    final fullSong = await provider.loadFullSong(song.id);
    if (fullSong == null) return;

    if (!context.mounted) return;

    final xml = MusicXmlGenerator.generate(fullSong);
    final issueTitle = 'New Song: ${fullSong.title}';
    final bodyWithXml = 'Please add this song to the library.\n\n```xml\n$xml\n```';

    final fullUrl = Uri.parse(
      'https://github.com/mvndaai/flutter-music/issues/new'
      '?title=${Uri.encodeComponent(issueTitle)}'
      '&body=${Uri.encodeComponent(bodyWithXml)}'
      '&labels=new-song',
    );

    // If the URL is short enough, just open it directly
    if (fullUrl.toString().length < 6000) {
      if (await canLaunchUrl(fullUrl)) {
        await launchUrl(fullUrl);
        return;
      }
    }

    // Otherwise, show the step-by-step guide for long songs
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Song (Large File)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('This song is too large to share via a direct link. Please follow these steps:'),
            SizedBox(height: 16),
            Text('1. Download the MusicXML file to your device.'),
            Text('2. A new GitHub issue page will open.'),
            Text('3. Drag and drop the downloaded file into the GitHub issue comment box before saving.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // 1. Download the file
              _downloadXml(fullSong.title, xml);
              
              // 2. Open GitHub issue page (without the body XML)
              final shortUrl = Uri.parse(
                'https://github.com/mvndaai/flutter-music/issues/new'
                '?title=${Uri.encodeComponent(issueTitle)}'
                '&body=${Uri.encodeComponent('Please add the attached MusicXML file to the library.')}'
                '&labels=new-song,new-music',
              );
              if (await canLaunchUrl(shortUrl)) {
                await launchUrl(shortUrl);
              }
            },
            child: const Text('Download & Open GitHub'),
          ),
        ],
      ),
    );
  }

  void _downloadXml(String title, String xml) {
    if (kIsWeb) {
      final bytes = utf8.encode(xml);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', '${title.replaceAll(' ', '_')}.musicxml')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      // For mobile/desktop, we would ideally use share_plus, but for now
      // we can inform the user or use path_provider to save to documents.
      // Since the user is likely on web (given the GitHub URL error),
      // we focus on that.
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
                ? 'No songs matching the current filters'
                : 'No songs yet.\nTap + to add your first song!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          if (hasFilter) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                context.read<SongProvider>().clearTags();
                context.read<SongProvider>().setSearchQuery('');
              },
              child: const Text('Clear filters'),
            ),
          ],
        ],
      ),
    );
  }
}
