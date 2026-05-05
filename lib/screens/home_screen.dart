import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/song_provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/instrument_profile.dart';
import '../widgets/tag_chip.dart';
import '../widgets/kid_safe_ad_banner.dart';
import '../config/app_links.dart';
import '../main.dart' show showToast;
import 'sheet_music_screen.dart';
import 'upload_screen.dart';
import 'share_screen.dart';
import 'music_editor_screen.dart';
import '../widgets/music_settings_sheet.dart';
import '../widgets/batch_print_dialog.dart';
import '../music_kit/utils/music_xml_generator.dart';
import '../platform/platform.dart';

enum EditMode { normal, reorder }

/// Home screen showing the song library with tag-based filtering.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  EditMode _editMode = EditMode.normal;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      context.read<SongProvider>().setSearchQuery(_searchController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<SongProvider>().loadSongs();
      if (mounted) {
        _handleQueryParameters();
        _focusNode.requestFocus();
      }
    });
  }

  void _handleQueryParameters() async {
    final uri = Uri.base;
    
    // Handle instrument parameter
    final instrumentParam = uri.queryParameters['instrument'];
    if (instrumentParam != null && instrumentParam.isNotEmpty) {
      final instrumentProvider = context.read<InstrumentProvider>();
      
      // Try to find by ID first, then by name (case-insensitive)
      final instrument = instrumentProvider.allSchemes.firstWhere(
        (i) => i.id == instrumentParam || i.name.toLowerCase() == instrumentParam.toLowerCase(),
        orElse: () => InstrumentProfile.black, // Use black as a sentinel value
      );
      
      if (instrument.id != InstrumentProfile.black.id) {
        await instrumentProvider.setActive(instrument.id);
      }
    }
    
    // Check if widget is still mounted after async gap
    if (!mounted) return;
    
    // Get the song parameter from the query string
    final songId = uri.queryParameters['song'];
    if (songId == null || songId.isEmpty) return;

    final provider = context.read<SongProvider>();
    // Wait for songs to be loaded if they haven't been
    if (provider.songs.isEmpty) {
      await provider.loadSongs();
    }

    // Try to find by ID first, then by title (case-insensitive)
    var song = provider.songs.firstWhere(
      (s) => s.id == songId || s.title.toLowerCase() == songId.toLowerCase(),
      orElse: () => Song(id: '', title: '', measures: [], createdAt: DateTime.now()),
    );

    // If not found in library, check bundled songs
    if (song.id.isEmpty) {
      for (final entry in provider.bundledSongsMetadata.entries) {
        final libraryName = entry.key;
        for (final metadata in entry.value) {
          if (metadata.title.toLowerCase() == songId.toLowerCase()) {
            try {
              final assetPath = metadata.localPath;
              if (assetPath == null) continue; // Skip remote songs for auto-import

              final xmlContent = await rootBundle.loadString(assetPath);
              
              final imported = await provider.addSongFromXml(
                xmlContent,
                tags: metadata.tags,
                library: libraryName,
                localPath: assetPath,
              );
              if (imported != null) {
                song = imported;
              }
              break;
            } catch (e) {
              debugPrint('Failed to auto-import song: $e');
            }
          }
        }
        if (song.id.isNotEmpty) break;
      }
    }

    if (song.id.isNotEmpty && mounted) {
      _openSheet(context, song);
    }
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

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () =>
            BatchPrintDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.keyP, meta: true): () =>
            BatchPrintDialog.show(context),
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
          title: const Text('🎵 My Songs'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Song',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UploadScreen()),
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
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Get the app / share',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShareScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () => MusicSettingsSheet.show(
                context,
                showPrint: true,
                onPrint: () => BatchPrintDialog.show(context),
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
                // Search and Filter bar
                _SearchAndFilterBar(
                  provider: provider,
                  searchController: _searchController,
                ),
                // Edit mode banner
                if (_editMode == EditMode.reorder)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      children: [
                        Icon(
                          Icons.swap_vert,
                          size: 20,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Drag songs to reorder',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(() => _editMode = EditMode.normal),
                          icon: Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                          label: Text(
                            'Done',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Song list
                Expanded(
                  child: provider.filteredSongs.isEmpty
                      ? _EmptyState(
                          hasFilter: provider.selectedTags.isNotEmpty || provider.searchQuery.isNotEmpty,
                        )
                      : _editMode == EditMode.reorder
                          ? ReorderableListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: provider.filteredSongs.length,
                              onReorder: (oldIndex, newIndex) {
                                provider.reorderSongs(oldIndex, newIndex);
                              },
                              itemBuilder: (context, index) {
                                final song = provider.filteredSongs[index];
                                final showLibrary = provider.filteredSongs.map((s) => s.library).toSet().length > 1;
                                return Padding(
                                  key: ValueKey(song.id),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SongCard(
                                    song: song,
                                    showLibrary: showLibrary,
                                    editMode: _editMode,
                                    onEnterReorderMode: () => setState(() => _editMode = EditMode.reorder),
                                  ),
                                );
                              },
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: provider.filteredSongs.length,
                              itemBuilder: (context, index) {
                                final song = provider.filteredSongs[index];
                                final showLibrary = provider.filteredSongs.map((s) => s.library).toSet().length > 1;
                                return Padding(
                                  key: ValueKey(song.id),
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _SongCard(
                                    song: song,
                                    showLibrary: showLibrary,
                                    editMode: _editMode,
                                    onEnterReorderMode: () => setState(() => _editMode = EditMode.reorder),
                                  ),
                                );
                              },
                            ),
                ),
                // Ad Banner
                Consumer<InstrumentProvider>(
                  builder: (context, instrProvider, _) {
                    if (kIsWeb || instrProvider.isAdFree) return const SizedBox.shrink();
                    return const KidSafeAdBanner();
                  },
                ),
              ],
            );
          },
        ),
      ),
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
  final bool showLibrary;
  final EditMode editMode;
  final VoidCallback onEnterReorderMode;
  
  const _SongCard({
    required this.song,
    this.showLibrary = false,
    this.editMode = EditMode.normal,
    required this.onEnterReorderMode,
  });

  String _getInitials(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<SongProvider>();

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: song.icon.isNotEmpty
              ? Text(
                  song.icon,
                  style: const TextStyle(
                    fontSize: 20,
                    fontFamilyFallback: [
                      'Apple Color Emoji',
                      'Segoe UI Emoji',
                      'Noto Color Emoji',
                      'Android Emoji',
                    ],
                  ),
                )
              : Text(
                  _getInitials(song.title),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (song.composer.isNotEmpty || song.arranger.isNotEmpty || (showLibrary && song.library != SongProvider.builtinLibraryName))
              Text(
                [
                  if (song.composer.isNotEmpty) song.composer,
                  if (song.arranger.isNotEmpty) song.arranger,
                  if (showLibrary && song.library != SongProvider.builtinLibraryName) song.library,
                ].join(' • '),
                style: const TextStyle(fontSize: 12),
              ),
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
        trailing: editMode == EditMode.reorder
            ? null
            : PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'copy_link') {
              _copySongLink(context, song);
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
            const PopupMenuItem(value: 'copy_link', child: Text('Copy Link')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (song.library == 'Created')
              const PopupMenuItem(value: 'share', child: Text('Share (GitHub)')),
            const PopupMenuItem(value: 'tags', child: Text('Edit Tags')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
        onTap: () => _openSheet(context, song),
        onLongPress: editMode == EditMode.normal ? onEnterReorderMode : null,
      ),
    );
  }

  void _copySongLink(BuildContext context, Song song) {
    String baseUrl;
    if (kIsWeb) {
      // Use the current page URL but strip any existing query parameters
      baseUrl = Uri.base.replace(queryParameters: {}).toString();
      // Remove trailing question mark if present (happens if original URL had one)
      if (baseUrl.endsWith('?')) {
        baseUrl = baseUrl.substring(0, baseUrl.length - 1);
      }
    } else {
      baseUrl = AppLinks.webUrl;
    }

    // Ensure we don't create double slashes and handle existing parameters
    final String separator = baseUrl.contains('?') ? '&' : '?';
    final songUrl = '$baseUrl$separator' 'song=${Uri.encodeComponent(song.title)}';

    Clipboard.setData(ClipboardData(text: songUrl));
    showToast('Link to "${song.title}" copied!');
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
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
    saveFile(title: title, content: xml);
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
