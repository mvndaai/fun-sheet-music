import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/models/instrument_profile.dart'; // For kNoteKeys
import '../music_kit/models/sound_profile.dart' show SoundProfile, WaveformType;
import '../providers/sound_provider.dart';
import '../services/tone_player.dart';
import '../platform/platform.dart' as platform;
import '../widgets/name_icon_emoji_dialog.dart';
import '../main.dart' show showToast;

class SoundSetupScreen extends StatefulWidget {
  final SoundProfile profile;

  const SoundSetupScreen({
    super.key,
    required this.profile,
  });

  @override
  State<SoundSetupScreen> createState() => _SoundSetupScreenState();
}

class _SoundSetupScreenState extends State<SoundSetupScreen> {
  int? _selectedOctave;

  late Map<String, String> _noteSounds;
  late String _name;
  late String? _icon;
  late String? _emoji;
  late WaveformType _waveform;

  final platform.PlatformAudioRecorder _audioRecorder = platform.createAudioRecorder();
  final TonePlayer _tonePlayer = TonePlayer();

  String? _pendingNote;
  bool _isActionActive = false;

  @override
  void initState() {
    super.initState();
    _noteSounds = Map.from(widget.profile.noteSounds);
    _name = widget.profile.name;
    _icon = widget.profile.icon;
    _emoji = widget.profile.emoji;
    _waveform = widget.profile.waveform;
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _tonePlayer.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.profile.isBuiltIn) return;

    final provider = context.read<SoundProvider>();
    final updated = widget.profile.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      noteSounds: _noteSounds,
      waveform: _waveform,
    );
    provider.updateProfile(updated);
  }

  Future<void> _editInfo() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => NameIconEmojiDialog(
        initialName: _name,
        initialIcon: _icon,
        initialEmoji: _emoji,
        title: 'Sound set info',
        nameHint: 'e.g. My Custom Sounds',
      ),
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

  Future<void> _toggleRecording(String note) async {
    final noteKey = _getMappingKey(note);
    if (_isActionActive) {
      final key = await _audioRecorder.stopRecording();
      if (!mounted) return;
      setState(() {
        if (key != null && _pendingNote != null) _noteSounds[noteKey] = key;
        _isActionActive = false;
        _pendingNote = null;
      });
      _save();
    } else {
      try {
        await _audioRecorder.startRecording(widget.profile.id, noteKey);
        if (!mounted) return;
        setState(() {
          _pendingNote = note;
          _isActionActive = true;
        });
      } catch (e) {
        showToast('Failed: $e', isError: true);
      }
    }
  }

  String _getMappingKey(String step) => _selectedOctave != null ? '$step$_selectedOctave' : step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: widget.profile.isBuiltIn ? null : _editInfo,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_emoji ?? '🔊', style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Flexible(child: Text(_name, overflow: TextOverflow.ellipsis)),
              if (!widget.profile.isBuiltIn) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.edit, size: 14, color: Colors.grey)),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Column(
            children: [
              if (widget.profile.isBuiltIn)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Built-in sound sets cannot be modified.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
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
            child: Column(
              children: [
                Text(widget.profile.isBuiltIn ? 'Viewing preset configuration.' : 'Record custom sounds for ${_selectedOctave != null ? 'Octave $_selectedOctave' : 'Default settings'}.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                if (!widget.profile.isBuiltIn) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Synth Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      DropdownButton<WaveformType>(
                        value: _waveform,
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _waveform = v);
                            _save();
                          }
                        },
                        items: WaveformType.values.map((w) => DropdownMenuItem(
                          value: w,
                          child: Text(w.name[0].toUpperCase() + w.name.substring(1)),
                        )).toList(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: kNoteKeys.length,
              itemBuilder: (context, index) {
                final step = kNoteKeys[index];
                final noteKey = _getMappingKey(step);
                
                final hasCustomSound = _noteSounds.containsKey(noteKey);
                final isInherited = !hasCustomSound;
                
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
                        if (_noteSounds[noteKey] != null || SoundProfile.standard.noteSounds[noteKey] != null) 
                          IconButton(
                            icon: const Icon(Icons.play_arrow), 
                            onPressed: () {
                              final samplePath = _noteSounds[noteKey] ?? SoundProfile.standard.noteSounds[noteKey];
                              _tonePlayer.playNote(440, samplePath: samplePath, waveform: widget.profile.waveform);
                            },
                          ),
                        IconButton(
                          icon: Icon(_isActionActive && _pendingNote == step ? Icons.stop : Icons.mic), 
                          color: _isActionActive && _pendingNote == step ? Colors.red : null, 
                          onPressed: () => _toggleRecording(step),
                        ),
                        if (!isInherited && !_isActionActive) 
                          IconButton(
                            icon: const Icon(Icons.close, size: 20), 
                            onPressed: () {
                              setState(() => _noteSounds.remove(noteKey));
                              _save();
                            },
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getSubtitleText(String noteKey, bool isInherited, bool isHidden) {
    String prefix = isHidden ? '[HIDDEN] ' : '';
    final hasDefaultSound = SoundProfile.standard.noteSounds[noteKey] != null;
    if (isInherited && hasDefaultSound) {
      return '${prefix}Default sound';
    } else if (isInherited) {
      return '${prefix}No sound';
    }
    return '${prefix}Specific Recording';
  }
}
