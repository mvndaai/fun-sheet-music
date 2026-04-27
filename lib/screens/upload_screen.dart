import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/song_provider.dart';
import '../widgets/tag_chip.dart';
import 'music_editor_screen.dart';

/// Upload screen: lets the user pick a local MusicXML file or enter a URL.
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final TextEditingController _urlController = TextEditingController();
  final List<String> _tags = [];
  bool _loading = false;
  String? _error;
  String? _pickedFileName;
  String? _pickedFileContent;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml', 'mxl', 'musicxml'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) {
      setState(() => _error = 'Could not read file content.');
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedFileContent = String.fromCharCodes(file.bytes!);
      _error = null;
    });
  }

  Future<void> _uploadFile() async {
    if (_pickedFileContent == null) {
      setState(() => _error = 'Please pick a file first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<SongProvider>();
    final song = await provider.addSongFromXml(
      _pickedFileContent!,
      tags: List.from(_tags),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (song != null) {
      _showSuccess(song.title);
    } else {
      setState(() => _error = provider.error ?? 'Unknown error');
    }
  }

  Future<void> _fetchUrl() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a URL.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final provider = context.read<SongProvider>();
    final song = await provider.addSongFromUrl(url, tags: List.from(_tags));
    if (!mounted) return;
    setState(() => _loading = false);
    if (song != null) {
      _showSuccess(song.title);
    } else {
      setState(() => _error = provider.error ?? 'Unknown error');
    }
  }

  void _showSuccess(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ "$title" added to library'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  void _addTag(String tag) {
    tag = tag.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SongProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Song'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.edit), text: 'Create'),
            Tab(icon: Icon(Icons.upload_file), text: 'Upload File'),
            Tab(icon: Icon(Icons.cloud_download), text: 'From URL'),
            Tab(icon: Icon(Icons.library_music), text: 'Libraries'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                const _CreateTab(),
                _FileUploadTab(
                  pickedFileName: _pickedFileName,
                  onPickFile: _pickFile,
                  onUpload: _uploadFile,
                  tags: _tags,
                  availableTags: provider.allTags,
                  onAddTag: _addTag,
                  onRemoveTag: (t) => setState(() => _tags.remove(t)),
                  error: _tab.index == 1 ? _error : null,
                ),
                _UrlTab(
                  controller: _urlController,
                  onFetch: _fetchUrl,
                  tags: _tags,
                  availableTags: provider.allTags,
                  onAddTag: _addTag,
                  onRemoveTag: (t) => setState(() => _tags.remove(t)),
                  error: _tab.index == 2 ? _error : null,
                ),
                _LibraryTab(
                  onSongAdded: (title) => _showSuccess(title),
                ),
              ],
            ),
    );
  }
}

class _CreateTab extends StatelessWidget {
  const _CreateTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Compose your own music from scratch.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MusicEditorScreen()),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Make My Own'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagsSection extends StatefulWidget {
  final List<String> tags;
  final List<String> availableTags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;

  const _TagsSection({
    required this.tags,
    required this.availableTags,
    required this.onAddTag,
    required this.onRemoveTag,
  });

  @override
  State<_TagsSection> createState() => _TagsSectionState();
}

