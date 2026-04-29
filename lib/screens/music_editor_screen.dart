import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../music_kit/models/song.dart';
import '../music_kit/models/measure.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/utils/music_xml_generator.dart';
import '../services/musicxml_parser.dart';
import '../providers/song_provider.dart';
import '../providers/instrument_provider.dart';
import 'instruments_screen.dart';
import '../widgets/note_settings_sheet.dart';
import '../widgets/sheet_music_widget.dart';
import '../services/pitch_detection_service.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_constants.dart';

class MusicEditorScreen extends StatefulWidget {
  final Song? initialSong;
  const MusicEditorScreen({super.key, this.initialSong});

  @override
  State<MusicEditorScreen> createState() => _MusicEditorScreenState();
}

class _MusicEditorScreenState extends State<MusicEditorScreen> {
  late Song _song;
  int _selectedMeasureIndex = 0;

  // New note attributes
  String _nextStep = 'C';
  int _nextOctave = 4;
  double _nextAlter = 0;
  String _nextType = 'quarter';
  bool _nextIsRest = false;
  bool _nextIsDotted = false;
  String? _nextBeam;

  final PitchDetectionService _audio = PitchDetectionService();
  final TonePlayer _tonePlayer = TonePlayer();
  bool _isListening = false;
  StreamSubscription<String>? _noteSubscription;
  double _tempo = 140.0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  int _playbackMeasureIndex = -1;
  int _playbackNoteIndex = -1;
  bool _playWholeSong = false;
  bool _includePickupInFirstRow = true;

  final List<Song> _history = [];
  int _historyIndex = -1;
  int _lastSavedHistoryIndex = -1;

