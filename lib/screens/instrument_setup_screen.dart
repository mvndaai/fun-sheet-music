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
import '../widgets/note_color_picker.dart';
import 'instruments_screen.dart';

enum SetupMode { visuals, visibility, tuning, keyboard, sounds }

class InstrumentSetupScreen extends StatefulWidget {
  final InstrumentProfile scheme;
  final SetupMode initialMode;

  const InstrumentSetupScreen({
    super.key,
    required this.scheme,
    this.initialMode = SetupMode.visuals,
  });

  @override
  State<InstrumentSetupScreen> createState() => _InstrumentSetupScreenState();
}

class _InstrumentSetupScreenState extends State<InstrumentSetupScreen> with SingleTickerProviderStateMixin {
  late SetupMode _mode;
  int? _selectedOctave; // null means "Default"

  late Map<String, Color> _colors;
  late Map<String, Color> _octaveOverrides;
  late Set<String> _hiddenKeys;
  late Map<String, String> _keyboardOverrides;
  late Map<String, String> _noteSounds;
  late Map<String, String> _tuningOverrides;
  late String _name;
  late String? _icon;
  late String? _emoji;

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
    _mode = widget.scheme.isBuiltIn && widget.initialMode == SetupMode.visuals
        ? SetupMode.tuning
        : widget.initialMode;
    
    _selectedOctave = (_mode == SetupMode.visuals || _mode == SetupMode.visibility) ? null : 4;

    _colors = Map.from(widget.scheme.colors);
    _octaveOverrides = Map.from(widget.scheme.octaveOverrides);
    _hiddenKeys = Set.from(widget.scheme.hiddenKeys);
    _keyboardOverrides = Map.from(widget.scheme.keyboardOverrides);
    _noteSounds = Map.from(widget.scheme.noteSounds);
    _tuningOverrides = Map.from(widget.scheme.tuningOverrides);
    _name = widget.scheme.name;
    _icon = widget.scheme.icon;
    _emoji = widget.scheme.emoji;
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
    final updated = widget.scheme.withIconOnly(
      icon: _icon,
      emoji: _emoji,
    ).copyWith(
      name: _name,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      hiddenKeys: _hiddenKeys,
      keyboardOverrides: _keyboardOverrides,
      noteSounds: _noteSounds,
      tuningOverrides: _tuningOverrides,
    );

