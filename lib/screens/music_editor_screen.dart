import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../music_kit/models/song.dart';
import '../music_kit/models/measure.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/instrument_color_scheme.dart';
import '../music_kit/utils/music_xml_generator.dart';
import '../services/musicxml_parser.dart';
import '../providers/song_provider.dart';
import '../providers/color_scheme_provider.dart';
import 'color_schemes_screen.dart';
import 'color_schemes_screen.dart';
import '../widgets/note_settings_sheet.dart';
import '../widgets/sheet_music_widget.dart';
import '../services/audio_service.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_constants.dart';

class MusicEditorScreen extends StatefulWidget {
  final Song? initialSong;
  const MusicEditorScreen({super.key, this.initialSong});

  @override
  State<MusicEditorScreen> createState() => _MusicEditorScreenState();
}

class _InstrumentIcon extends StatelessWidget {
  final InstrumentColorScheme scheme;
  final double size;
  const _InstrumentIcon({required this.scheme, this.size = 32});

  @override
  Widget build(BuildContext context) {
    if (scheme.emoji != null && scheme.emoji!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: Text(
              scheme.emoji!,
              style: TextStyle(fontSize: size),
            ),
          ),
        ),
      );
    }

    if (scheme.icon != null && scheme.icon!.isNotEmpty) {
      return Image.network(
        scheme.icon!,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => Icon(Icons.music_note, size: size),
      );
    }

    return Icon(Icons.music_note, size: size);
  }
}

class _MusicEditorScreenState extends State<MusicEditorScreen> {
  late Song _song;
  int _selectedMeasureIndex = 0;
  int _selectedNoteIndex = -1;

  // New note attributes
  String _nextStep = 'C';
  int _nextOctave = 4;
  double _nextAlter = 0;
  String _nextType = 'quarter';
  bool _nextIsRest = false;
  bool _nextIsDotted = false;
  String? _nextBeam;

  final AudioService _audio = AudioService();
  final TonePlayer _tonePlayer = TonePlayer();
  bool _isListening = false;
  StreamSubscription<String>? _noteSubscription;
  double _tempo = 140.0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  int _playbackMeasureIndex = -1;
  int _playbackNoteIndex = -1;
  bool _playWholeSong = false;

  final List<Song> _history = [];
  int _historyIndex = -1;

  @override
  void initState() {
    super.initState();
    if (widget.initialSong != null) {
      _song = widget.initialSong!;
    } else {
      final view = WidgetsBinding.instance.platformDispatcher.views.first;
      final isSmallScreen = view.physicalSize.width / view.devicePixelRatio < 600;
      _song = Song(
        id: '',
        title: 'My New Song',
        composer: 'Me',
        measures: List.generate(
          isSmallScreen ? 2 : 1,
          (i) => Measure(number: i + 1, notes: [], beats: 4, beatType: 4),
        ),
        createdAt: DateTime.now(),
      );
    }
    _saveToHistory();
  }