  bool get _hasUnsavedChanges => _historyIndex != _lastSavedHistoryIndex;

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
    _lastSavedHistoryIndex = _historyIndex;
  }

  void _saveToHistory() {
    // Remove future states if we are in the middle of history
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(_song);
    if (_history.length > 50) {
      _history.removeAt(0);
      _lastSavedHistoryIndex--;
    }
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
    final scheme = context.read<InstrumentProvider>().activeScheme;
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
    final songWithRests = _song.copyWith(measures: _fillRests(_song.measures));
    setState(() {
      _isPlaying = true;
      _playbackMeasureIndex = _selectedMeasureIndex;
      _playbackNoteIndex = 0;
      if (_playWholeSong) {
        _playbackMeasureIndex = 0;
      }
    });
    _scheduleNextNote(songWithRests);
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

  void _scheduleNextNote(Song playbackSong) {
    if (!_isPlaying || !mounted) return;

    final m = playbackSong.measures[_playbackMeasureIndex];
    if (_playbackNoteIndex >= m.notes.length) {
      if (_playWholeSong && _playbackMeasureIndex < playbackSong.measures.length - 1) {
        _playbackMeasureIndex++;
        _playbackNoteIndex = 0;
        _scheduleNextNote(playbackSong);
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
      if (!mounted) return;
      _playbackNoteIndex++;
      _scheduleNextNote(playbackSong);
    });
  }

  List<Measure> _fillRests(List<Measure> measures) {
    final List<Measure> result = [];
    for (final m in measures) {
      if (m.isPickup) {
        result.add(m);
        continue;
      }
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
    final songWithRests = _song.copyWith(measures: _fillRests(_song.measures));
    final xml = MusicXmlGenerator.generate(songWithRests);
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

    _lastSavedHistoryIndex = _historyIndex;

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

  Future<bool> _showBackConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Unsaved Changes'),
            content: const Text('You have unsaved changes. Do you want to discard them and leave?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Discard'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _showBackConfirmationDialog();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: KeyboardListener(
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
          } else if (event.logicalKey == LogicalKeyboardKey.keyB) {
            _toggleBeam();
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
              icon: Consumer<InstrumentProvider>(
                builder: (context, cp, _) {
                  final s = cp.activeScheme;
                  return InstrumentIcon(scheme: s, size: 24);
                },
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InstrumentsScreen()),
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
                song: _song.copyWith(measures: _fillRests(_song.measures)),
                measuresPerRow: 2,
                includePickupInFirstRow: _includePickupInFirstRow,
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
                  beam: (!_nextIsRest && (_nextType == 'eighth' || _nextType == '16th')) ? _nextBeam : null,
                ),
              ),
            ),
            _buildEditorControls(),
          ],
        ),
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

  void _toggleBeam() {
    if (_nextIsRest || !(_nextType == 'eighth' || _nextType == '16th')) return;
    setState(() {
      if (_nextBeam == null) {
        _nextBeam = 'begin';
      } else if (_nextBeam == 'begin') {
        _nextBeam = 'continue';
      } else if (_nextBeam == 'continue') {
        _nextBeam = 'end';
      } else {
        _nextBeam = null;
      }
    });
  }

  void _addCurrentNote() {
    final bool canBeam = !_nextIsRest && (_nextType == 'eighth' || _nextType == '16th');
    final MusicNote note = MusicNote(
      step: _nextStep,
      octave: _nextOctave,
      alter: _nextAlter,
      duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
      type: _nextType,
      dot: _nextIsDotted ? 1 : 0,
      isRest: _nextIsRest,
      beam: canBeam ? _nextBeam : null,
    );
    _addNote(note);

    // Auto-advance beam state
    if (canBeam) {
      setState(() {
        if (_nextBeam == 'begin') {
          _nextBeam = 'continue';
        } else if (_nextBeam == 'end') {
          _nextBeam = null;
        }
      });
    }
  }

  int _getGlobalActiveIndex() {
    if (_isPlaying) {
      final playbackSong = _song.copyWith(measures: _fillRests(_song.measures));
      int idx = 0;
      for (int i = 0; i < _playbackMeasureIndex; i++) {
        idx += playbackSong.measures[i].notes.length;
      }
      return idx + _playbackNoteIndex;
    }
    return -1;
  }

  int _getGhostNoteGlobalIndex() {
    final displaySong = _song.copyWith(measures: _fillRests(_song.measures));
    if (_selectedMeasureIndex >= displaySong.measures.length) return 0;

    int targetMeasureIndex = _selectedMeasureIndex;

    // Check if current note would fit in the selected measure
    final m = _song.measures[targetMeasureIndex];
    final double actualCapacity = m.beats * (4.0 / m.beatType);
    final double currentDuration = m.notes.fold(0.0, (sum, n) => sum + n.duration);
    final double nextNoteDuration = MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0);

    // If it won't fit, it will jump to the next measure on add
    if (currentDuration + nextNoteDuration > actualCapacity + 0.001) {
      if (targetMeasureIndex < displaySong.measures.length - 1) {
        targetMeasureIndex++;
      }
    }

    int idx = 0;
    for (int i = 0; i < targetMeasureIndex; i++) {
      idx += displaySong.measures[i].notes.length;
    }

    if (targetMeasureIndex == _selectedMeasureIndex) {
      // Position at the end of REAL notes in the current measure
      return idx + _song.measures[targetMeasureIndex].notes.length;
    } else {
      // Position at the start of the next measure
      return idx;
    }
  }

  Widget _buildEditorControls() {
    final m = _song.measures[_selectedMeasureIndex];
    final colorScheme = Theme.of(context).colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width > 720;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTransportRow(m),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  if (isLargeScreen) ...[
                    _buildLargeScreenSelectorRow1(),
                    const SizedBox(height: 12),
                    _buildLargeScreenSelectorRow2(),
                  ] else ...[
                    _buildPitchAndOctaveSelectors(),
                    const SizedBox(height: 12),
                    _buildDurationAndModifierSelectors(),
                  ],
                  const SizedBox(height: 16),
                  _buildActionButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransportRow(Measure m) {
    final colorScheme = Theme.of(context).colorScheme;
    final pickupCount = _song.measures.where((m) => m.isPickup).length;
    final totalMeasures = _song.measures.length - pickupCount;
    
    String measureLabel;
    if (m.isPickup) {
      measureLabel = 'Pickup';
    } else {
      // Find the count of non-pickup measures before and including this one
      int index = 0;
      for (int i = 0; i <= _selectedMeasureIndex; i++) {
        if (!_song.measures[i].isPickup) index++;
      }
      measureLabel = '$index / $totalMeasures';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.stop : Icons.play_arrow,
              color: _isPlaying ? Colors.red : Colors.green,
              size: 28,
            ),
            onPressed: _togglePlayback,
            tooltip: _isPlaying ? 'Stop' : 'Play',
          ),
          const SizedBox(width: 4),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Loop', style: TextStyle(fontSize: 10, color: colorScheme.onSurface.withOpacity(0.6))),
              SizedBox(
                height: 24,
                width: 40,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: _playWholeSong,
                    onChanged: (v) => setState(() => _playWholeSong = v),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          _buildTimeSigDisplay(m),
          const SizedBox(width: 16),
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 18),
                  onPressed: _selectedMeasureIndex > 0 ? () => setState(() => _selectedMeasureIndex--) : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
                InkWell(
                  onTap: () => _showTimeSigDialog(m),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Row(
                      children: [
                        Text(
                          measureLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.settings, size: 12, color: colorScheme.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, size: 18),
                  onPressed: _selectedMeasureIndex < _song.measures.length - 1 ? () => setState(() => _selectedMeasureIndex++) : null,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.add_box_outlined, size: 22),
            onPressed: _addMeasure,
            tooltip: 'Add Measure',
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSigDisplay(Measure m) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.3)),
      ),
      child: InkWell(
        onTap: () => _showTimeSigDialog(m),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${m.beats}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1)),
                  Container(width: 12, height: 1, color: colorScheme.onSurface, margin: const EdgeInsets.symmetric(vertical: 1)),
                  Text('${m.beatType}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, height: 1)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  void _showTimeSigDialog(Measure m) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Measure Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<int>(
                    value: m.beats,
                    items: [2, 3, 4, 5, 6, 7, 8].map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          final measures = List<Measure>.from(_song.measures);
                          measures[_selectedMeasureIndex] = m.copyWith(beats: v);
                          _song = _song.copyWith(measures: measures);
                          _saveToHistory();
                        });
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text('/', style: TextStyle(fontSize: 20)),
                  ),
                  DropdownButton<int>(
                    value: m.beatType,
                    items: [2, 4, 8].map((i) => DropdownMenuItem(value: i, child: Text(i.toString()))).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          final measures = List<Measure>.from(_song.measures);
                          measures[_selectedMeasureIndex] = m.copyWith(beatType: v);
                          _song = _song.copyWith(measures: measures);
                          _saveToHistory();
                        });
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Pickup Measure'),
                subtitle: const Text('Incomplete measure at start'),
                value: m.isPickup,
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      final measures = List<Measure>.from(_song.measures);
                      measures[_selectedMeasureIndex] = m.copyWith(isPickup: v);
                      _song = _song.copyWith(measures: measures);
                      _saveToHistory();
                    });
                    Navigator.pop(context);
                  }
                },
              ),
              if (m.isPickup)
                CheckboxListTile(
                  title: const Text('Include in same row'),
                  subtitle: const Text('Layout pickup with next measures'),
                  value: _includePickupInFirstRow,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _includePickupInFirstRow = v);
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeScreenSelectorRow1() {
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: _buildPitchSegmentedButton(),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: _buildOctaveSegmentedButton(),
        ),
      ],
    );
  }

  Widget _buildLargeScreenSelectorRow2() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _buildAccidentalSegmentedButton(),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 7,
          child: _buildDurationSegmentedButton(),
        ),
        const SizedBox(width: 8),
        _buildModifierButton(
          isSelected: _nextIsDotted,
          onPressed: () => setState(() => _nextIsDotted = !_nextIsDotted),
          label: '.',
        ),
        const SizedBox(width: 8),
        _buildModifierButton(
          isSelected: _nextIsRest,
          onPressed: () => setState(() => _nextIsRest = !_nextIsRest),
          icon: _nextIsRest ? _getRestLabel(_nextType) : '𝄽',
        ),
        if (!_nextIsRest && (_nextType == 'eighth' || _nextType == '16th')) ...[
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: _buildBeamSegmentedButton(),
          ),
        ],
      ],
    );
  }

  Widget _buildBeamSegmentedButton() {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    return SegmentedButton<String?>(
      segments: [
        const ButtonSegment(value: null, label: Text('None', style: TextStyle(fontSize: 11))),
        const ButtonSegment(value: 'begin', label: Text('Start', style: TextStyle(fontSize: 11))),
        const ButtonSegment(value: 'continue', label: Text('Cont.', style: TextStyle(fontSize: 11))),
        const ButtonSegment(value: 'end', label: Text('End', style: TextStyle(fontSize: 11))),
      ],
      selected: {_nextBeam},
      onSelectionChanged: (val) => setState(() => _nextBeam = val.first),
      showSelectedIcon: false,
      style: style,
    );
  }

  Widget _buildPitchSegmentedButton() {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    return SegmentedButton<String>(
      segments: ['C', 'D', 'E', 'F', 'G', 'A', 'B']
          .map((s) => ButtonSegment(value: s, label: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold))))
          .toList(),
      selected: {_nextStep},
      onSelectionChanged: (val) => setState(() => _nextStep = val.first),
      showSelectedIcon: false,
      style: style,
    );
  }

  Widget _buildOctaveSegmentedButton() {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    return SegmentedButton<int>(
      segments: [2, 3, 4, 5, 6]
          .map((i) => ButtonSegment(value: i, label: Text(i.toString(), style: const TextStyle(fontSize: 13))))
          .toList(),
      selected: {_nextOctave},
      onSelectionChanged: (val) => setState(() => _nextOctave = val.first),
      showSelectedIcon: false,
      style: style,
    );
  }

  Widget _buildAccidentalSegmentedButton() {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    return SegmentedButton<double>(
      segments: [
        ButtonSegment(value: -1.0, label: Text('♭', style: GoogleFonts.notoMusic(fontSize: 18))),
        ButtonSegment(value: 0.0, label: Text('♮', style: GoogleFonts.notoMusic(fontSize: 18))),
        ButtonSegment(value: 1.0, label: Text('♯', style: GoogleFonts.notoMusic(fontSize: 18))),
      ],
      selected: {_nextAlter},
      onSelectionChanged: (val) => setState(() => _nextAlter = val.first),
      showSelectedIcon: false,
      style: style,
    );
  }

  Widget _buildDurationSegmentedButton() {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    // Reversed: shortest (16th) to longest (whole) to match arrow key directions
    final durationTypes = ['16th', 'eighth', 'quarter', 'half', 'whole'];
    return SegmentedButton<String>(
      segments: durationTypes
          .map((t) => ButtonSegment(
                value: t,
                label: Text(
                  _nextIsRest ? _getRestLabel(t) : _getNoteLabel(t),
                  style: GoogleFonts.notoMusic(fontSize: 22),
                ),
              ))
          .toList(),
      selected: {_nextType},
      onSelectionChanged: (val) => setState(() => _nextType = val.first),
      showSelectedIcon: false,
      style: style,
    );
  }

  Widget _buildPitchAndOctaveSelectors() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _buildPitchSegmentedButton(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 5,
              child: _buildOctaveSegmentedButton(),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _buildAccidentalSegmentedButton(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDurationAndModifierSelectors() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDurationSegmentedButton(),
            ),
            const SizedBox(width: 8),
            _buildModifierButton(
              isSelected: _nextIsDotted,
              onPressed: () => setState(() => _nextIsDotted = !_nextIsDotted),
              label: '.',
            ),
            const SizedBox(width: 8),
            _buildModifierButton(
              isSelected: _nextIsRest,
              onPressed: () => setState(() => _nextIsRest = !_nextIsRest),
              icon: _nextIsRest ? _getRestLabel(_nextType) : '𝄽',
            ),
          ],
        ),
        if (!_nextIsRest && (_nextType == 'eighth' || _nextType == '16th')) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _buildBeamSegmentedButton(),
          ),
        ],
      ],
    );
  }

  Widget _buildModifierButton({required bool isSelected, required VoidCallback onPressed, String? label, String? icon}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 40,
      width: 44,
      decoration: BoxDecoration(
        color: isSelected ? colorScheme.secondaryContainer : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Center(
          child: label != null
              ? Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))
              : Text(icon!, style: GoogleFonts.notoMusic(fontSize: 22, color: isSelected ? colorScheme.primary : null)),
        ),
      ),
    );
  }

  String _getNoteLabel(String type) => switch (type) {
        'whole' => '𝅝',
        'half' => '𝅗𝅥',
        'quarter' => '𝅘𝅥',
        'eighth' => '𝅘𝅥𝅮',
        '16th' => '𝅘𝅥𝅯',
        _ => '𝅘𝅥',
      };

  String _getRestLabel(String type) => switch (type) {
        'whole' => '𝄻',
        'half' => '𝄼',
        'quarter' => '𝄽',
        'eighth' => '𝄾',
        '16th' => '𝄿',
        _ => '𝄽',
      };

  Widget _buildActionButtons() {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        _buildCircleActionButton(
          icon: Icons.backspace_outlined,
          onPressed: _deleteLastNote,
          color: colorScheme.surfaceContainerHighest,
          iconColor: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _addCurrentNote,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Add Note', style: TextStyle(fontWeight: FontWeight.bold)),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              minimumSize: const Size.fromHeight(48),
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildCircleActionButton(
          icon: _isListening ? Icons.mic : Icons.mic_off,
          onPressed: _toggleListening,
          color: _isListening ? Colors.red.withOpacity(0.1) : colorScheme.primaryContainer,
          iconColor: _isListening ? Colors.red : colorScheme.onPrimaryContainer,
          isListening: _isListening,
        ),
      ],
    );
  }

  Widget _buildCircleActionButton({
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    required Color iconColor,
    bool isListening = false,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: isListening ? Border.all(color: Colors.red.withOpacity(0.5), width: 2) : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }


}
