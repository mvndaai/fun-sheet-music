import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/song.dart';
import '../music_kit/models/music_note.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../services/pitch_detection_service.dart';
import '../services/tone_player.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../widgets/sheet_music_widget.dart';
import '../music_kit/utils/note_resolver.dart';
import '../widgets/note_settings_sheet.dart';
import 'instruments_screen.dart';

/// Practice screen: displays sheet music and listens to the microphone.
/// When the microphone hears the current note, the app advances to the next.
class PracticeScreen extends StatefulWidget {
  final Song song;

  const PracticeScreen({super.key, required this.song});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen>
    with SingleTickerProviderStateMixin {
  final PitchDetectionService _audio = PitchDetectionService();
  final TonePlayer _tonePlayer = TonePlayer();

  int _currentNoteIndex = 0;
  bool _micActive = false;
  bool _gameModeEnabled = false;
  String _detectedNote = '';
  String? _statusMessage;
  bool _isKeyboardInput = false;
  String _lastPhysicalKey = '';
  final Map<LogicalKeyboardKey, String> _keyToNote = {};
  StreamSubscription<String>? _noteSubscription;
  Timer? _clearNoteTimer;

  List<MusicNote> get _notes => widget.song.allNotes;

  MusicNote? get _currentNote =>
      _currentNoteIndex < _notes.length ? _notes[_currentNoteIndex] : null;

  @override
  void dispose() {
    _noteSubscription?.cancel();
    _clearNoteTimer?.cancel();
    _audio.dispose();
    _tonePlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    if (_micActive) {
      await _stopMic();
    } else {
      await _startMic();
    }
  }

  Future<void> _startMic() async {
    setState(() => _statusMessage = 'Starting microphone...');
    final success = await _audio.startListening();
    if (!success) {
      setState(() {
        _statusMessage = 'Microphone permission denied. Please allow microphone access.';
        _micActive = false;
      });
      return;
    }
    setState(() {
      _micActive = true;
      _statusMessage = null;
    });
    _noteSubscription = _audio.noteStream.listen((note) => _onNoteDetected(note, fromKeyboard: false));
  }

  Future<void> _stopMic() async {
    await _noteSubscription?.cancel();
    _noteSubscription = null;
    await _audio.stopListening();
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
      // Keep the last heard note visible for 2 seconds before clearing
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

    // Apply tuning override: if this instrument has a mapping for the expected note,
    // listen for the mapped note instead.
    final activeScheme = context.read<InstrumentProvider>().activeScheme;
    final specificNote = current.letterName; // e.g. "C5"

    // Resolve target note name with enharmonic and octave-fallback support
    final targetNoteName = NoteResolver.resolveTargetNote(
      note: current,
      activeScheme: activeScheme,
    );

    // Check if the detected note matches the target note (within tolerance).
    final detectedMidi = MusicConstants.noteNameToMidi(detectedNoteName);
    final targetMidi = MusicConstants.noteNameToMidi(targetNoteName);

    if (detectedMidi < 0 || targetMidi < 0) return;

    if ((detectedMidi - targetMidi).abs() <= 1) {
      // Correct note heard – advance
      _advance();

      // Pause briefly to avoid re-triggering on the same note
      _noteSubscription?.pause();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) _noteSubscription?.resume();
      });
    }
  }

  void _advance() {
    if (_currentNoteIndex < _notes.length - 1) {
      setState(() => _currentNoteIndex++);
    } else {
      _onSongComplete();
    }
  }

  void _previous() {
    if (_currentNoteIndex > 0) {
      setState(() => _currentNoteIndex--);
    }
  }

  void _onSongComplete() {
    setState(() => _statusMessage = '🎉 Song complete!');
    _stopMic();
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
                _currentNoteIndex = 0;
                _statusMessage = null;
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

  void _openSettings() {
    NoteSettingsSheet.show(context);
  }

  /// Returns the index of the measure that contains the note at [noteIndex].
  int _measureIndexForNoteIndex(int noteIndex) {
    int count = 0;
    for (int i = 0; i < widget.song.measures.length; i++) {
      final playable = widget.song.measures[i].playableNotes.length;
      if (noteIndex < count + playable) return i;
      count += playable;
    }
    return widget.song.measures.length - 1;
  }

  /// Returns a copy of the song containing only the 2 measures around the
  /// current note, used for the game-mode view.
  Song _gameModeFilteredSong() {
    final measureIdx = _measureIndexForNoteIndex(_currentNoteIndex);
    final endMeasure = (measureIdx + 2).clamp(0, widget.song.measures.length);
    return widget.song.copyWith(
      measures: widget.song.measures.sublist(measureIdx, endMeasure),
    );
  }

  /// Returns the active-note index relative to the game-mode filtered song.
  int _gameModeNoteIndex() {
    final measureIdx = _measureIndexForNoteIndex(_currentNoteIndex);
    int offset = 0;
    for (int i = 0; i < measureIdx; i++) {
      offset += widget.song.measures[i].playableNotes.length;
    }
    return _currentNoteIndex - offset;
  }

  @override
  Widget build(BuildContext context) {
    final current = _currentNote;
    final progress = _notes.isEmpty
        ? 0.0
        : (_currentNoteIndex / _notes.length).clamp(0.0, 1.0);

    return Consumer<InstrumentProvider>(
      builder: (context, provider, _) => Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyRepeatEvent) return KeyEventResult.handled;

          final mapping = KeyboardUtils.getMappingName(event);
          final overrides = provider.activeScheme.effectiveKeyboardOverrides;

          // Helper to find note by exact mapping string
          String? findNote(String mapping) {
            // If we have a current note, prefer a mapping that matches its letter name (ignoring octave)
            // or better yet, matches the target note name exactly.
            final current = _currentNote;
            if (current != null) {
              final targetNoteName = NoteResolver.resolveTargetNote(
                note: current,
                activeScheme: provider.activeScheme,
              );
              if (overrides[targetNoteName] == mapping) return targetNoteName;

              // If not exact match, check other octaves of the same note
              final step = targetNoteName.replaceAll(RegExp(r'\d+$'), '');
              for (int oct = 1; oct <= 8; oct++) {
                final candidate = '$step$oct';
                if (overrides[candidate] == mapping) return candidate;
              }
            }

            for (final entry in overrides.entries) {
              if (entry.value == mapping) return entry.key;
            }
            return null;
          }

          // Handle KeyUp to stop notes
          if (event is KeyUpEvent) {
            final noteName = _keyToNote.remove(event.logicalKey);
            if (noteName != null) {
              final midi = MusicConstants.noteNameToMidi(noteName);
              if (midi >= 0) {
                final samplePath = provider.activeScheme.getSamplePath(noteName);
                _tonePlayer.stopNote(MusicConstants.midiToFrequency(midi), samplePath: samplePath);
              }
            }
            return KeyEventResult.ignored;
          }

          if (event is! KeyDownEvent) return KeyEventResult.ignored;

          // Prevent repeating notes when holding keys
          if (_keyToNote.containsKey(event.logicalKey)) {
            return KeyEventResult.handled;
          }

          // Try exact mapping first (e.g. Shift+KeyA), then fallback to plain key (KeyA)
          // only if no specific modifier mapping was found.
          String? noteName = findNote(mapping);
          if (noteName == null && mapping.contains('+')) {
            noteName = findNote(KeyboardUtils.getEventKeyName(event));
          }

          if (noteName != null) {
            _keyToNote[event.logicalKey] = noteName;
            final midi = MusicConstants.noteNameToMidi(noteName);
            if (midi >= 0) {
              final samplePath = provider.activeScheme.getSamplePath(noteName);
              _tonePlayer.startNote(MusicConstants.midiToFrequency(midi), samplePath: samplePath);
            }
            setState(() {
              _lastPhysicalKey = KeyboardUtils.formatForDisplay(mapping);
            });
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
          appBar: AppBar(
            title: Text('Practice: ${widget.song.title}'),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.rotate_left,
                  color: _gameModeEnabled
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
                tooltip: _gameModeEnabled ? 'Exit Game Mode' : 'Game Mode',
                onPressed: () => setState(() => _gameModeEnabled = !_gameModeEnabled),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Settings',
                onPressed: _openSettings,
              ),
            ],
          ),
          body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(value: progress, minHeight: 6),

            // Status / detected note
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: _micActive
                  ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    _micActive ? Icons.mic : Icons.mic_off,
                    color: _micActive ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage ??
                          (_micActive ? 'Listening…' : 'Tap 🎙 to start practice'),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    '${_currentNoteIndex + 1} / ${_notes.length}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Current note highlight
            if (current != null)
              _CurrentNoteCard(
                note: current,
                showSolfege: provider.showSolfege,
                noteIndex: _currentNoteIndex,
                total: _notes.length,
                detectedNote: _detectedNote,
                isKeyboardInput: _isKeyboardInput,
                lastPhysicalKey: _lastPhysicalKey,
                targetNoteName: NoteResolver.resolveTargetNote(
                  note: current,
                  activeScheme: provider.activeScheme,
                ),
                keyboardOverrides: provider.activeScheme.effectiveKeyboardOverrides,
              ),

            const Divider(height: 1),

            // Sheet music (scrollable or game mode)
            Expanded(
              child: _gameModeEnabled
                  ? ClipRect(
                      child: Transform(
                        // Perspective: bottom (current notes) appears wider/closer,
                        // top (upcoming notes) narrower/farther — highway effect.
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.003) // perspective depth
                          ..rotateX(0.4), // tilt top away from viewer
                        alignment: Alignment.bottomCenter,
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SheetMusicWidget(
                            song: _gameModeFilteredSong(),
                            activeNoteIndex: _gameModeNoteIndex(),
                            showSolfege: provider.showSolfege,
                            showLetter: provider.showLetter,
                            labelsBelow: provider.labelsBelow,
                            coloredLabels: provider.coloredLabels,
                            measuresPerRow: 2,
                            showHeader: false,
                          ),
                        ),
                      ),
                    )
                  : SheetMusicWidget(
                      song: widget.song,
                      activeNoteIndex: _currentNoteIndex,
                      showSolfege: provider.showSolfege,
                      showLetter: provider.showLetter,
                      labelsBelow: provider.labelsBelow,
                      coloredLabels: provider.coloredLabels,
                      measuresPerRow: provider.measuresPerRow,
                    ),
            ),

            // Navigation controls
            _NavigationBar(
              onPrevious: _currentNoteIndex > 0 ? _previous : null,
              onNext: _currentNoteIndex < _notes.length - 1 ? _advance : null,
              onMicToggle: _toggleMic,
              micActive: _micActive,
            ),
          ],
        ),
      ),
    ),
  );
}
}

