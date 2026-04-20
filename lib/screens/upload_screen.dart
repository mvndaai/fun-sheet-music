import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../widgets/tag_chip.dart';

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
    _tab = TabController(length: 3, vsync: this);
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
            Tab(icon: Icon(Icons.upload_file), text: 'Upload File'),
            Tab(icon: Icon(Icons.cloud_download), text: 'From URL'),
            Tab(icon: Icon(Icons.library_music), text: 'Library'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _FileUploadTab(
                  pickedFileName: _pickedFileName,
                  onPickFile: _pickFile,
                  onUpload: _uploadFile,
                  tags: _tags,
                  availableTags: provider.allTags,
                  onAddTag: _addTag,
                  onRemoveTag: (t) => setState(() => _tags.remove(t)),
                  error: _tab.index == 0 ? _error : null,
                ),
                _UrlTab(
                  controller: _urlController,
                  onFetch: _fetchUrl,
                  tags: _tags,
                  availableTags: provider.allTags,
                  onAddTag: _addTag,
                  onRemoveTag: (t) => setState(() => _tags.remove(t)),
                  error: _tab.index == 1 ? _error : null,
                ),
                _LibraryTab(
                  onSongAdded: (title) => _showSuccess(title),
                ),
              ],
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

/// A library entry from the musetrainer GitHub repository.
class _LibraryEntry {
  final String name;
  final String downloadUrl;

  const _LibraryEntry({required this.name, required this.downloadUrl});

  /// Human-readable title derived from the filename.
  String get title => name
      .replaceAll(RegExp(r'\.(mxl|xml|musicxml)$', caseSensitive: false), '')
      .replaceAll('_', ' ');
}

class _LibraryTab extends StatefulWidget {
  final void Function(String title) onSongAdded;

  const _LibraryTab({required this.onSongAdded});

  @override
  State<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends State<_LibraryTab>
    with AutomaticKeepAliveClientMixin {
  static const _apiUrl =
      'https://api.github.com/repos/musetrainer/library/contents/scores';
  static const _rawBase =
      'https://raw.githubusercontent.com/musetrainer/library/master/scores/';

  List<_LibraryEntry> _entries = [];
  bool _fetching = false;
  String? _fetchError;
  final Set<String> _adding = {};
  final Set<String> _added = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _fetching = true;
      _fetchError = null;
    });
    try {
      final response = await http.get(Uri.parse(_apiUrl));
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final List<dynamic> data = json.decode(response.body) as List<dynamic>;
      final entries = data
          .where((item) {
            if (item['type'] != 'file') return false;
            final name = (item['name'] as String).toLowerCase();
            return name.endsWith('.mxl') ||
                name.endsWith('.xml') ||
                name.endsWith('.musicxml');
          })
          .map((item) => _LibraryEntry(
                name: item['name'] as String,
                downloadUrl: Uri.parse(_rawBase).resolve(item['name'] as String).toString(),
              ))
          .toList()
        ..sort((a, b) => a.title.compareTo(b.title));
      setState(() => _entries = entries);
    } catch (e) {
      setState(() => _fetchError = 'Failed to load library: $e');
    } finally {
      setState(() => _fetching = false);
    }
  }

  Future<void> _addSong(_LibraryEntry entry) async {
    setState(() => _adding.add(entry.name));
    try {
      final provider = context.read<SongProvider>();
      final song = await provider.addSongFromUrl(entry.downloadUrl);
      if (!mounted) return;
      if (song != null) {
        setState(() => _added.add(entry.name));
        widget.onSongAdded(song.title);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Failed to add "${entry.title}"'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(entry.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_fetching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_fetchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 8),
              Text(_fetchError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadEntries,
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _searchQuery.isEmpty
        ? _entries
        : _entries
            .where((e) =>
                e.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search songs…',
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
          child: Text(
            '${filtered.length} songs from musetrainer/library',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final entry = filtered[index];
              final isAdding = _adding.contains(entry.name);
              final isAdded = _added.contains(entry.name);
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.music_note),
                ),
                title: Text(entry.title),
                trailing: isAdding
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isAdded
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            tooltip: 'Add to library',
                            onPressed: () => _addSong(entry),
                          ),
                onTap: isAdding || isAdded ? null : () => _addSong(entry),
              );
            },
          ),
        ),
      ],
    );
  }
}