    if (widget.scheme.isBuiltIn) {
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
        case SetupMode.visuals:
        case SetupMode.visibility:
          break;
      }
    } else {
      provider.updateCustom(updated);
    }
  }

  Future<void> _editInfo() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => NameIconEmojiDialog(
        initialName: _name,
        initialIcon: _icon,
        initialEmoji: _emoji,
      ),
    );
    if (result != null) {
      final name = result['name'] ?? '';
      final icon = result['icon'] ?? '';
      final emoji = result['emoji'] ?? '';
      setState(() {
        _name = name.trim();
        _icon = icon.isNotEmpty ? icon.trim() : null;
        _emoji = emoji.isNotEmpty ? emoji.trim() : null;
      });
      _save();
    }
  }

  void _onKey(KeyEvent event) {
    if (_mode != SetupMode.keyboard || _pendingNote == null || event is! KeyDownEvent) return;

    final mapping = KeyboardUtils.getMappingName(event);
    final noteKey = _getMappingKey(_pendingNote!);

    setState(() {
      _keyboardOverrides.forEach((note, m) {
        if (m == mapping && note != noteKey) _keyboardOverrides[note] = '';
      });
      _keyboardOverrides[noteKey] = mapping;
      _pendingNote = null;
    });
    _save();
  }

  Future<void> _toggleRecording(String note) async {
    final noteKey = _getMappingKey(note);
    if (_isActionActive) {
      final key = await _audioRecorder.stopRecording();
      setState(() {
        if (key != null && _pendingNote != null) {
          _noteSounds[noteKey] = key;
        }
        _isActionActive = false;
        _pendingNote = null;
      });
      _save();
    } else {
      try {
        await _audioRecorder.startRecording(widget.scheme.id, noteKey);
        setState(() {
          _pendingNote = note;
          _isActionActive = true;
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to start recording: $e')),
          );
        }
      }
    }
  }

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
      final noteKey = _getMappingKey(_pendingNote!);
      setState(() {
        _tuningOverrides[noteKey] = _liveDetection!;
      });
      _save();
      _toggleTuning(_pendingNote!);
    }
  }

  Future<void> _pickColor(String note, Color currentColor) async {
    final picked = await showNoteColorPicker(context, current: currentColor, label: note);
    if (picked != null) {
      setState(() {
        if (_selectedOctave != null) {
          _octaveOverrides['$note$_selectedOctave'] = picked;
        } else {
          _colors[note] = picked;
        }
      });
      _save();
    }
  }

  void _toggleVisibility(String step) {
    setState(() {
      if (_hiddenKeys.contains(step)) {
        _hiddenKeys.remove(step);
      } else {
        _hiddenKeys.add(step);
      }
    });
    _save();
  }

  String _getMappingKey(String step) {
    return _selectedOctave != null ? '$step$_selectedOctave' : step;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKey(event);
        return _mode == SetupMode.keyboard && _pendingNote != null ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: widget.scheme.isBuiltIn ? null : _editInfo,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InstrumentIcon(scheme: widget.scheme.copyWith(name: _name, icon: _icon, emoji: _emoji), size: 24),
                const SizedBox(width: 12),
                Flexible(child: Text(_name, overflow: TextOverflow.ellipsis)),
                if (!widget.scheme.isBuiltIn) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.edit, size: 14, color: Colors.grey)),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(_mode == SetupMode.visibility ? 50 : 100),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<SetupMode>(
                      segments: [
                        if (!widget.scheme.isBuiltIn) const ButtonSegment(value: SetupMode.visuals, icon: Icon(Icons.color_lens), label: Text('Colors')),
                        const ButtonSegment(value: SetupMode.visibility, icon: Icon(Icons.visibility_off), label: Text('Hidden')),
                        const ButtonSegment(value: SetupMode.tuning, icon: Icon(Icons.tune), label: Text('Tuning')),
                        const ButtonSegment(value: SetupMode.keyboard, icon: Icon(Icons.keyboard), label: Text('Keys')),
                        const ButtonSegment(value: SetupMode.sounds, icon: Icon(Icons.mic), label: Text('Sounds')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (val) {
                        if (_isActionActive) return;
                        setState(() {
                          _mode = val.first;
                          _pendingNote = null;
                          if (_mode == SetupMode.visibility) {
                            _selectedOctave = null;
                          } else if (_selectedOctave == null && _mode != SetupMode.visuals) {
                            _selectedOctave = 4;
                          }
                        });
                      },
                    ),
                  ),
                ),
                if (_mode != SetupMode.visibility)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SegmentedButton<int?>(
                      segments: const [
                        ButtonSegment(value: null, label: Text('Default')),
                        ButtonSegment(value: 3, label: Text('3')),
                        ButtonSegment(value: 4, label: Text('4')),
                        ButtonSegment(value: 5, label: Text('5')),
                        ButtonSegment(value: 6, label: Text('6')),
                      ],
                      selected: {_selectedOctave},
                      onSelectionChanged: (val) {
                        if (_isActionActive) return;
                        setState(() {
                          _selectedOctave = val.first;
                          _pendingNote = null;
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            _buildInstructions(),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: kNoteKeys.length,
                itemBuilder: (context, index) {
                  final step = kNoteKeys[index];
                  final noteKey = _getMappingKey(step);
                  final isOctaveSelected = _selectedOctave != null;

                  // Determine inheritance for current octave
                  final bool isColorInherited = isOctaveSelected && !_octaveOverrides.containsKey(noteKey);
                  final bool isKeyInherited = isOctaveSelected && !_keyboardOverrides.containsKey(noteKey);
                  final bool isSoundInherited = isOctaveSelected && !_noteSounds.containsKey(noteKey);
                  final bool isTuningInherited = isOctaveSelected && !_tuningOverrides.containsKey(noteKey);

                  final currentColor = _octaveOverrides[noteKey] ?? _colors[step] ?? widget.scheme.colorForNote(step, 0, octave: _selectedOctave, context: context);
                  final isHidden = _hiddenKeys.contains(step);

                  return _NoteConfigTile(
                    note: noteKey,
                    mode: _mode,
                    scheme: widget.scheme,
                    color: currentColor,
                    isHidden: isHidden,
                    keyboardMapping: _keyboardOverrides[noteKey],
                    soundPath: _noteSounds[noteKey],
                    tunedTo: _tuningOverrides[noteKey],
                    isInherited: (_mode == SetupMode.visuals && isColorInherited) ||
                                 (_mode == SetupMode.keyboard && isKeyInherited) ||
                                 (_mode == SetupMode.sounds && isSoundInherited) ||
                                 (_mode == SetupMode.tuning && isTuningInherited),
                    isPending: _pendingNote == step,
                    isActionActive: _isActionActive && _pendingNote == step,
                    liveDetection: _pendingNote == step ? _liveDetection : null,
                    onTap: () {
                      if (_isActionActive) return;
                      if (_mode == SetupMode.visuals) {
                        _pickColor(step, currentColor);
                      } else if (_mode == SetupMode.visibility) {
                        _toggleVisibility(step);
                      } else {
                        setState(() => _pendingNote = _pendingNote == step ? null : step);
                      }
                    },
                    onAction: () {
                      if (_mode == SetupMode.sounds) _toggleRecording(step);
                      if (_mode == SetupMode.tuning) _toggleTuning(step);
                    },
                    onToggleVisibility: () => _toggleVisibility(step),
                    onConfirmTuning: _confirmTuning,
                    onPlay: () {
                      final midi = MusicConstants.noteNameToMidi(_selectedOctave != null ? noteKey : '${step}4');
                      if (midi >= 0) {
                        _tonePlayer.playNote(MusicConstants.midiToFrequency(midi), samplePath: widget.scheme.getSamplePath(noteKey));
                      }
                    },
                    onClear: () {
                      setState(() {
                        if (_mode == SetupMode.keyboard) _keyboardOverrides.remove(noteKey);
                        if (_mode == SetupMode.sounds) _noteSounds.remove(noteKey);
                        if (_mode == SetupMode.tuning) _tuningOverrides.remove(noteKey);
                        if (_mode == SetupMode.visuals && _selectedOctave != null) _octaveOverrides.remove(noteKey);
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
    final octaveLabel = _selectedOctave != null ? 'Octave $_selectedOctave' : 'Default settings';
    switch (_mode) {
      case SetupMode.visuals:
        text = 'Editing Colors for $octaveLabel.';
        break;
      case SetupMode.visibility:
        text = 'Hide notes that your instrument cannot play.';
        break;
      case SetupMode.keyboard:
        text = _pendingNote == null ? 'Tap a note to map it for $octaveLabel.' : 'Press a key for $_pendingNote...';
        break;
      case SetupMode.sounds:
        text = 'Record custom sounds for $octaveLabel.';
        break;
      case SetupMode.tuning:
        text = 'Set tuning overrides for $octaveLabel.';
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
  final Color color;
  final bool isHidden;
  final String? keyboardMapping;
  final String? soundPath;
  final String? tunedTo;
  final bool isInherited;
  final bool isPending;
  final bool isActionActive;
  final String? liveDetection;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final VoidCallback? onToggleVisibility;
  final VoidCallback onConfirmTuning;
  final VoidCallback onPlay;
  final VoidCallback onClear;

  const _NoteConfigTile({
    required this.note,
    required this.mode,
    required this.scheme,
    required this.color,
    required this.isHidden,
    this.keyboardMapping,
    this.soundPath,
    this.tunedTo,
    required this.isInherited,
    required this.isPending,
    required this.isActionActive,
    this.liveDetection,
    required this.onTap,
    required this.onAction,
    this.onToggleVisibility,
    required this.onConfirmTuning,
    required this.onPlay,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;
    String subtitle = '';
    Widget? trailing;

    if (mode == SetupMode.visuals) {
      subtitle = isInherited ? 'Default Color: #${colorToHex(color)}' : 'Specific Color: #${colorToHex(color)}';
    } else if (mode == SetupMode.visibility) {
      subtitle = isHidden ? 'Hidden' : 'Visible';
      trailing = Switch(value: !isHidden, onChanged: (_) => onToggleVisibility?.call());
    } else if (mode == SetupMode.keyboard) {
      if (isPending) {
        subtitle = 'WAITING FOR KEY...';
      } else if (keyboardMapping?.isNotEmpty == true) {
        subtitle = 'Specific: ${KeyboardUtils.formatForDisplay(keyboardMapping!)}';
      } else {
        // Find if inherited from the base step map or the standard profile
        final baseStep = note.replaceAll(RegExp(r'\d'), '');
        final userDefaultMapping = scheme.keyboardOverrides[baseStep];
        final standardMapping = scheme.effectiveKeyboardOverrides[note];
        
        if (userDefaultMapping?.isNotEmpty == true) {
          subtitle = 'Default: ${KeyboardUtils.formatForDisplay(userDefaultMapping!)}';
        } else if (standardMapping?.isNotEmpty == true) {
          subtitle = 'Standard: ${KeyboardUtils.formatForDisplay(standardMapping!)}';
        } else {
          subtitle = 'Not mapped';
        }
      }
    } else if (mode == SetupMode.sounds) {
      subtitle = isActionActive ? 'RECORDING...' : (soundPath?.isNotEmpty == true ? 'Specific Recording' : 'Default');
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (soundPath?.isNotEmpty == true) IconButton(icon: const Icon(Icons.play_arrow), onPressed: onPlay),
          IconButton(icon: Icon(isActionActive ? Icons.stop : Icons.mic), color: isActionActive ? Colors.red : null, onPressed: onAction),
        ],
      );
    } else if (mode == SetupMode.tuning) {
      subtitle = isActionActive ? (liveDetection ?? 'Listening...') : (tunedTo?.isNotEmpty == true ? 'Specific: $tunedTo' : 'Standard');
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActionActive && liveDetection != null) IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: onConfirmTuning),
          IconButton(icon: Icon(isActionActive ? Icons.stop : Icons.tune), color: isActionActive ? Colors.green : null, onPressed: onAction),
        ],
      );
    }

    return Opacity(
      opacity: isHidden ? 0.5 : 1.0,
      child: ListTile(
        selected: isPending,
        onTap: isHidden && (mode != SetupMode.visuals && mode != SetupMode.visibility) ? null : onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: Text(note, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ),
        title: Row(
          children: [
            Text(note, style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isActionActive && liveDetection != null) ...[
               const SizedBox(width: 12),
               const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
               const SizedBox(width: 8),
               Text(liveDetection!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
            ]
          ],
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: isActionActive || isPending ? Theme.of(context).primaryColor : null,
            fontStyle: isInherited ? FontStyle.italic : null,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing,
            if (!isInherited && !isActionActive && mode != SetupMode.visibility)
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: onClear),
          ],
        ),
      ),
    );
  }
}