  void _saveToHistory() {
    // Remove future states if we are in the middle of history
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(_song);
    if (_history.length > 50) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _song = _history[_historyIndex];
        _selectedMeasureIndex = _selectedMeasureIndex.clamp(0, _song.measures.length - 1);
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _song = _history[_historyIndex];
        _selectedMeasureIndex = _selectedMeasureIndex.clamp(0, _song.measures.length - 1);
      });
    }
  }

  @override
  void dispose() {
    _noteSubscription?.cancel();
    _audio.stopListening();
    _playbackTimer?.cancel();
    _tonePlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    final success = await _audio.startListening();
    if (success) {
      if (mounted) {
        setState(() => _isListening = true);
      }
      _noteSubscription = _audio.noteStream.listen((noteName) {
        if (noteName.isNotEmpty && mounted) {
          _addNoteFromMic(noteName);
        }
      });
    }
  }

  Future<void> _stopListening() async {
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    await _audio.stopListening();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _addNoteFromMic(String noteName) {
    if (!mounted) return;
    // Apply tuning overrides from active instrument scheme
    final scheme = context.read<ColorSchemeProvider>().activeScheme;
    String actualNoteName = noteName;
    if (scheme.tuningOverrides.isNotEmpty) {
      // Find if this heard note is a result of a transposed note in the scheme
      final entry = scheme.tuningOverrides.entries.firstWhere(
        (e) => e.value == noteName,
        orElse: () => MapEntry(noteName, noteName),
      );
      actualNoteName = entry.key;
    }

    final match = RegExp(r'^([A-G])([#b])?(-?\d+)$').firstMatch(actualNoteName);
    if (match == null) return;

    final step = match.group(1)!;
    final acc = match.group(2);
    final alter = acc == '#' ? 1.0 : (acc == 'b' ? -1.0 : 0.0);
    final octave = int.tryParse(match.group(3)!) ?? 4;

    _addNote(MusicNote(
      step: step,
      octave: octave,
      alter: alter,
      duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
      type: _nextType,
      dot: _nextIsDotted ? 1 : 0,
      beam: _nextBeam,
    ));
  }

  String _getNoteType(double duration) {
    String closestType = 'quarter';
    double minDiff = double.infinity;
    for (var entry in MusicConstants.typeToDuration.entries) {
      final diff = (entry.value - duration).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestType = entry.key;
      }
    }
    return closestType;
  }

  void _addNote(MusicNote note) {
    setState(() {
      _addNoteInternal(note);
      _saveToHistory();
    });
  }

  void _addNoteInternal(MusicNote note) {
    final m = _song.measures[_selectedMeasureIndex];
    final double actualCapacity = m.beats * (4.0 / m.beatType);
    final double currentDuration = m.notes.fold(0.0, (sum, n) => sum + n.duration);
    final double remainingSpace = actualCapacity - currentDuration;

    if (note.duration > remainingSpace + 0.001) {
      if (remainingSpace > 0.125) {
        // Fill remaining space and split
        final firstPart = note.copyWith(
          duration: remainingSpace,
          type: _getNoteType(remainingSpace),
          dot: 0, // Split parts don't inherit dots directly
          isTied: true,
        );
        _appendNoteToCurrentMeasure(firstPart);

        final restOfNote = note.copyWith(
          duration: note.duration - remainingSpace,
          type: _getNoteType(note.duration - remainingSpace),
          dot: 0,
        );
        _moveToNextMeasure();
        _addNoteInternal(restOfNote);
      } else {
        // Not enough space, move to next measure
        _moveToNextMeasure();
        _addNoteInternal(note);
      }
    } else {
      _appendNoteToCurrentMeasure(note);
    }
  }

  void _appendNoteToCurrentMeasure(MusicNote note) {
    final measures = List<Measure>.from(_song.measures);
    final m = measures[_selectedMeasureIndex];
    final notes = List<MusicNote>.from(m.notes)..add(note);
    measures[_selectedMeasureIndex] = m.copyWith(notes: notes);
    _song = _song.copyWith(measures: measures);
  }

  void _moveToNextMeasure() {
    if (_selectedMeasureIndex < _song.measures.length - 1) {
      _selectedMeasureIndex++;
    } else {
      _addMeasureInternal();
    }
  }

  void _deleteLastNote() {
    setState(() {
      final measures = List<Measure>.from(_song.measures);
      final m = measures[_selectedMeasureIndex];
      if (m.notes.isNotEmpty) {
        final notes = List<MusicNote>.from(m.notes)..removeLast();
        measures[_selectedMeasureIndex] = m.copyWith(notes: notes);
      } else if (_selectedMeasureIndex > 0) {
        measures.removeAt(_selectedMeasureIndex);
        _selectedMeasureIndex--;
      }
      _song = _song.copyWith(measures: measures);
      _saveToHistory();
    });
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    setState(() {
      _isPlaying = true;
      _playbackMeasureIndex = _selectedMeasureIndex;
      _playbackNoteIndex = 0;
      if (_playWholeSong) {
        _playbackMeasureIndex = 0;
      }
    });
    _scheduleNextNote();
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _playbackMeasureIndex = -1;
        _playbackNoteIndex = -1;
      });
    } else {
      _isPlaying = false;
      _playbackMeasureIndex = -1;
      _playbackNoteIndex = -1;
    }
  }

  void _scheduleNextNote() {
    if (!_isPlaying || !mounted) return;
    
    final m = _song.measures[_playbackMeasureIndex];
    if (_playbackNoteIndex >= m.notes.length) {
      if (_playWholeSong && _playbackMeasureIndex < _song.measures.length - 1) {
        _playbackMeasureIndex++;
        _playbackNoteIndex = 0;
        _scheduleNextNote();
      } else {
        _stopPlayback();
      }
      return;
    }

    final note = m.notes[_playbackNoteIndex];
    if (!note.isRest) {
      _tonePlayer.playNote(note.frequency);
    }

    setState(() {}); // Highlight current note

    final quarterNoteDuration = 60000.0 / _tempo;
    final noteDurationMs = (note.duration * quarterNoteDuration).toInt();

    _playbackTimer = Timer(Duration(milliseconds: noteDurationMs), () {
      _playbackNoteIndex++;
      _scheduleNextNote();
    });
  }

  List<Measure> _fillRests(List<Measure> measures) {
    final List<Measure> result = [];
    for (final m in measures) {
      double totalDuration = 0;
      for (final n in m.notes) {
        totalDuration += n.duration;
      }
      
      final double actualCapacity = m.beats * (4.0 / m.beatType);
      
      if (totalDuration < actualCapacity) {
        final remaining = actualCapacity - totalDuration;
        if (remaining >= 0.125) { // Minimum rest size (32nd note)
          final restNotes = _createRests(remaining);
          result.add(m.copyWith(notes: [...m.notes, ...restNotes]));
          continue;
        }
      }
      result.add(m);
    }
    return result;
  }

  List<MusicNote> _createRests(double duration) {
    final rests = <MusicNote>[];
    double remaining = duration;
    
    // Define available rest types and their durations (including dotted)
    final List<MapEntry<String, double>> possibleRests = [];
    for (final entry in MusicConstants.typeToDuration.entries) {
      possibleRests.add(entry);
      // Add dotted version (1.5x duration)
      possibleRests.add(MapEntry('${entry.key}_dotted', entry.value * 1.5));
    }
    
    // Sort by duration descending
    possibleRests.sort((a, b) => b.value.compareTo(a.value));

    for (final entry in possibleRests) {
      while (remaining >= entry.value - 0.001) { // Small epsilon for float precision
        final isDotted = entry.key.endsWith('_dotted');
        final type = isDotted ? entry.key.replaceAll('_dotted', '') : entry.key;
        
        rests.add(MusicNote(
          step: 'C',
          octave: 4,
          duration: entry.value,
          type: type,
          isRest: true,
          dot: isDotted ? 1 : 0,
        ));
        remaining -= entry.value;
      }
    }
    return rests;
  }

  void _addMeasure() {
    setState(() {
      _addMeasureInternal();
      _saveToHistory();
    });
  }

  void _addMeasureInternal() {
    final measures = List<Measure>.from(_song.measures);
    final last = measures.last;
    final newMeasure = Measure(
      number: last.number + 1,
      notes: [],
      beats: last.beats,
      beatType: last.beatType,
    );
    _song = _song.copyWith(measures: [...measures, newMeasure]);
    _selectedMeasureIndex = _song.measures.length - 1;
  }

  Future<void> _save() async {
    final xml = MusicXmlGenerator.generate(_song);
    final provider = context.read<SongProvider>();
    String id = _song.id;
    if (id.isEmpty) {
      final newSong = await provider.addSongFromXml(xml, library: 'Created');
      if (newSong != null) {
        id = newSong.id;
        // The parser returns a new Song object, update local state
        setState(() {
          _song = newSong;
        });
      }
    } else {
      await provider.updateSongXml(id, xml);
    }
    
    // SongProvider automatically notifies listeners on add/update
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song saved successfully')),
      );
      Navigator.pop(context);
    }
  }

  void _showMetadataEditor() {
    final titleController = TextEditingController(text: _song.title);
    final composerController = TextEditingController(text: _song.composer);
    final arrangerController = TextEditingController(text: _song.arranger);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Song Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: composerController,
              decoration: const InputDecoration(labelText: 'Composer'),
            ),
            TextField(
              controller: arrangerController,
              decoration: const InputDecoration(labelText: 'Arranger'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _song = _song.copyWith(
                  title: titleController.text,
                  composer: composerController.text,
                  arranger: arrangerController.text,
                );
                _saveToHistory();
              });
              Navigator.pop(context);
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showXmlEditor() {
    final controller = TextEditingController(text: MusicXmlGenerator.generate(_song));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit MusicXML'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: controller,
            maxLines: 20,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Paste MusicXML here...',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              try {
                final newSong = MusicXmlParser.parse(controller.text, id: _song.id);
                setState(() {
                  _song = newSong;
                  _saveToHistory();
                });
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error parsing XML: $e')));
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            _changePitch(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            _changePitch(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _changeDuration(1);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            _changeDuration(-1);
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            _addCurrentNote();
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            _deleteLastNote();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: _showMetadataEditor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_song.id.isEmpty ? 'Make My Own' : _song.title, style: const TextStyle(fontSize: 16)),
                if (_song.composer.isNotEmpty)
                  Text(_song.composer, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal)),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: Consumer<ColorSchemeProvider>(
                builder: (context, cp, _) {
                  final s = cp.activeScheme;
                  return _InstrumentIcon(scheme: s, size: 24);
                },
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ColorSchemesScreen()),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => NoteSettingsSheet.show(
                context,
                showTempo: true,
                tempo: _tempo,
                onTempoChanged: (v) => setState(() => _tempo = v),
              ),
            ),
            IconButton(icon: const Icon(Icons.undo), onPressed: _historyIndex > 0 ? _undo : null),
            IconButton(icon: const Icon(Icons.redo), onPressed: _historyIndex < _history.length - 1 ? _redo : null),
            IconButton(icon: const Icon(Icons.code), onPressed: _showXmlEditor),
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SheetMusicWidget(
                song: _song,
                measuresPerRow: 2,
                activeNoteIndex: _getGlobalActiveIndex(),
                ghostNoteIndex: _isPlaying ? null : _getGhostNoteGlobalIndex(),
                ghostNote: _isPlaying ? null : MusicNote(
                  step: _nextStep,
                  octave: _nextOctave,
                  alter: _nextAlter,
                  duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
                  type: _nextType,
                  dot: _nextIsDotted ? 1 : 0,
                  isRest: _nextIsRest,
                  beam: _nextBeam,
                ),
              ),
            ),
            _buildEditorControls(),
          ],
        ),
      ),
    );
  }

  void _changePitch(int delta) {
    const steps = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    int idx = steps.indexOf(_nextStep);
    idx += delta;
    if (idx >= steps.length) {
      idx = 0;
      _nextOctave++;
    } else if (idx < 0) {
      idx = steps.length - 1;
      _nextOctave--;
    }
    setState(() {
      _nextStep = steps[idx];
      _nextOctave = _nextOctave.clamp(2, 6);
    });
  }

  void _changeDuration(int delta) {
    final types = MusicConstants.typeToDuration.keys.toList();
    final List<({String type, bool dotted})> durations = [];
    for (final type in types) {
      durations.add((type: type, dotted: false));
      durations.add((type: type, dotted: true));
    }
    durations.sort((a, b) {
      double durA = MusicConstants.typeToDuration[a.type]! * (a.dotted ? 1.5 : 1.0);
      double durB = MusicConstants.typeToDuration[b.type]! * (b.dotted ? 1.5 : 1.0);
      return durA.compareTo(durB);
    });

    int currentIdx = durations.indexWhere((d) => d.type == _nextType && d.dotted == _nextIsDotted);
    if (currentIdx == -1) currentIdx = durations.indexWhere((d) => d.type == 'quarter' && !d.dotted);

    int nextIdx = (currentIdx + delta).clamp(0, durations.length - 1);
    setState(() {
      _nextType = durations[nextIdx].type;
      _nextIsDotted = durations[nextIdx].dotted;
    });
  }

  void _addCurrentNote() {
    _addNote(MusicNote(
      step: _nextStep,
      octave: _nextOctave,
      alter: _nextAlter,
      duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
      type: _nextType,
      dot: _nextIsDotted ? 1 : 0,
      isRest: _nextIsRest,
      beam: _nextBeam,
    ));
  }

  int _getGlobalActiveIndex() {
    if (_isPlaying) {
      int idx = 0;
      for (int i = 0; i < _playbackMeasureIndex; i++) {
        idx += _song.measures[i].playableNotes.length;
      }
      return idx + _playbackNoteIndex;
    }
    return -1;
  }

  int _getGhostNoteGlobalIndex() {
    if (_selectedMeasureIndex >= _song.measures.length) return 0;
    int idx = 0;
    for (int i = 0; i < _selectedMeasureIndex; i++) {
      idx += _song.measures[i].playableNotes.length;
    }
    return idx + _song.measures[_selectedMeasureIndex].playableNotes.length;
  }

  Widget _buildEditorControls() {
    final m = _song.measures[_selectedMeasureIndex];
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Measure ${_selectedMeasureIndex + 1}'),
              const Spacer(),
              _buildTimeSignatureSelector(m),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.navigate_before),
                onPressed: _selectedMeasureIndex > 0 ? () => setState(() => _selectedMeasureIndex--) : null,
              ),
              IconButton(
                icon: const Icon(Icons.navigate_next),
                onPressed: _selectedMeasureIndex < _song.measures.length - 1 ? () => setState(() => _selectedMeasureIndex++) : null,
              ),
              IconButton(icon: const Icon(Icons.add_box), onPressed: _addMeasure),
            ],
          ),
          const Divider(),
          Row(
            children: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                onPressed: _togglePlayback,
              ),
              const Text('Loop:'),
              Switch(
                value: _playWholeSong,
                onChanged: (v) => setState(() => _playWholeSong = v),
              ),
              Text(_playWholeSong ? 'Song' : 'Measure'),
              const Spacer(),
              _buildDropdown<String>(
                label: 'Note',
                value: _nextStep,
                items: ['C', 'D', 'E', 'F', 'G', 'A', 'B'],
                onChanged: (v) => setState(() => _nextStep = v!),
              ),
              _buildDropdown<int>(
                label: 'Octave',
                value: _nextOctave,
                items: [2, 3, 4, 5, 6],
                onChanged: (v) => setState(() => _nextOctave = v!),
              ),
              _buildDropdown<String>(
                label: 'Duration',
                value: _nextType,
                items: MusicConstants.typeToDuration.keys.toList(),
                onChanged: (v) => setState(() => _nextType = v!),
              ),
              _buildDropdown<String?>(
                label: 'Beam',
                value: _nextBeam,
                items: [null, 'begin', 'continue', 'end'],
                onChanged: (v) => setState(() => _nextBeam = v),
              ),
              FilterChip(
                label: const Text('Dot'),
                selected: _nextIsDotted,
                onSelected: (v) => setState(() => _nextIsDotted = v),
              ),
              FilterChip(
                label: const Text('Rest'),
                selected: _nextIsRest,
                onSelected: (v) => setState(() => _nextIsRest = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addNote(MusicNote(
                    step: _nextStep,
                    octave: _nextOctave,
                    alter: _nextAlter,
                    duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
                    type: _nextType,
                    dot: _nextIsDotted ? 1 : 0,
                    isRest: _nextIsRest,
                    beam: _nextBeam,
                  )),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Note'),
                ),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                onPressed: _toggleListening,
                backgroundColor: _isListening ? Colors.green : null,
                mini: true,
                child: Icon(_isListening ? Icons.mic : Icons.mic_off),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSignatureSelector(Measure m) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButton<int>(
          value: m.beats,
          isDense: true,
          items: [2, 3, 4, 5, 6, 7, 8].map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              final measures = List<Measure>.from(_song.measures);
              measures[_selectedMeasureIndex] = m.copyWith(beats: v);
              _song = _song.copyWith(measures: measures);
              _saveToHistory();
            });
          },
        ),
        const Text('/'),
        DropdownButton<int>(
          value: m.beatType,
          isDense: true,
          items: [2, 4, 8].map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              final measures = List<Measure>.from(_song.measures);
              measures[_selectedMeasureIndex] = m.copyWith(beatType: v);
              _song = _song.copyWith(measures: measures);
              _saveToHistory();
            });
          },
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 10)),
        DropdownButton<T>(
          value: value,
          isDense: true,
          items: items.map((i) => DropdownMenuItem<T>(value: i, child: Text(i == null ? 'None' : i.toString()))).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
