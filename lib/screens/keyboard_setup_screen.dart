import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/models/instrument_profile.dart'; // For kNoteKeys
import '../music_kit/models/keyboard_profile.dart';
import '../providers/keyboard_provider.dart';
import '../music_kit/utils/music_constants.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../services/tone_player.dart';
import '../platform/platform.dart' as platform;
import 'instruments_screen.dart';

enum KeyboardSetupMode { keys, sounds }

class KeyboardSetupScreen extends StatefulWidget {
  final KeyboardProfile profile;
  final KeyboardSetupMode initialMode;

  const KeyboardSetupScreen({
    super.key,
    required this.profile,
    this.initialMode = KeyboardSetupMode.keys,
  });

  @override
  State<KeyboardSetupScreen> createState() => _KeyboardSetupScreenState();
}

class _KeyboardSetupScreenState extends State<KeyboardSetupScreen> {
  late KeyboardSetupMode _mode;
  int? _selectedOctave = 4;

  late Map<String, String> _keyboardOverrides;
  late Map<String, String> _noteSounds;
  late String _name;
  late String? _icon;
  late String? _emoji;

  final platform.PlatformAudioRecorder _audioRecorder = platform.createAudioRecorder();
  final TonePlayer _tonePlayer = TonePlayer();

  String? _pendingNote;
  bool _isActionActive = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _keyboardOverrides = Map.from(widget.profile.keyboardOverrides);
    _noteSounds = Map.from(widget.profile.noteSounds);
    _name = widget.profile.name;
    _icon = widget.profile.icon;
    _emoji = widget.profile.emoji;
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _tonePlayer.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.profile.isBuiltIn) return; // Prevent modifying built-in keyboards

    final provider = context.read<KeyboardProvider>();
    final updated = widget.profile.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      keyboardOverrides: _keyboardOverrides,
      noteSounds: _noteSounds,
    );
    provider.updateProfile(updated);
  }

  Future<void> _editInfo() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => NameIconEmojiDialog(initialName: _name, initialIcon: _icon, initialEmoji: _emoji),
    );
    if (result != null) {
      setState(() {
        _name = result['name']?.trim() ?? _name;
        _icon = result['icon']?.isNotEmpty == true ? result['icon'] : null;
        _emoji = result['emoji']?.isNotEmpty == true ? result['emoji'] : null;
      });
      _save();
    }
  }

  void _onKey(KeyEvent event) {
    if (_mode != KeyboardSetupMode.keys || _pendingNote == null || event is! KeyDownEvent) return;
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
        if (key != null && _pendingNote != null) _noteSounds[noteKey] = key;
        _isActionActive = false;
        _pendingNote = null;
      });
      _save();
    } else {
      try {
        await _audioRecorder.startRecording(widget.profile.id, noteKey);
        setState(() {
          _pendingNote = note;
          _isActionActive = true;
        });
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  String _getMappingKey(String step) => _selectedOctave != null ? '$step$_selectedOctave' : step;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKey(event);
        return _mode == KeyboardSetupMode.keys && _pendingNote != null ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: Scaffold(
        appBar: AppBar(
          title: InkWell(
            onTap: widget.profile.isBuiltIn ? null : _editInfo,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_emoji ?? '⌨️', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Flexible(child: Text(_name, overflow: TextOverflow.ellipsis)),
                if (!widget.profile.isBuiltIn) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.edit, size: 14, color: Colors.grey)),
              ],
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(100),
            child: Column(
              children: [
                if (widget.profile.isBuiltIn)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Built-in keyboard settings cannot be modified.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SegmentedButton<KeyboardSetupMode>(
                      segments: const [
                        ButtonSegment(value: KeyboardSetupMode.keys, icon: Icon(Icons.keyboard), label: Text('Keys')),
                        ButtonSegment(value: KeyboardSetupMode.sounds, icon: Icon(Icons.mic), label: Text('Sounds')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (val) {
                        if (_isActionActive) return;
                        setState(() { _mode = val.first; _pendingNote = null; });
                      },
                    ),
                  ),
                if (!widget.profile.isBuiltIn)
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
                        setState(() { _selectedOctave = val.first; _pendingNote = null; });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.profile.isBuiltIn ? 'Viewing preset configuration.' : _getInstructionText(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: kNoteKeys.length,
                itemBuilder: (context, index) {
                  final step = kNoteKeys[index];
                  final noteKey = _getMappingKey(step);
                  final isInherited = _selectedOctave != null && !_keyboardOverrides.containsKey(noteKey) && !_noteSounds.containsKey(noteKey);
                  
                  // Get current instrument color for this note
                  final instrument = context.watch<InstrumentProvider>().activeScheme;
                  final isHidden = instrument.hiddenKeys.contains(step);
                  final color = instrument.colorForNote(step, 0, octave: _selectedOctave, context: context);
                  final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

                  return Opacity(
                    opacity: isHidden ? 0.4 : 1.0,
                    child: ListTile(
                      onTap: widget.profile.isBuiltIn ? null : () {
                        if (_isActionActive) return;
                        setState(() => _pendingNote = _pendingNote == step ? null : step);
                      },
                      selected: _pendingNote == step,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Center(
                          child: Text(
                            step,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(noteKey, style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isHidden ? TextDecoration.lineThrough : null,
                          )),
                          if (isHidden) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.visibility_off, size: 14, color: Colors.grey),
                          ],
                        ],
                      ),
                      subtitle: Text(_getSubtitleText(noteKey, isInherited, isHidden)),
                      trailing: widget.profile.isBuiltIn ? null : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_mode == KeyboardSetupMode.sounds) ...[
                            if (_noteSounds[noteKey] != null) IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _tonePlayer.playNote(440, samplePath: _noteSounds[noteKey])),
                            IconButton(icon: Icon(_isActionActive && _pendingNote == step ? Icons.stop : Icons.mic), color: _isActionActive && _pendingNote == step ? Colors.red : null, onPressed: () => _toggleRecording(step)),
                          ],
                          if (!isInherited && !_isActionActive) IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () {
                            setState(() {
                              if (_mode == KeyboardSetupMode.keys) _keyboardOverrides.remove(noteKey);
                              if (_mode == KeyboardSetupMode.sounds) _noteSounds.remove(noteKey);
                            });
                            _save();
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInstructionText() {
    final octaveLabel = _selectedOctave != null ? 'Octave $_selectedOctave' : 'Default settings';
    if (_mode == KeyboardSetupMode.keys) return _pendingNote == null ? 'Tap a note to map it for $octaveLabel.' : 'Press a key for $_pendingNote...';
    return 'Record custom sounds for $octaveLabel.';
  }

  String _getSubtitleText(String noteKey, bool isInherited, bool isHidden) {
    String prefix = isHidden ? '[HIDDEN] ' : '';
    if (_mode == KeyboardSetupMode.keys) {
      final mapping = _keyboardOverrides[noteKey] ?? KeyboardProfile.standard.keyboardOverrides[noteKey];
      return '$prefix${isInherited ? 'Default: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}' : 'Specific: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}'}';
    }
    return '$prefix${isInherited ? 'Default sound' : 'Specific Recording'}';
  }
}