/// Shows the current note in a large, prominent card.
class _CurrentNoteCard extends StatelessWidget {
  final MusicNote note;
  final bool showSolfege;
  final int noteIndex;
  final int total;
  final String detectedNote;
  final bool isKeyboardInput;
  final String lastPhysicalKey;
  final String targetNoteName;
  final Map<String, String> keyboardOverrides;

  const _CurrentNoteCard({
    required this.note,
    required this.showSolfege,
    required this.noteIndex,
    required this.total,
    required this.detectedNote,
    required this.isKeyboardInput,
    required this.lastPhysicalKey,
    required this.targetNoteName,
    required this.keyboardOverrides,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect = detectedNote.isNotEmpty &&
        (MusicConstants.noteNameToMidi(detectedNote) -
                    MusicConstants.noteNameToMidi(targetNoteName))
                .abs() <=
            1;

    final solfege = MusicConstants.stepToSolfege[note.step] ?? note.step;
    final keyboardHint = keyboardOverrides[targetNoteName];
    final cleanHint = KeyboardUtils.formatForDisplay(keyboardHint);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Play now:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      showSolfege ? note.solfegeName : note.letterName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '($solfege)${targetNoteName != note.letterName ? " (Tuned $targetNoteName)" : ""}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    if (cleanHint != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Theme.of(context).dividerColor),
                        ),
                        child: Text(
                          cleanHint,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (detectedNote.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCorrect
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isCorrect ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    isKeyboardInput
                        ? 'Key: $lastPhysicalKey'
                        : 'Hearing',
                    style: TextStyle(
                      fontSize: 10,
                      color: isCorrect ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    detectedNote,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? Colors.green : Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NavigationBar extends StatelessWidget {
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onMicToggle;
  final bool micActive;

  const _NavigationBar({
    this.onPrevious,
    this.onNext,
    this.onMicToggle,
    required this.micActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous),
            onPressed: onPrevious,
            tooltip: 'Previous note',
          ),
          FloatingActionButton(
            onPressed: onMicToggle,
            backgroundColor: micActive ? Colors.green : null,
            mini: false,
            child: Icon(micActive ? Icons.mic : Icons.mic_off),
          ),
          IconButton(
            icon: const Icon(Icons.skip_next),
            onPressed: onNext,
            tooltip: 'Next note',
          ),
        ],
      ),
    );
  }
}
