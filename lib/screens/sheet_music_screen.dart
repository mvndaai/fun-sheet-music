import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/measure.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/music_display_mode.dart';
import '../providers/instrument_provider.dart';
import '../providers/keyboard_provider.dart';
import '../services/pitch_detection_service.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_pdf_service.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../music_kit/utils/note_resolver.dart';
import '../music_kit/sheet_music_constants.dart';
import '../music_kit/widgets/staff_painter.dart';
import '../widgets/sheet_music_widget.dart';
import '../widgets/note_settings_sheet.dart';

class SheetMusicScreen extends StatefulWidget {
  final Song song;

  const SheetMusicScreen({super.key, required this.song});

  @override
  State<SheetMusicScreen> createState() => _SheetMusicScreenState();
}

class _SheetMusicScreenState extends State<SheetMusicScreen> with SingleTickerProviderStateMixin {
  // Common State
  final TonePlayer _tonePlayer = TonePlayer();
  int _activeNoteIndex = 0;
  double _tempo = 140.0;

  // View Mode State
  bool _isPlaying = false;
  Timer? _playbackTimer;

  // Practice/Game Mode State
  final PitchDetectionService _audio = PitchDetectionService();
  bool _micActive = false;
  String _detectedNote = '';
  //String? _statusMessage;
  bool _isKeyboardInput = false;
  String _lastPhysicalKey = '';
  final Map<LogicalKeyboardKey, String> _keyToNote = {};
  StreamSubscription<String>? _noteSubscription;
  Timer? _clearNoteTimer;
  final ScrollController _gameScrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  MusicDisplayMode? _lastMode;

  List<MusicNote> get _notes => widget.song.allNotes;
  MusicNote? get _currentNote => _activeNoteIndex < _notes.length ? _notes[_activeNoteIndex] : null;

  @override
  void initState() {
    super.initState();
    // Ensure keyboard focus is regained if lost
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _stopPlayback();
    _stopMic();
    _audio.dispose();
    _tonePlayer.dispose();
    _gameScrollController.dispose();
    _focusNode.dispose();
    _clearNoteTimer?.cancel();
    super.dispose();
  }

