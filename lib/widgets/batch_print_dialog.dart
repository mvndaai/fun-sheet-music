import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/song_provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/utils/music_pdf_service.dart';
import '../music_kit/models/song.dart';

class BatchPrintDialog extends StatefulWidget {
  const BatchPrintDialog({super.key});

  static Future<void> show(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) => const BatchPrintDialog(),
    );
  }

  @override
  State<BatchPrintDialog> createState() => _BatchPrintDialogState();
}

class _BatchPrintDialogState extends State<BatchPrintDialog> {
  final Set<String> _selectedSongIds = {};

  @override
  Widget build(BuildContext context) {
    final songs = context.watch<SongProvider>().songs;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Batch Print Songs'),
          if (songs.isNotEmpty)
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedSongIds.length == songs.length) {
                    _selectedSongIds.clear();
                  } else {
                    _selectedSongIds.addAll(songs.map((s) => s.id));
                  }
                });
              },
              child: Text(_selectedSongIds.length == songs.length ? 'Deselect All' : 'Select All'),
            ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: songs.isEmpty
            ? const Text('No songs available.')
            : ListView.builder(
                shrinkWrap: true,
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final isSelected = _selectedSongIds.contains(song.id);
                  return CheckboxListTile(
                    title: Text(song.title),
                    subtitle: Text(song.composer),
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedSongIds.add(song.id);
                        } else {
                          _selectedSongIds.remove(song.id);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedSongIds.isEmpty ? null : _printSelected,
          child: const Text('Print Selected'),
        ),
      ],
    );
  }

  Future<void> _printSelected() async {
    final songProvider = context.read<SongProvider>();
    final instrumentProvider = context.read<InstrumentProvider>();
    
    final List<Song> fullSongs = [];
    for (final id in _selectedSongIds) {
      final song = await songProvider.loadFullSong(id);
      if (song != null) {
        fullSongs.add(song);
      }
    }

    if (fullSongs.isNotEmpty && mounted) {
      Navigator.pop(context);
      await MusicPdfService.printSongs(
        songs: fullSongs,
        colorScheme: instrumentProvider.activeScheme,
        showSolfege: instrumentProvider.showSolfege,
        showLetter: instrumentProvider.showLetter,
        labelsBelow: instrumentProvider.labelsBelow,
        coloredLabels: instrumentProvider.coloredLabels,
        measuresPerRow: instrumentProvider.measuresPerRow,
        landscape: instrumentProvider.pdfLandscape,
      );
    }
  }
}
