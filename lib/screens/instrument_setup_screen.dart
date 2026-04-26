import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../services/tone_player.dart';
import '../services/pitch_detection_service.dart';
import '../platform/platform.dart' as platform;

enum SetupMode { keyboard, sounds, tuning }

class InstrumentSetupScreen extends StatefulWidget {
  final InstrumentProfile scheme;
  final SetupMode initialMode;

  const InstrumentSetupScreen({
    super.key,
    required this.scheme,
    this.initialMode = SetupMode.tuning,
  });

  @override
  State<InstrumentSetupScreen> createState() => _InstrumentSetupScreenState();
}

class _InstrumentSetupScreenState extends State<InstrumentSetupScreen> with SingleTickerProviderStateMixin {
  late SetupMode _mode;
  late Map<String, String> _keyboardOverrides;
  late Map<String, String> _noteSounds;
  late Map<String, String> _tuningOverrides;

  final platform.PlatformAudioRecorder _audioRecorder = platform.createAudioRecorder();
  final TonePlayer _tonePlayer = TonePlayer();
  final PitchDetectionService _pitchService = PitchDetectionService();
  StreamSubscription<String>? _pitchSub;

  String? _pendingNote;
  bool _isActionActive = false;
  String? _liveDetection;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _keyboardOverrides = Map.from(widget.scheme.keyboardOverrides);
    _noteSounds = Map.from(widget.scheme.noteSounds);
    _tuningOverrides = Map.from(widget.scheme.tuningOverrides);
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _tonePlayer.dispose();
    _pitchSub?.cancel();
    _pitchService.dispose();
    super.dispose();
  }

  void _save() {
    final provider = context.read<InstrumentProvider>();
    switch (_mode) {
      case SetupMode.keyboard:
        provider.updateKeyboardOverrides(widget.scheme.id, _keyboardOverrides);
        break;
      case SetupMode.sounds:
        provider.updateNoteSounds(widget.scheme.id, _noteSounds);
        break;
      case SetupMode.tuning:
        provider.updateTuningOverrides(widget.scheme.id, _tuningOverrides);
        break;
    }
  }

  // ── Keyboard Logic ────────────────────────────────────────────────────────

  void _onKey(KeyEvent event) {
    if (_mode != SetupMode.keyboard || _pendingNote == null || event is! KeyDownEvent) return;

    final mapping = KeyboardUtils.getMappingName(event);
    setState(() {
      // Clear existing mapping for this key if it exists elsewhere
      _keyboardOverrides.forEach((note, m) {
        if (m == mapping && note != _pendingNote) _keyboardOverrides[note] = '';
      });
      _keyboardOverrides[_pendingNote!] = mapping;
      _pendingNote = null;
    });
    _save();
  }

  // ── Sound Logic ───────────────────────────────────────────────────────────

  Future<void> _toggleRecording(String note) async {
    if (_isActionActive) {
      // Stop recording
      final key = await _audioRecorder.stopRecording();
      setState(() {
        if (key != null && _pendingNote != null) {
          _noteSounds[_pendingNote!] = key;
        }
        _isActionActive = false;
        _pendingNote = null;
      });
      _save();
    } else {
      // Start recording
      try {
        await _audioRecorder.startRecording(widget.scheme.id, note);
        setState(() {
          _pendingNote = note;
          _isActionActive = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to start recording: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  // ── Tuning Logic ──────────────────────────────────────────────────────────

  Future<void> _toggleTuning(String note) async {
    if (_isActionActive) {
      await _pitchSub?.cancel();
      await _pitchService.stopListening();
      setState(() {
        _isActionActive = false;
        _pendingNote = null;
        _liveDetection = null;
      });
    } else {
      final ok = await _pitchService.startListening();
      if (!ok) return;
      setState(() {
        _pendingNote = note;
        _isActionActive = true;
        _liveDetection = null;
      });
      _pitchSub = _pitchService.noteStream.listen((detected) {
        if (detected.isNotEmpty) {
          setState(() => _liveDetection = detected);
        }
      });
    }
  }

  void _confirmTuning() {
    if (_pendingNote != null && _liveDetection != null) {
      setState(() {
        _tuningOverrides[_pendingNote!] = _liveDetection!;
      });
      _save();
      _toggleTuning(_pendingNote!); // Stop listening
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final Set<String> allNotes = {};

    // Add enabled notes from standard octave range (skip disabled keys)
    for (int octave = 3; octave <= 6; octave++) {
      for (final note in kNoteKeys) {
        if (!widget.scheme.disabledKeys.contains(note)) {
          allNotes.add('$note$octave');
        }
      }
    }
    
    // Add notes with explicit overrides (even if they're disabled keys)
    allNotes.addAll(_keyboardOverrides.keys);
    allNotes.addAll(_noteSounds.keys);
    allNotes.addAll(_tuningOverrides.keys);

    final enabledNotes = <String>[];
    final disabledNotes = <String>[];

    for (final note in allNotes) {
      final step = note.replaceAll(RegExp(r'\d'), '');
      if (widget.scheme.disabledKeys.contains(step)) {
        disabledNotes.add(note);
      } else {
        enabledNotes.add(note);
      }
    }

    int midiSort(String a, String b) => MusicConstants.noteNameToMidi(a).compareTo(MusicConstants.noteNameToMidi(b));
    enabledNotes.sort(midiSort);
    disabledNotes.sort(midiSort);

    final displayNotes = [
      ...enabledNotes,
      if (disabledNotes.isNotEmpty) '---DIVIDER---',
      ...disabledNotes,
    ];

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKey(event);
        return _mode == SetupMode.keyboard && _pendingNote != null ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${widget.scheme.name} Setup'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(50),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<SetupMode>(
                segments: const [
                  ButtonSegment(value: SetupMode.tuning, icon: Icon(Icons.tune), label: Text('Tuning')),
                  ButtonSegment(value: SetupMode.keyboard, icon: Icon(Icons.keyboard), label: Text('Keys')),
                  ButtonSegment(value: SetupMode.sounds, icon: Icon(Icons.mic), label: Text('Sounds')),
                ],
                selected: {_mode},
                onSelectionChanged: (val) {
                  if (_isActionActive) return;
                  setState(() {
                    _mode = val.first;
                    _pendingNote = null;
                  });
                },
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            _buildInstructions(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: displayNotes.length,
                itemBuilder: (context, index) {
                  final note = displayNotes[index];

                  if (note == '---DIVIDER---') {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(thickness: 2, height: 32),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text(
                            'DISABLED KEYS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return _NoteConfigTile(
                    note: note,
                    mode: _mode,
                    scheme: widget.scheme,
                    keyboardMapping: _keyboardOverrides[note],
                    soundPath: _noteSounds[note],
                    tunedTo: _tuningOverrides[note],
                    isPending: _pendingNote == note,
                    isActionActive: _isActionActive && _pendingNote == note,
                    liveDetection: _pendingNote == note ? _liveDetection : null,
                    onTap: () {
                      if (_isActionActive) return;
                      setState(() => _pendingNote = _pendingNote == note ? null : note);
                    },
                    onAction: () {
                      if (_mode == SetupMode.sounds) _toggleRecording(note);
                      if (_mode == SetupMode.tuning) _toggleTuning(note);
                    },
                    onConfirmTuning: _confirmTuning,
                    onPlay: () {
                      final midi = MusicConstants.noteNameToMidi(note);
                      if (midi >= 0) {
                        _tonePlayer.playNote(MusicConstants.midiToFrequency(midi), samplePath: widget.scheme.getSamplePath(note));
                      }
                    },
                    onClear: () {
                      setState(() {
                        if (_mode == SetupMode.keyboard) _keyboardOverrides.remove(note);
                        if (_mode == SetupMode.sounds) _noteSounds.remove(note);
                        if (_mode == SetupMode.tuning) _tuningOverrides.remove(note);
                      });
                      _save();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    String text = '';
    switch (_mode) {
      case SetupMode.keyboard:
        text = _pendingNote == null ? 'Tap a note to map it to a keyboard key.' : 'Press a key for $_pendingNote...';
        break;
      case SetupMode.sounds:
        text = 'Record custom sounds for each note.';
        break;
      case SetupMode.tuning:
        text = 'Tell the app what note your instrument actually plays.';
        break;
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
    );
  }
}

class _NoteConfigTile extends StatelessWidget {
  final String note;
  final SetupMode mode;
  final InstrumentProfile scheme;
  final String? keyboardMapping;
  final String? soundPath;
  final String? tunedTo;
  final bool isPending;
  final bool isActionActive;
  final String? liveDetection;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback onConfirmTuning;
  final VoidCallback onPlay;
  final VoidCallback onClear;

  const _NoteConfigTile({
    required this.note,
    required this.mode,
    required this.scheme,
    this.keyboardMapping,
    this.soundPath,
    this.tunedTo,
    required this.isPending,
    required this.isActionActive,
    this.liveDetection,
    required this.onTap,
    required this.onAction,
    required this.onConfirmTuning,
    required this.onPlay,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final step = note.replaceAll(RegExp(r'\d'), '');
    final isDisabled = scheme.disabledKeys.contains(step);
    final color = scheme.colorForNote(step, 0, octave: int.tryParse(note.replaceAll(RegExp(r'\D'), '')), context: context);
    final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

    String subtitle = '';
    Widget? trailing;

    if (mode == SetupMode.keyboard) {
      if (isPending) {
        subtitle = 'WAITING FOR KEY...';
      } else if (keyboardMapping?.isNotEmpty == true) {
        subtitle = KeyboardUtils.formatForDisplay(keyboardMapping!);
      } else {
        // Check for default from Standard profile
        final defaultMapping = scheme.effectiveKeyboardOverrides[note];
        if (defaultMapping != null && defaultMapping.isNotEmpty) {
          subtitle = 'Default: ${KeyboardUtils.formatForDisplay(defaultMapping)}';
        } else {
          subtitle = 'Not mapped';
        }
      }
    } else if (mode == SetupMode.sounds) {
      subtitle = isActionActive ? 'RECORDING...' : (soundPath?.isNotEmpty == true ? 'Recorded' : 'Default');
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (soundPath?.isNotEmpty == true) IconButton(icon: const Icon(Icons.play_arrow), onPressed: onPlay),
          IconButton(icon: Icon(isActionActive ? Icons.stop : Icons.mic), color: isActionActive ? Colors.red : null, onPressed: onAction),
        ],
      );
    } else if (mode == SetupMode.tuning) {
      subtitle = isActionActive ? (liveDetection ?? 'Listening...') : (tunedTo?.isNotEmpty == true ? 'Tuned to $tunedTo' : 'Standard');
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActionActive && liveDetection != null) IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: onConfirmTuning),
          IconButton(icon: Icon(isActionActive ? Icons.stop : Icons.tune), color: isActionActive ? Colors.green : null, onPressed: onAction),
        ],
      );
    }

    return Opacity(
      opacity: isDisabled ? 0.5 : 1.0,
      child: ListTile(
        selected: isPending,
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(note, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
        title: Text(note, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isActionActive || isPending ? Theme.of(context).primaryColor : null,
            fontStyle: subtitle.startsWith('Default:') ? FontStyle.italic : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing,
            if ((keyboardMapping?.isNotEmpty == true || (soundPath?.isNotEmpty == true) || (tunedTo?.isNotEmpty == true)) && !isActionActive)
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear),
          ],
        ),
      ),
    );
  }
}