  // --- View Mode Logic ---

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    if (_notes.isEmpty) return;
    setState(() {
      _isPlaying = true;
      if (_activeNoteIndex >= _notes.length - 1) {
        _activeNoteIndex = 0;
      }
    });
    _scheduleNextNote();
  }

  void _pausePlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    setState(() => _isPlaying = false);
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _isPlaying = false;
  }

  void _scheduleNextNote() {
    if (_activeNoteIndex >= _notes.length) {
      setState(() {
        _isPlaying = false;
        _activeNoteIndex = 0;
      });
      return;
    }

    final note = _notes[_activeNoteIndex];
    final keyboardProvider = context.read<KeyboardProvider>();
    final samplePath = keyboardProvider.activeProfile.getSamplePath(note.letterName);
    _tonePlayer.playNote(note.frequency, samplePath: samplePath);

    final quarterNoteDuration = 60000.0 / _tempo;
    final noteDurationMs = (note.duration * quarterNoteDuration).toInt();

    _playbackTimer = Timer(Duration(milliseconds: noteDurationMs), () {
      if (_isPlaying && mounted) {
        setState(() {
          if (_activeNoteIndex < _notes.length - 1) {
            _activeNoteIndex++;
            _scheduleNextNote();
          } else {
            _isPlaying = false;
            _activeNoteIndex = 0;
          }
        });
      }
    });
  }

  // --- Practice/Game Mode Logic ---

  Future<void> _toggleMic() async {
    if (_micActive) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    //setState(() => _statusMessage = 'Starting microphone...');
    final success = await _audio.startListening();
    if (!mounted) return;
    if (!success) {
      setState(() {
        //_statusMessage = 'Microphone permission denied.';
        _micActive = false;
      });
      return;
    }
    setState(() {
      _micActive = true;
      //_statusMessage = null;
    });
    _noteSubscription = _audio.noteStream.listen((note) => _onNoteDetected(note, fromKeyboard: false));
  }

  Future<void> _stopMic() async {
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    await _audio.stopListening();
    if (!mounted) return;
    setState(() {
      _micActive = false;
      _detectedNote = '';
    });
  }

  void _onNoteDetected(String detectedNoteName, {bool fromKeyboard = false}) {
    if (!mounted) return;

    if (detectedNoteName.isNotEmpty) {
      _clearNoteTimer?.cancel();
      setState(() {
        _detectedNote = detectedNoteName;
        _isKeyboardInput = fromKeyboard;
      });
    } else {
      _clearNoteTimer?.cancel();
      _clearNoteTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _detectedNote = '';
            _isKeyboardInput = false;
            _lastPhysicalKey = '';
          });
        }
      });
    }

    final current = _currentNote;
    if (current == null || detectedNoteName.isEmpty) return;

    final activeScheme = context.read<InstrumentProvider>().activeScheme;
    final targetNoteName = NoteResolver.resolveTargetNote(note: current, activeScheme: activeScheme);
    final detectedMidi = MusicConstants.noteNameToMidi(detectedNoteName);
    final targetMidi = MusicConstants.noteNameToMidi(targetNoteName);

    if (detectedMidi < 0 || targetMidi < 0) return;

    if ((detectedMidi - targetMidi).abs() <= 1) {
      _advance();
      _noteSubscription?.pause();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _noteSubscription?.resume();
      });
    }
  }

  void _advance() {
    if (_activeNoteIndex < _notes.length - 1) {
      setState(() => _activeNoteIndex++);
      _scrollToCurrentNoteSmooth();
    } else {
      _onSongComplete();
    }
  }

  void _previous() {
    if (_activeNoteIndex > 0) {
      setState(() => _activeNoteIndex--);
      _scrollToCurrentNoteSmooth();
    }
  }

  void _scrollToCurrentNoteSmooth() {
    final mode = context.read<InstrumentProvider>().displayMode;
    if (mode != MusicDisplayMode.game || !_gameScrollController.hasClients) return;

    final noteIndex = _activeNoteIndex;
    int measureIdx = -1;
    int noteInMeasureIdx = -1;
    int totalNotesInMeasure = 0;
    
    int count = 0;
    for (int i = 0; i < widget.song.measures.length; i++) {
      final playable = widget.song.measures[i].playableNotes.length;
      if (noteIndex < count + playable) {
        measureIdx = i;
        noteInMeasureIdx = noteIndex - count;
        totalNotesInMeasure = playable;
        break;
      }
      count += playable;
    }
    
    if (measureIdx == -1) return;

    const double measureW = 350.0;
    final double noteProgress = totalNotesInMeasure > 0 ? noteInMeasureIdx / totalNotesInMeasure : 0;
    final double noteX = kClefW + (measureIdx * measureW) + (noteProgress * measureW);
    
    final maxScroll = _gameScrollController.position.maxScrollExtent;
    final viewportHeight = _gameScrollController.position.viewportDimension;
    final totalWidth = kClefW + widget.song.measures.length * measureW;
    final double noteYInContent = totalWidth - noteX;
    final double strikeLineYInViewport = viewportHeight * 0.75;
    final double scrollPosition = noteYInContent - strikeLineYInViewport;

    _gameScrollController.animateTo(
      scrollPosition.clamp(0, maxScroll),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSongComplete() {
    _stopMic();
    _stopPlayback();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.stars, color: Colors.white),
            SizedBox(width: 12),
            Text('Congratulations! Song Complete!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('🎉 Congratulations!'),
        content: const Text('You completed the song!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _activeNoteIndex = 0;
                //_statusMessage = null;
              });
            },
            child: const Text('Play Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // --- Shared Logic ---

  void _toggleMetronome() {
    if (_tonePlayer.isMetronomeRunning) {
      _tonePlayer.stopMetronome();
    } else {
      final provider = context.read<InstrumentProvider>();
      _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
    }
    setState(() {});
  }

  Future<void> _printSong() async {
    final provider = context.read<InstrumentProvider>();
    await MusicPdfService.printSong(
      song: widget.song,
      colorScheme: provider.activeScheme,
      showSolfege: provider.showSolfege,
      showLetter: provider.showLetter,
      labelsBelow: provider.labelsBelow,
      coloredLabels: provider.coloredLabels,
      measuresPerRow: provider.measuresPerRow,
      landscape: provider.pdfLandscape,
    );
  }

  void _openSettings() {
    NoteSettingsSheet.show(
      context,
      tempo: _tempo,
      onTempoChanged: (v) {
        setState(() => _tempo = v);
        if (_tonePlayer.isMetronomeRunning) {
          final provider = context.read<InstrumentProvider>();
          _tonePlayer.startMetronome(_tempo, sound: provider.metronomeSound);
        }
      },
      onPrint: _printSong,
      showTempo: true,
      showPrint: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstrumentProvider>();
    final keyboardProvider = context.watch<KeyboardProvider>();
    final mode = provider.displayMode;

    // Detect mode change to trigger scroll
    if (_lastMode != mode) {
      _lastMode = mode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && mode == MusicDisplayMode.game) {
          _scrollToCurrentNoteSmooth();
        }
      });
    }

    final current = _currentNote;
    final progress = _notes.isEmpty ? 0.0 : (_activeNoteIndex / _notes.length).clamp(0.0, 1.0);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        final isP = event.logicalKey == LogicalKeyboardKey.keyP;
        final isControlOrMeta = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
        
        if (isP && isControlOrMeta) {
          if (event is KeyDownEvent) {
            _printSong();
          }
          return KeyEventResult.handled;
        }

        if (mode == MusicDisplayMode.view) return KeyEventResult.ignored;
        if (event is KeyRepeatEvent) return KeyEventResult.handled;
        final mapping = KeyboardUtils.getMappingName(event);
        final overrides = keyboardProvider.activeProfile.keyboardOverrides;

        String? findNote(String mapping) {
          final current = _currentNote;
          if (current != null) {
            final targetNoteName = NoteResolver.resolveTargetNote(note: current, activeScheme: provider.activeScheme);
            if (overrides[targetNoteName] == mapping) return targetNoteName;
            // Fallback for keyboard mappings across octaves if only one was mapped
            // (Standard Keyboard already has many mapped, but we can do a quick check)
            final step = targetNoteName.replaceAll(RegExp(r'\d+$'), '');
            for (int oct = 1; oct <= 8; oct++) {
              if (overrides['$step$oct'] == mapping) return '$step$oct';
            }
          }
          for (final entry in overrides.entries) {
            if (entry.value == mapping) return entry.key;
          }
          return null;
        }

        if (event is KeyUpEvent) {
          final noteName = _keyToNote.remove(event.logicalKey);
          if (noteName != null) {
            final midi = MusicConstants.noteNameToMidi(noteName);
            if (midi >= 0) {
              final samplePath = keyboardProvider.activeProfile.getSamplePath(noteName);
              _tonePlayer.stopNote(MusicConstants.midiToFrequency(midi), samplePath: samplePath);
            }
          }
          return KeyEventResult.ignored;
        }

        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (_keyToNote.containsKey(event.logicalKey)) return KeyEventResult.handled;

        String? noteName = findNote(mapping);
        if (noteName == null && mapping.contains('+')) {
          noteName = findNote(KeyboardUtils.getEventKeyName(event));
        }

        if (noteName != null) {
          _keyToNote[event.logicalKey] = noteName;
          final midi = MusicConstants.noteNameToMidi(noteName);
          if (midi >= 0) {
            final samplePath = keyboardProvider.activeProfile.getSamplePath(noteName);
            _tonePlayer.startNote(MusicConstants.midiToFrequency(midi), samplePath: samplePath);
          }
          setState(() => _lastPhysicalKey = KeyboardUtils.formatForDisplay(mapping));
          _onNoteDetected(noteName, fromKeyboard: true);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.space) {
          _toggleMic();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        extendBodyBehindAppBar: mode == MusicDisplayMode.game,
        appBar: AppBar(
          backgroundColor: mode == MusicDisplayMode.game ? Colors.transparent : null,
          elevation: mode == MusicDisplayMode.game ? 0 : null,
          title: Text(widget.song.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _activeNoteIndex > 0 ? _previous : null,
              tooltip: 'Previous Note',
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: _activeNoteIndex < _notes.length - 1 ? _advance : null,
              tooltip: 'Next Note',
            ),
            if (mode == MusicDisplayMode.view)
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: _togglePlayback,
                tooltip: _isPlaying ? 'Pause' : 'Play',
              )
            else
              IconButton(
                icon: Icon(_micActive ? Icons.mic : Icons.mic_off),
                onPressed: _toggleMic,
                color: _micActive ? Colors.green : null,
                tooltip: _micActive ? 'Stop Mic' : 'Start Mic',
              ),
            IconButton(
              icon: Icon(_tonePlayer.isMetronomeRunning ? Icons.stop : Icons.av_timer),
              onPressed: _toggleMetronome,
              tooltip: _tonePlayer.isMetronomeRunning ? 'Stop Metronome' : 'Start Metronome',
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _openSettings,
              tooltip: 'Settings',
            ),
          ],
        ),
        body: Column(
          children: [
            if (mode != MusicDisplayMode.game) LinearProgressIndicator(value: progress, minHeight: 4),
            if (mode == MusicDisplayMode.practice && current != null)
              _CurrentNoteCard(
                note: current,
                showSolfege: provider.showSolfege,
                detectedNote: _detectedNote,
                isKeyboardInput: _isKeyboardInput,
                lastPhysicalKey: _lastPhysicalKey,
                targetNoteName: NoteResolver.resolveTargetNote(note: current, activeScheme: provider.activeScheme),
                keyboardOverrides: keyboardProvider.activeProfile.keyboardOverrides,
              ),
            Expanded(
              child: mode == MusicDisplayMode.game ? _GameView(
                song: widget.song,
                activeNoteIndex: _activeNoteIndex,
                detectedNote: _detectedNote,
                scrollController: _gameScrollController,
              ) : SheetMusicWidget(
                key: ValueKey(mode),
                song: widget.song,
                activeNoteIndex: _activeNoteIndex,
                showSolfege: provider.showSolfege,
                showLetter: provider.showLetter,
                labelsBelow: provider.labelsBelow,
                coloredLabels: provider.coloredLabels,
                measuresPerRow: provider.measuresPerRow,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameView extends StatelessWidget {
  final Song song;
  final int activeNoteIndex;
  final String detectedNote;
  final ScrollController scrollController;

  const _GameView({required this.song, required this.activeNoteIndex, required this.detectedNote, required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InstrumentProvider>();
    return Stack(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: ShaderMask(
            shaderCallback: (Rect bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.white, Colors.white],
              stops: [0.0, 0.1, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: Transform(
                transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(-0.3),
                alignment: Alignment.bottomCenter,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Transform.scale(
                    scaleX: 2.2,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Center(
                        child: SizedBox(
                          width: kClefW + song.measures.length * 350.0,
                          child: SheetMusicWidget(
                            song: song,
                            activeNoteIndex: activeNoteIndex,
                            showSolfege: provider.showSolfege,
                            showLetter: provider.showLetter,
                            labelsBelow: provider.labelsBelow,
                            coloredLabels: provider.coloredLabels,
                            measuresPerRow: song.measures.length,
                            showHeader: false,
                            scrollable: false,
                            labelRotation: math.pi / 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Floating symbols
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: IgnorePointer(
            child: Transform(
              transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateX(-0.3),
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scaleX: 2.2,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Center(
                    child: SizedBox(
                      width: kClefW + 10, height: kRowH,
                      child: CustomPaint(
                        painter: StaffPainter(
                          row: StaffRowData(
                            measures: [Measure(number: 0, notes: [], beats: song.measures.isNotEmpty ? song.measures[0].beats : 4, beatType: song.measures.isNotEmpty ? song.measures[0].beatType : 4)],
                            firstNoteIndex: 0, isFirstRow: true, isLastRow: false, measuresPerRow: 1,
                          ),
                          activeNoteIndex: -1, showSolfege: false, showLetter: false, labelsBelow: false, coloredLabels: false,
                          instrument: provider.activeScheme, showNoteLabels: false, context: context, labelRotation: math.pi / 2, showStaffLines: false,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (detectedNote.isNotEmpty)
          Positioned(
            bottom: 120, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(30)),
                child: Text(detectedNote, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        Positioned(
          bottom: MediaQuery.of(context).size.height * 0.25 - 40, left: 0, right: 0,
          child: IgnorePointer(child: Container(height: 2, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5))),
        ),
      ],
    );
  }
}

class _CurrentNoteCard extends StatelessWidget {
  final MusicNote note;
  final bool showSolfege;
  final String detectedNote;
  final bool isKeyboardInput;
  final String lastPhysicalKey;
  final String targetNoteName;
  final Map<String, String> keyboardOverrides;

  const _CurrentNoteCard({required this.note, required this.showSolfege, required this.detectedNote, required this.isKeyboardInput, required this.lastPhysicalKey, required this.targetNoteName, required this.keyboardOverrides});

  @override
  Widget build(BuildContext context) {
    final isCorrect = detectedNote.isNotEmpty && (MusicConstants.noteNameToMidi(detectedNote) - MusicConstants.noteNameToMidi(targetNoteName)).abs() <= 1;
    final keyboardHint = keyboardOverrides[targetNoteName];
    final cleanHint = KeyboardUtils.formatForDisplay(keyboardHint);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Play now:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(showSolfege ? note.solfegeName : note.letterName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(width: 8),
                    if (cleanHint.isNotEmpty)
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)), child: Text(cleanHint, style: const TextStyle(fontSize: 11))),
                  ],
                ),
              ],
            ),
          ),
          if (detectedNote.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: (isCorrect ? Colors.green : Colors.orange).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: isCorrect ? Colors.green : Colors.orange)),
              child: Column(children: [
                Text(isKeyboardInput ? 'Key: $lastPhysicalKey' : 'Hearing', style: TextStyle(fontSize: 9, color: isCorrect ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                Text(detectedNote, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isCorrect ? Colors.green : Colors.orange)),
              ]),
            ),
        ],
      ),
    );
  }
}