class _TagsSectionState extends State<_TagsSection> {
  late final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...widget.tags.map((t) => TagChip(
                  tag: t,
                  onDelete: () => widget.onRemoveTag(t),
                )),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  hintText: 'Add tag…',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onSubmitted: (v) {
                  widget.onAddTag(v);
                  _controller.clear();
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                widget.onAddTag(_controller.text);
                _controller.clear();
              },
            ),
          ],
        ),
        if (widget.availableTags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            children: widget.availableTags
                .where((t) => !widget.tags.contains(t))
                .map((t) => ActionChip(
                      label: Text(t),
                      onPressed: () => widget.onAddTag(t),
                      avatar: const Icon(Icons.add, size: 14),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _FileUploadTab extends StatelessWidget {
  final String? pickedFileName;
  final VoidCallback onPickFile;
  final VoidCallback onUpload;
  final List<String> tags;
  final List<String> availableTags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final String? error;

  const _FileUploadTab({
    this.pickedFileName,
    required this.onPickFile,
    required this.onUpload,
    required this.tags,
    required this.availableTags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload a MusicXML file (.xml, .mxl, .musicxml) from your device.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.folder_open),
            label: Text(pickedFileName ?? 'Choose File'),
            onPressed: onPickFile,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (pickedFileName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    pickedFileName!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          _TagsSection(
            tags: tags,
            availableTags: availableTags,
            onAddTag: onAddTag,
            onRemoveTag: onRemoveTag,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.upload),
            label: const Text('Add to Library'),
            onPressed: pickedFileName != null ? onUpload : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlTab extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onFetch;
  final List<String> tags;
  final List<String> availableTags;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final String? error;

  const _UrlTab({
    required this.controller,
    required this.onFetch,
    required this.tags,
    required this.availableTags,
    required this.onAddTag,
    required this.onRemoveTag,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: true,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Download a MusicXML file from a URL.\n'
            'Supports public Google Cloud Storage URLs:\n'
            '  https://storage.googleapis.com/bucket/file.xml\n'
            '  gs://bucket/file.xml',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://storage.googleapis.com/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 24),
          _TagsSection(
            tags: tags,
            availableTags: availableTags,
            onAddTag: onAddTag,
            onRemoveTag: onRemoveTag,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.cloud_download),
            label: const Text('Download & Add'),
            onPressed: onFetch,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// A library entry that can come from assets or a URL.
class _LibraryEntry {
  final String title;
  final String library;
  final String? assetPath;
  final String? url;

  const _LibraryEntry({
    required this.title,
    required this.library,
    this.assetPath,
    this.url,
  });

  String get uniqueId => assetPath ?? url ?? title;
}

class _LibraryTab extends StatefulWidget {
  final void Function(String title) onSongAdded;

  const _LibraryTab({required this.onSongAdded});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab>
    with AutomaticKeepAliveClientMixin {
  final Set<String> _adding = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _addSong(_LibraryEntry entry) async {
    setState(() => _adding.add(entry.uniqueId));
    try {
      final provider = context.read<SongProvider>();
      String? xmlContent;
      
      if (entry.assetPath != null) {
        xmlContent = await rootBundle.loadString(entry.assetPath!);
      } else if (entry.url != null) {
        // addSongFromUrl handles the fetch internally
        final song = await provider.addSongFromUrl(entry.url!, library: entry.library);
        if (song != null) {
           widget.onSongAdded(song.title);
        }
        return;
      }

      if (xmlContent != null) {
        final song = await provider.addSongFromXml(xmlContent, library: entry.library);
        if (song != null) {
          widget.onSongAdded(song.title);
        }
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _adding.remove(entry.uniqueId));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<SongProvider>();

    // Build unified list from all selected libraries
    final List<_LibraryEntry> allAvailable = [];
    
    // 1. Add bundled songs if selected
    for (final libName in provider.selectedLibraries) {
      if (SongProvider.bundledSongs.containsKey(libName)) {
        for (final songData in SongProvider.bundledSongs[libName]!) {
          allAvailable.add(_LibraryEntry(
            title: songData['title']!,
            library: libName,
            assetPath: songData['asset'],
          ));
        }
      }
    }

    // 2. Filter by search
    final filtered = _searchQuery.isEmpty
        ? allAvailable
        : allAvailable
            .where((e) => e.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList()
      ..sort((a, b) => a.title.compareTo(b.title));

    return Column(
      children: [
        // Library Selectors
        Container(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: provider.currentLibraries.map((lib) {
                  final isSelected = provider.selectedLibraries.contains(lib);
                  return FilterChip(
                    label: Text(lib),
                    selected: isSelected,
                    onSelected: (val) => provider.setLibrarySelected(lib, val),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search all enabled libraries…',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Text(
                '${filtered.length} songs available',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),

        // Unified Results List
        Expanded(
          child: allAvailable.isEmpty
              ? const Center(child: Text('No libraries enabled'))
              : ListView.builder(
                  primary: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isAdding = _adding.contains(entry.uniqueId);
                    
                    // Check if song is already in local provider
                    final bool isAlreadyAdded = provider.songs.any((s) {
                      String normalize(String t) => t
                          .toLowerCase()
                          .replaceAll(RegExp(r'[^\w\s]'), '')
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim();
                      return normalize(s.title) == normalize(entry.title) &&
                          s.library == entry.library;
                    });

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: const Icon(Icons.music_note),
                      ),
                      title: Text(entry.title),
                      subtitle: Text(entry.library),
                      trailing: SizedBox(
                        width: 48,
                        child: Center(
                          child: isAdding
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : isAlreadyAdded
                                  ? const Icon(Icons.check_circle,
                                      color: Colors.green)
                                  : IconButton(
                                      icon: const Icon(Icons.add_circle_outline),
                                      onPressed: () => _addSong(entry),
                                    ),
                        ),
                      ),
                      onTap: isAdding || isAlreadyAdded
                          ? null
                          : () => _addSong(entry),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
