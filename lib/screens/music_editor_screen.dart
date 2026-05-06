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
import '../providers/keyboard_provider.dart';
import '../providers/sound_provider.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../main.dart' show showToast;
import '../widgets/music_settings_sheet.dart';
import '../widgets/sheet_music_widget.dart';
import '../widgets/verse_selector.dart';
import '../music_kit/utils/music_pdf_service.dart';
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
  final FocusNode _focusNode = FocusNode();

  // New note attributes
  String _nextStep = 'C';
  int _nextOctave = 4;
  double _nextAlter = 0;
  String _nextType = 'quarter';
  bool _nextIsRest = false;
  bool _nextIsDotted = false;
  bool _nextIsTied = false;
  String? _nextBeam;
  String? _nextBeam2;

  final PitchDetectionService _audio = PitchDetectionService();
  final TonePlayer _tonePlayer = TonePlayer();
  bool _isListening = false;
  StreamSubscription<String>? _noteSubscription;
  double _tempo = 140.0;
  bool _isPlaying = false;
  Timer? _playbackTimer;
  int _playbackMeasureIndex = -1;
  int _playbackNoteIndex = -1;
  bool _includePickupInFirstRow = true;
  bool _isLyricsMode = false;
  int _currentVerse = 1;
  bool _focusLastInNextMeasure = false;
  final TextEditingController _lyricController = TextEditingController();

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
      _song = Song(
        id: '',
        title: 'Make My Own',
        composer: 'Me',
        measures: [
          const Measure(number: 1, notes: [], beats: 4, beatType: 4),
        ],
        createdAt: DateTime.now(),
      );
    }
    _saveToHistory();
    _lastSavedHistoryIndex = _historyIndex;
    _validateNextNoteDuration();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
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
        _validateNextNoteDuration();
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _song = _history[_historyIndex];
        _selectedMeasureIndex = _selectedMeasureIndex.clamp(0, _song.measures.length - 1);
        _validateNextNoteDuration();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _noteSubscription?.cancel();
    _audio.stopListening();
    _playbackTimer?.cancel();
    _tonePlayer.dispose();
    _lyricController.dispose();
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
    _validateNextNoteDuration();
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
        _validateNextNoteDuration();
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
      // Always play from the beginning if we're not just playing the selected measure
      // or just play the whole song by default now that loop is removed
      _playbackMeasureIndex = 0;
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
      if (_playbackMeasureIndex < playbackSong.measures.length - 1) {
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
      final soundProvider = context.read<SoundProvider>();
      final samplePath = soundProvider.activeProfile.getSamplePath(note.letterName);
      _tonePlayer.playNote(note.frequency, samplePath: samplePath);
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
          isPlaceholder: true,
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
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    
    String id = _song.id;
    if (id.isEmpty) {
      final newSong = await provider.addSongFromXml(xml, library: 'Created');
      if (newSong != null) {
        id = newSong.id;
        // The parser returns a new Song object, update local state
        if (mounted) {
          setState(() {
            _song = newSong;
          });
        }
      }
    } else {
      await provider.updateSongXml(id, xml);
    }

    _lastSavedHistoryIndex = _historyIndex;

    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Song saved successfully')),
      );
      navigator.pop();
    }
  }

  Future<void> _printSong() async {
    final songWithRests = _song.copyWith(measures: _fillRests(_song.measures));
    final instrumentProvider = context.read<InstrumentProvider>();
    await MusicPdfService.printSong(
      song: songWithRests,
      colorScheme: instrumentProvider.activeScheme,
      showSolfege: instrumentProvider.showSolfege,
      showLetter: instrumentProvider.showLetter,
      labelsBelow: instrumentProvider.labelsBelow,
      coloredLabels: instrumentProvider.coloredLabels,
      measuresPerRow: instrumentProvider.measuresPerRow,
      landscape: instrumentProvider.pdfLandscape,
    );
  }

  void _showMetadataEditor() {
    showDialog(
      context: context,
      builder: (context) => _SongMetadataDialog(
        initialSong: _song,
        onUpdate: (updatedSong) {
          setState(() {
            _song = updatedSong;
            _saveToHistory();
          });
        },
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
                showToast('Error parsing XML: $e', isError: true);
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

  List<Measure> _getDisplayMeasures() {
    final List<Measure> measures = [..._song.measures];
    
    // Find where the real content ends
    int lastContentIndex = -1;
    for (int i = measures.length - 1; i >= 0; i--) {
      if (measures[i].notes.isNotEmpty) {
        lastContentIndex = i;
        break;
      }
    }

    // Remove all empty measures at the end
    if (lastContentIndex < measures.length - 1) {
      measures.removeRange(lastContentIndex + 1, measures.length);
    }

    // Always add exactly one placeholder measure at the end, except in lyrics mode
    if (!_isLyricsMode) {
      measures.add(Measure(
        number: measures.isEmpty ? 1 : measures.last.number + 1,
        notes: [],
        beats: measures.isEmpty ? 4 : (measures.last.beats),
        beatType: measures.isEmpty ? 4 : (measures.last.beatType),
        isPlaceholder: true,
      ));
    }
    
    return _fillRests(measures);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final shouldPop = await _showBackConfirmationDialog();
        if (shouldPop && mounted) {
          navigator.pop();
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: (node, event) {
          // STRICT BLOCK: If we are in lyrics mode, block ALL note-entry and note-modifying shortcuts.
          // This is the safest way to ensure typing letters like 'L' or 'B' doesn't add notes.
          if (_isLyricsMode) {
            // However, we still want to allow some "global" controls like Undo/Redo or Save
            // if they are triggered with Control/Meta modifiers.
            final isModified = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
            if (!isModified) {
              return KeyEventResult.ignored;
            }
          }

          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          final keyboard = context.read<KeyboardProvider>().activeProfile;
          final mapping = KeyboardUtils.getMappingName(event);

          if (mapping == keyboard.getEditorShortcut('pitchUp')) {
            _changePitch(1);
          } else if (mapping == keyboard.getEditorShortcut('pitchDown')) {
            _changePitch(-1);
          } else if (mapping == keyboard.getEditorShortcut('durationUp')) {
            _changeDuration(1);
          } else if (mapping == keyboard.getEditorShortcut('durationDown')) {
            _changeDuration(-1);
          } else if (mapping == keyboard.getEditorShortcut('toggleBeam')) {
            _toggleBeam();
          } else if (mapping == keyboard.getEditorShortcut('addNote')) {
            _addCurrentNote();
          } else if (mapping == keyboard.getEditorShortcut('deleteNote')) {
            _deleteLastNote();
          } else if (mapping == keyboard.getEditorShortcut('undo')) {
            _undo();
          } else if (mapping == keyboard.getEditorShortcut('redo')) {
            _redo();
          } else if (mapping == keyboard.getEditorShortcut('print')) {
            _printSong();
          } else if (mapping == keyboard.getEditorShortcut('save')) {
            _save();
          } else if (mapping == keyboard.getEditorShortcut('toggleListening')) {
            _toggleListening();
          } else if (mapping == keyboard.getEditorShortcut('prevMeasure')) {
            if (_selectedMeasureIndex > 0) {
              setState(() {
                _selectedMeasureIndex--;
                _validateNextNoteDuration();
              });
            }
          } else if (mapping == keyboard.getEditorShortcut('nextMeasure')) {
            if (_selectedMeasureIndex < _song.measures.length - 1) {
              setState(() {
                _selectedMeasureIndex++;
                _validateNextNoteDuration();
              });
            }
          } else if (mapping == keyboard.getEditorShortcut('togglePlayback')) {
            _togglePlayback();
          } else {
            return KeyEventResult.ignored;
          }
          return KeyEventResult.handled;
        },
        child: Scaffold(
          appBar: AppBar(
            title: InkWell(
              onTap: _showMetadataEditor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_song.title.isNotEmpty ? _song.title : 'Make My Own', style: const TextStyle(fontSize: 16)),
                  if (_song.composer.isNotEmpty || _song.arranger.isNotEmpty)
                    Text(
                      [
                        if (_song.composer.isNotEmpty) _song.composer,
                        if (_song.arranger.isNotEmpty) _song.arranger,
                      ].join(' • '),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
                    ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
                color: _isPlaying ? Colors.red : null,
                onPressed: _togglePlayback,
                tooltip: _isPlaying ? 'Stop' : 'Play',
              ),
              IconButton(icon: const Icon(Icons.code), onPressed: _showXmlEditor),
              IconButton(
                icon: Icon(_isLyricsMode ? Icons.text_fields : Icons.music_note),
                onPressed: () => setState(() => _isLyricsMode = !_isLyricsMode),
                tooltip: 'Toggle Lyrics Mode',
              ),
              IconButton(icon: const Icon(Icons.save), onPressed: _save),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => MusicSettingsSheet.show(
                  context,
                  tempo: _tempo,
                  onTempoChanged: (v) => setState(() => _tempo = v),
                  showPrint: true,
                  onPrint: _printSong,
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SheetMusicWidget(
                  song: _song.copyWith(
                    measures: _getDisplayMeasures(),
                  ),
                  measuresPerRow: 2,
                  includePickupInFirstRow: _includePickupInFirstRow,
                  activeNoteIndex: _getGlobalActiveIndex(),
                  ghostNoteIndex: (_isPlaying || _isLyricsMode) ? null : _getGhostNoteGlobalIndex(),
                  ghostNote: (_isPlaying || _isLyricsMode) ? null : MusicNote(
                    step: _nextStep,
                    octave: _nextOctave,
                    alter: _nextAlter,
                    duration: MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0),
                    type: _nextType,
                    dot: _nextIsDotted ? 1 : 0,
                    isRest: _nextIsRest,
                    beam: (!_nextIsRest && (_nextType == 'eighth' || _nextType == '16th')) ? _nextBeam : null,
                  ),
                  currentVerse: _currentVerse,
                ),
              ),
              _isLyricsMode ? _buildLyricsEditor() : _buildEditorControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLyricsEditor() {
    final colorScheme = Theme.of(context).colorScheme;
    final measures = _song.measures;
    final currentMeasure = measures[_selectedMeasureIndex];
    final totalVerses = _song.totalVerses;
    final totalMeasures = measures.length;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Simplified Navigation Row for Lyrics Mode
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _selectedMeasureIndex > 0
                        ? () => setState(() => _selectedMeasureIndex--)
                        : null,
                    tooltip: 'Previous Measure',
                  ),
                  Text(
                    'Measure ${_selectedMeasureIndex + 1} / $totalMeasures',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _selectedMeasureIndex < totalMeasures - 1
                        ? () => setState(() => _selectedMeasureIndex++)
                        : null,
                    tooltip: 'Next Measure',
                  ),
                  const Spacer(),
                  VerseSelector(
                    currentVerse: _currentVerse,
                    totalVerses: totalVerses,
                    onChanged: (v) => setState(() => _currentVerse = v),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _showVariablesEditor,
                    icon: const Icon(Icons.settings_ethernet, size: 18),
                    label: const Text('Vars'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text('Type lyrics for each note in this measure:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (currentMeasure.notes.where((n) => !n.isChordContinuation).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('No notes in this measure to add lyrics to.'),
                    )
                  else
                    FocusTraversalGroup(
                      policy: ReadingOrderTraversalPolicy(),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 12,
                        children: currentMeasure.notes.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final note = entry.value;
                          if (note.isChordContinuation) return const SizedBox.shrink();

                          final playableNotes = currentMeasure.notes.where((n) => !n.isChordContinuation).toList();
                          final isFirstNote = note == playableNotes.first;
                          final isLastNote = note == playableNotes.last;
                          
                          return SizedBox(
                            width: 100,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(note.letterName, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                _LyricField(
                                  key: ValueKey('${_selectedMeasureIndex}_${idx}_${_currentVerse}'),
                                  note: note,
                                  verse: _currentVerse,
                                  isFirstNote: isFirstNote,
                                  isLastNote: isLastNote,
                                  focusThisOne: (isFirstNote && !_focusLastInNextMeasure) || (isLastNote && _focusLastInNextMeasure),
                                  onTabNextMeasure: () {
                                    if (_selectedMeasureIndex < totalMeasures - 1) {
                                      setState(() {
                                        _selectedMeasureIndex++;
                                        _focusLastInNextMeasure = false;
                                      });
                                    } else {
                                      _promptAddVerseOrMeasure();
                                    }
                                  },
                                  onTabPrevMeasure: () {
                                    if (_selectedMeasureIndex > 0) {
                                      setState(() {
                                        _selectedMeasureIndex--;
                                        _focusLastInNextMeasure = true;
                                      });
                                    }
                                  },
                                  onChanged: (val) {
                                    final newLyrics = Map<int, String>.from(note.lyrics);
                                    if (val.isEmpty) {
                                      newLyrics.remove(_currentVerse);
                                    } else {
                                      newLyrics[_currentVerse] = val;
                                    }
                                    final newNote = note.copyWith(lyrics: newLyrics);
                                    final newNotes = List<MusicNote>.from(currentMeasure.notes);
                                    newNotes[idx] = newNote;
                                    final newMeasures = List<Measure>.from(_song.measures);
                                    newMeasures[_selectedMeasureIndex] = currentMeasure.copyWith(notes: newNotes);
                                    setState(() {
                                      _song = _song.copyWith(measures: newMeasures);
                                    });
                                  },
                                  onEditingComplete: _saveToHistory,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVariablesEditor() {
    showDialog(
      context: context,
      builder: (context) => _VariablesEditorDialog(
        initialVariableSets: _song.lyricsVariableSets,
        onUpdate: (updatedSets) {
          setState(() {
            _song = _song.copyWith(lyricsVariableSets: updatedSets);
            _saveToHistory();
          });
        },
      ),
    );
  }

  void _promptAddVerseOrMeasure() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End of Song'),
        content: const Text('Would you like to add a new verse?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _currentVerse++;
                _selectedMeasureIndex = 0;
              });
            },
            child: const Text('Add Verse'),
          ),
        ],
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
    final m = _song.measures[_selectedMeasureIndex];
    final double maxCapacity = m.beats * (4.0 / m.beatType);

    final types = MusicConstants.typeToDuration.keys.toList();
    final List<({String type, bool dotted})> durations = [];
    for (final type in types) {
      if (MusicConstants.typeToDuration[type]! > maxCapacity + 0.001) continue;
      durations.add((type: type, dotted: false));
      if (MusicConstants.typeToDuration[type]! * 1.5 <= maxCapacity + 0.001) {
        durations.add((type: type, dotted: true));
      }
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

  void _validateNextNoteDuration() {
    final m = _song.measures[_selectedMeasureIndex];
    final double maxCapacity = m.beats * (4.0 / m.beatType);
    double currentDur = MusicConstants.typeToDuration[_nextType]! * (_nextIsDotted ? 1.5 : 1.0);
    
    if (currentDur > maxCapacity + 0.001) {
      // Find longest valid duration
      final types = ['breve', 'whole', 'half', 'quarter', 'eighth', '16th'];
      for (final t in types) {
        if (MusicConstants.typeToDuration[t]! * 1.5 <= maxCapacity + 0.001) {
          _nextType = t;
          _nextIsDotted = true;
          return;
        }
        if (MusicConstants.typeToDuration[t]! <= maxCapacity + 0.001) {
          _nextType = t;
          _nextIsDotted = false;
          return;
        }
      }
      // Fallback to 16th if nothing fits (shouldn't happen with standard time sigs)
      _nextType = '16th';
      _nextIsDotted = false;
    }
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
      beam2: (canBeam && _nextType == '16th') ? _nextBeam2 : null,
      isTied: _nextIsTied,
    );
    _addNote(note);

    // Auto-advance beam states
    if (canBeam) {
      setState(() {
        if (_nextBeam == 'begin') {
          _nextBeam = 'continue';
        } else if (_nextBeam == 'end') {
          _nextBeam = null;
        }

        if (_nextType == '16th') {
          if (_nextBeam2 == 'begin') {
            _nextBeam2 = 'continue';
          } else if (_nextBeam2 == 'end') {
            _nextBeam2 = null;
          }
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
    final displaySong = _song.copyWith(
      measures: _getDisplayMeasures(),
    );
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

    if (targetMeasureIndex == _selectedMeasureIndex && targetMeasureIndex < _song.measures.length) {
      // Position at the end of REAL notes in the current measure
      return idx + _song.measures[targetMeasureIndex].notes.length;
    } else {
      // Position at the start of the next measure (which might be the placeholder)
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
        border: Border(top: BorderSide(color: colorScheme.outlineVariant.withValues(alpha:0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha:0.1),
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
            icon: const Icon(Icons.undo, size: 20),
            onPressed: _historyIndex > 0 ? _undo : null,
            tooltip: 'Undo',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.redo, size: 20),
            onPressed: _historyIndex < _history.length - 1 ? _redo : null,
            tooltip: 'Redo',
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          _buildTimeSigDisplay(m),
          const SizedBox(width: 16),
          InkWell(
            onTap: () => _showTimeSigDialog(m),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
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
                          _validateNextNoteDuration();
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
                          _validateNextNoteDuration();
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
    final showBeamingArea = !_nextIsRest && (_nextType == 'eighth' || _nextType == '16th');
    return Column(
      children: [
        Row(
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
              onPressed: () {
                final m = _song.measures[_selectedMeasureIndex];
                final double maxCapacity = m.beats * (4.0 / m.beatType);
                final double currentDuration = MusicConstants.typeToDuration[_nextType]!;
                if (!_nextIsDotted && currentDuration * 1.5 > maxCapacity + 0.001) {
                  return;
                }
                setState(() => _nextIsDotted = !_nextIsDotted);
              },
              label: '.',
            ),
            const SizedBox(width: 8),
            _buildModifierButton(
              isSelected: _nextIsRest,
              onPressed: () => setState(() => _nextIsRest = !_nextIsRest),
              icon: _nextIsRest ? _getRestLabel(_nextType) : '𝄽',
            ),
            if (!_nextIsRest) ...[
              const SizedBox(width: 8),
              _buildModifierButton(
                isSelected: _nextIsTied,
                onPressed: () => setState(() => _nextIsTied = !_nextIsTied),
                icon: '⁀',
              ),
            ],
          ],
        ),
        if (showBeamingArea) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Beam 1', style: TextStyle(fontSize: 10)),
                    const SizedBox(height: 2),
                    _buildBeamSegmentedButton(1),
                  ],
                ),
              ),
              if (_nextType == '16th') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Beam 2', style: TextStyle(fontSize: 10)),
                      const SizedBox(height: 2),
                      _buildBeamSegmentedButton(2),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildBeamSegmentedButton(int level) {
    final style = SegmentedButton.styleFrom(
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
    return SegmentedButton<String?>(
      segments: [
        const ButtonSegment(value: null, label: Text('None', style: TextStyle(fontSize: 10))),
        const ButtonSegment(value: 'begin', label: Text('Start', style: TextStyle(fontSize: 10))),
        const ButtonSegment(value: 'continue', label: Text('Cont.', style: TextStyle(fontSize: 10))),
        const ButtonSegment(value: 'end', label: Text('End', style: TextStyle(fontSize: 10))),
      ],
      selected: {level == 1 ? _nextBeam : _nextBeam2},
      onSelectionChanged: (val) => setState(() {
        if (level == 1) {
          _nextBeam = val.first;
        } else {
          _nextBeam2 = val.first;
        }
      }),
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

    final m = _song.measures[_selectedMeasureIndex];
    final double maxCapacity = m.beats * (4.0 / m.beatType);

    // Reversed: shortest (16th) to longest (whole) to match arrow key directions
    final durationTypes = ['16th', 'eighth', 'quarter', 'half', 'whole', 'breve']
        .where((t) => MusicConstants.typeToDuration[t]! <= maxCapacity + 0.001)
        .toList();

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
    final showBeamingArea = !_nextIsRest && (_nextType == 'eighth' || _nextType == '16th');
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
              onPressed: () {
                final m = _song.measures[_selectedMeasureIndex];
                final double maxCapacity = m.beats * (4.0 / m.beatType);
                final double currentDuration = MusicConstants.typeToDuration[_nextType]!;
                if (!_nextIsDotted && currentDuration * 1.5 > maxCapacity + 0.001) {
                  return;
                }
                setState(() => _nextIsDotted = !_nextIsDotted);
              },
              label: '.',
            ),
            const SizedBox(width: 8),
            _buildModifierButton(
              isSelected: _nextIsRest,
              onPressed: () => setState(() => _nextIsRest = !_nextIsRest),
              icon: _nextIsRest ? _getRestLabel(_nextType) : '𝄽',
            ),
            if (!_nextIsRest) ...[
              const SizedBox(width: 8),
              _buildModifierButton(
                isSelected: _nextIsTied,
                onPressed: () => setState(() => _nextIsTied = !_nextIsTied),
                icon: '⁀',
              ),
            ],
          ],
        ),
        if (showBeamingArea) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBeamSegmentedButton(1),
              ),
              if (_nextType == '16th') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildBeamSegmentedButton(2),
                ),
              ],
            ],
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
        border: Border.all(color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.2)),
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
        'breve' => '𝅜',
        'whole' => '𝅝',
        'half' => '𝅗𝅥',
        'quarter' => '𝅘𝅥',
        'eighth' => '𝅘𝅥𝅮',
        '16th' => '𝅘𝅥𝅯',
        _ => '𝅘𝅥',
      };

  String _getRestLabel(String type) => switch (type) {
        'breve' => '𝄺',
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
          color: _isListening ? Colors.red.withValues(alpha: 0.1) : colorScheme.primaryContainer,
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
        border: isListening ? Border.all(color: Colors.red.withValues(alpha: 0.5), width: 2) : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor),
        onPressed: onPressed,
      ),
    );
  }
}

class _SongMetadataDialog extends StatefulWidget {
  final Song initialSong;
  final ValueChanged<Song> onUpdate;

  const _SongMetadataDialog({
    required this.initialSong,
    required this.onUpdate,
  });

  @override
  State<_SongMetadataDialog> createState() => _SongMetadataDialogState();
}

class _SongMetadataDialogState extends State<_SongMetadataDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _composerController;
  late final TextEditingController _arrangerController;
  late final TextEditingController _emojiSearchController = TextEditingController();
  late final ScrollController _emojiScrollController = ScrollController();
  late String _selectedEmoji;
  String _emojiQuery = '';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialSong.title);
    _composerController = TextEditingController(text: widget.initialSong.composer);
    _arrangerController = TextEditingController(text: widget.initialSong.arranger);
    _selectedEmoji = widget.initialSong.icon;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _composerController.dispose();
    _arrangerController.dispose();
    _emojiSearchController.dispose();
    _emojiScrollController.dispose();
    super.dispose();
  }

  Future<void> _showCustomIconDialog() async {
    final controller = TextEditingController(text: _selectedEmoji.length <= 2 ? _selectedEmoji : '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Icon'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 2,
          decoration: const InputDecoration(
            hintText: 'Enter 1-2 characters',
            helperText: 'e.g. A1, 🎸, or 👋',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _selectedEmoji = result);
    }
  }


  @override
  Widget build(BuildContext context) {
    final filteredEmojis = MusicConstants.allEmojis
        .where((e) => e.name.toLowerCase().contains(_emojiQuery.toLowerCase()))
        .toList();

    return AlertDialog(
      title: const Text('Song Info'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _composerController,
                decoration: const InputDecoration(labelText: 'Composer'),
              ),
              TextField(
                controller: _arrangerController,
                decoration: const InputDecoration(labelText: 'Arranger'),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('Icon', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _emojiSearchController,
                      decoration: const InputDecoration(
                        hintText: 'Search icons...',
                        isDense: true,
                        prefixIcon: Icon(Icons.search, size: 18),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (v) => setState(() => _emojiQuery = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Scrollbar(
                  controller: _emojiScrollController,
                  thumbVisibility: true,
                  child: GridView.builder(
                    controller: _emojiScrollController,
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 6,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemCount: filteredEmojis.length + (_emojiQuery.isEmpty ? 2 : 0),
                    itemBuilder: (context, index) {
                      if (_emojiQuery.isEmpty) {
                        if (index == 0) {
                          final isSelected = _selectedEmoji.isEmpty;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedEmoji = ''),
                            child: Tooltip(
                              message: 'No icon',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                  border: Border.all(
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(child: Icon(Icons.block, size: 20)),
                              ),
                            ),
                          );
                        }
                        if (index == 1) {
                          final isCustomSelected = _selectedEmoji.isNotEmpty && !MusicConstants.allEmojis.any((e) => e.char == _selectedEmoji);
                          return GestureDetector(
                            onTap: _showCustomIconDialog,
                            child: Tooltip(
                              message: 'Custom text icon',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isCustomSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                                  border: Border.all(
                                    color: isCustomSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: isCustomSelected
                                      ? Text(_selectedEmoji, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
                                      : const Icon(Icons.edit_note, size: 24),
                                ),
                              ),
                            ),
                          );
                        }
                      }
                      final emojiRecord = filteredEmojis[_emojiQuery.isEmpty ? index - 2 : index];
                      final emoji = emojiRecord.char;
                      final isSelected = _selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedEmoji = emoji),
                        child: Tooltip(
                          message: emojiRecord.name,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                              border: Border.all(
                                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(widget.initialSong.copyWith(
              title: _titleController.text,
              composer: _composerController.text,
              arranger: _arrangerController.text,
              icon: _selectedEmoji,
            ));
            Navigator.pop(context);
          },
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _LyricField extends StatefulWidget {
  final MusicNote note;
  final int verse;
  final ValueChanged<String> onChanged;
  final VoidCallback onEditingComplete;
  final bool isFirstNote;
  final bool isLastNote;
  final bool focusThisOne;
  final VoidCallback onTabNextMeasure;
  final VoidCallback onTabPrevMeasure;

  const _LyricField({
    super.key,
    required this.note,
    required this.verse,
    required this.onChanged,
    required this.onEditingComplete,
    required this.isFirstNote,
    required this.isLastNote,
    this.focusThisOne = false,
    required this.onTabNextMeasure,
    required this.onTabPrevMeasure,
  });

  @override
  State<_LyricField> createState() => _LyricFieldState();
}

class _LyricFieldState extends State<_LyricField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final lyric = widget.note.lyrics[widget.verse] ?? '';
    _controller = TextEditingController(text: lyric);
    _focusNode = FocusNode(
      debugLabel: 'LyricField_${widget.note.letterName}',
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        if (event.logicalKey == LogicalKeyboardKey.tab) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            if (widget.isFirstNote) {
              widget.onTabPrevMeasure();
              return KeyEventResult.handled;
            }
          } else {
            if (widget.isLastNote) {
              widget.onTabNextMeasure();
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );
    if (widget.focusThisOne) {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(_LyricField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.verse != oldWidget.verse || widget.note != oldWidget.note) {
      final lyric = widget.note.lyrics[widget.verse] ?? '';
      if (_controller.text != lyric) {
        _controller.text = lyric;
      }
    }
    if (widget.focusThisOne && !oldWidget.focusThisOne) {
      _focusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        isDense: true,
        hintText: widget.note.isRest ? '(rest)' : 'lyric...',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
    );
  }
}

class _VariablesEditorDialog extends StatefulWidget {
  final List<Map<String, String>> initialVariableSets;
  final ValueChanged<List<Map<String, String>>> onUpdate;

  const _VariablesEditorDialog({required this.initialVariableSets, required this.onUpdate});

  @override
  State<_VariablesEditorDialog> createState() => _VariablesEditorDialogState();
}

class _VariablesEditorDialogState extends State<_VariablesEditorDialog> {
  late List<Map<String, String>> _sets;

  @override
  void initState() {
    super.initState();
    _sets = widget.initialVariableSets.map((s) => Map<String, String>.from(s)).toList();
    if (_sets.isEmpty) {
      _sets.add({}); // At least one verse set
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get all keys across all sets
    final allKeys = <String>{};
    for (var set in _sets) {
      allKeys.addAll(set.keys);
    }
    final sortedKeys = allKeys.toList()..sort();

    return AlertDialog(
      title: const Text('Lyrics Variables'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: Column(
          children: [
            const Text(
              'Each column is a verse. Use {{name}} in lyrics.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    columns: [
                      const DataColumn(label: Text('Variable')),
                      ...List.generate(_sets.length, (i) => DataColumn(
                        label: Row(
                          children: [
                            Text('Verse ${i + 1}'),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 14),
                              onPressed: _sets.length > 1 ? () => setState(() => _sets.removeAt(i)) : null,
                            ),
                          ],
                        ),
                      )),
                      DataColumn(label: IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () => setState(() => _sets.add({})),
                        tooltip: 'Add Verse Column',
                      )),
                    ],
                    rows: [
                      ...sortedKeys.map((key) => DataRow(
                        cells: [
                          DataCell(Row(
                            children: [
                              Text(key, style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 14),
                                onPressed: () => setState(() {
                                  for (var set in _sets) {
                                    set.remove(key);
                                  }
                                }),
                              ),
                            ],
                          )),
                          ...List.generate(_sets.length, (i) => DataCell(
                            TextField(
                              decoration: const InputDecoration(isDense: true),
                              controller: TextEditingController(text: _sets[i][key] ?? ''),
                              onChanged: (val) => _sets[i][key] = val,
                            ),
                          )),
                          const DataCell(SizedBox.shrink()),
                        ],
                      )),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _addNewVariable,
              icon: const Icon(Icons.add),
              label: const Text('Add Variable Row'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_sets);
            Navigator.pop(context);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }

  void _addNewVariable() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Variable Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. animal'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  for (var set in _sets) {
                    set[controller.text] = '';
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}
