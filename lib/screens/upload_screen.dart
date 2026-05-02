import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/song_provider.dart';
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
  final ScrollController _importScrollController = ScrollController();
  final ScrollController _libraryScrollController = ScrollController();
  final TextEditingController _urlController = TextEditingController();
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
    _importScrollController.dispose();
    _libraryScrollController.dispose();
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
    if (!mounted) return;
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
    final song = await provider.addSongFromUrl(url);
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

  String _getInitials(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Song'),
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(icon: Icon(Icons.library_music), text: 'Libraries'),
            Tab(icon: Icon(Icons.edit), text: 'Create'),
            Tab(icon: Icon(Icons.add), text: 'Import'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tab,
              children: [
                _LibraryTab(
                  scrollController: _libraryScrollController,
                  onSongAdded: (title) => _showSuccess(title),
                ),
                const _CreateTab(),
                _ImportTab(
                  scrollController: _importScrollController,
                  pickedFileName: _pickedFileName,
                  onPickFile: _pickFile,
                  onUpload: _uploadFile,
                  urlController: _urlController,
                  onFetch: _fetchUrl,
                  error: _tab.index == 2 ? _error : null,
                ),
              ],
            ),
    );
  }
}

class _CreateTab extends StatelessWidget {
  const _CreateTab();

  String _getInitials(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

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

class _ImportTab extends StatelessWidget {
  final ScrollController scrollController;
  final String? pickedFileName;
  final VoidCallback onPickFile;
  final VoidCallback onUpload;
  final TextEditingController urlController;
  final VoidCallback onFetch;
  final String? error;

  const _ImportTab({
    required this.scrollController,
    this.pickedFileName,
    required this.onPickFile,
    required this.onUpload,
    required this.urlController,
    required this.onFetch,
    this.error,
  });

  String _getInitials(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Upload a MusicXML file from your device OR enter a URL.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          
          // File Picker
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
          
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Row(
              children: [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                Expanded(child: Divider()),
              ],
            ),
          ),

          // URL Entry
          TextField(
            controller: urlController,
            decoration: const InputDecoration(
              labelText: 'Enter URL',
              hintText: 'https://storage.googleapis.com/...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.link),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          
          if (error != null) ...[
            const SizedBox(height: 16),
            Text(error!, style: const TextStyle(color: Colors.red)),
          ],
          
          const SizedBox(height: 32),
          
          ElevatedButton.icon(
            icon: Icon(pickedFileName != null ? Icons.upload : Icons.cloud_download),
            label: Text(pickedFileName != null ? 'Add Uploaded File' : 'Download & Add from URL'),
            onPressed: (pickedFileName != null) ? onUpload : onFetch,
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
  final String icon;
  final String? assetPath;
  final String? url;

  const _LibraryEntry({
    required this.title,
    required this.library,
    this.icon = '',
    this.assetPath,
    this.url,
  });

  String get uniqueId => assetPath ?? url ?? title;
}

class _LibraryTab extends StatefulWidget {
  final ScrollController scrollController;
  final void Function(String title) onSongAdded;

  const _LibraryTab({
    required this.scrollController,
    required this.onSongAdded,
  });

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
        final song = await provider.addSongFromXml(
          xmlContent,
          library: entry.library,
          icon: entry.icon,
        );
        if (song != null) {
          widget.onSongAdded(song.title);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _adding.remove(entry.uniqueId));
    }
  }

  String _getInitials(String title) {
    final words = title.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    if (words.length == 1) return words[0][0].toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final provider = context.watch<SongProvider>();

    final importableLibraries = provider.bundledSongsMetadata.keys
        .where((lib) => provider.bundledSongsMetadata[lib]?.isNotEmpty ?? false)
        .toList()
      ..sort();

    final bool showLibraryChips = importableLibraries.length > 1;
    final bool showLibraryInList = provider.selectedLibraries.length > 1;

    // Build unified list from all selected libraries
    final List<_LibraryEntry> allAvailable = [];
    
    // 1. Add bundled songs if selected
    for (final libName in provider.selectedLibraries) {
      if (provider.bundledSongsMetadata.containsKey(libName)) {
        for (final song in provider.bundledSongsMetadata[libName]!) {
          allAvailable.add(_LibraryEntry(
            title: song.title,
            library: song.library,
            icon: song.icon,
            assetPath: song.localPath?.startsWith('assets/') == true ? song.localPath : null,
            url: song.localPath?.startsWith('http') == true ? song.localPath : song.sourceUrl,
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
        if (showLibraryChips)
          Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  children: importableLibraries.map((lib) {
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
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text(
                      importableLibraries.isEmpty
                          ? 'No bundled songs found in assets.'
                          : 'No libraries selected or search yielded no results.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    final isAdding = _adding.contains(entry.uniqueId);
                    
                    // Check if song is already in local provider
                    final bool isAlreadyAdded = provider.songs.any((s) {
                      String normalize(String? t) => (t ?? '')
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
                        child: entry.icon.isNotEmpty
                            ? Text(entry.icon, style: const TextStyle(fontSize: 20))
                            : Text(
                                _getInitials(entry.title),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                              ),
                      ),
                      title: Text(entry.title),
                      subtitle: showLibraryInList ? Text(entry.library) : null,
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
