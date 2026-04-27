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

enum SetupMode { visuals, visibility, tuning }

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

class _InstrumentSetupScreenState extends State<InstrumentSetupScreen> {
  late SetupMode _mode;
  int? _selectedOctave; // null means "Default"

  late Map<String, Color> _colors;
  late Map<String, Color> _octaveOverrides;
  late Set<String> _hiddenKeys;
  late Map<String, String> _tuningOverrides;
  late String _name;
  late String? _icon;
  late String? _emoji;

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
    _tuningOverrides = Map.from(widget.scheme.tuningOverrides);
    _name = widget.scheme.name;
    _icon = widget.scheme.icon;
    _emoji = widget.scheme.emoji;
  }

  @override
  void dispose() {
    _tonePlayer.dispose();
    _pitchSub?.cancel();
    _pitchService.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.scheme.isBuiltIn) return; // Prevent any modifications to built-in instruments
    
    final provider = context.read<InstrumentProvider>();
    final updated = widget.scheme.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      colors: _colors,
      octaveOverrides: _octaveOverrides,
      hiddenKeys: _hiddenKeys,
      tuningOverrides: _tuningOverrides,
    );

    provider.updateCustom(updated);
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

  // ── Tuning Logic ──────────────────────────────────────────────────────────

  Future<void> _toggleTuning(String note) async {
    if (_isActionActive) {
      await _pitchSub?.cancel();
      await _pitchService.stopListening();
      setState(() { _isActionActive = false; _pendingNote = null; _liveDetection = null; });
    } else {
      final ok = await _pitchService.startListening();
      if (!ok) return;
      setState(() { _pendingNote = note; _isActionActive = true; _liveDetection = null; });
      _pitchSub = _pitchService.noteStream.listen((detected) {
        if (detected.isNotEmpty) setState(() => _liveDetection = detected);
      });
    }
  }

  void _confirmTuning() {
    if (_pendingNote != null && _liveDetection != null) {
      final noteKey = _getMappingKey(_pendingNote!);
      setState(() { _tuningOverrides[noteKey] = _liveDetection!; });
      _save();
      _toggleTuning(_pendingNote!);
    }
  }

  // ── Visuals Logic ─────────────────────────────────────────────────────────

  Future<void> _pickColor(String note, Color currentColor) async {
    final picked = await showNoteColorPicker(context, current: currentColor, label: note);
    if (picked != null) {
      setState(() {
        if (_selectedOctave != null) _octaveOverrides['$note$_selectedOctave'] = picked;
        else _colors[note] = picked;
      });
      _save();
    }
  }

  void _toggleVisibility(String step) {
    setState(() {
      if (_hiddenKeys.contains(step)) _hiddenKeys.remove(step);
      else _hiddenKeys.add(step);
    });
    _save();
  }

  String _getMappingKey(String step) => _selectedOctave != null ? '$step$_selectedOctave' : step;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              if (widget.scheme.isBuiltIn)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Built-in instrument settings cannot be modified.', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SegmentedButton<SetupMode>(
                    segments: const [
                      ButtonSegment(value: SetupMode.visuals, icon: Icon(Icons.color_lens), label: Text('Colors')),
                      ButtonSegment(value: SetupMode.visibility, icon: Icon(Icons.visibility_off), label: Text('Hidden')),
                      ButtonSegment(value: SetupMode.tuning, icon: Icon(Icons.tune), label: Text('Tuning')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (val) {
                      if (_isActionActive) return;
                      setState(() {
                        _mode = val.first;
                        _pendingNote = null;
                        if (_mode == SetupMode.visibility) _selectedOctave = null;
                        else if (_selectedOctave == null && _mode != SetupMode.visuals) _selectedOctave = 4;
                      });
                    },
                  ),
                ),
              if (_mode != SetupMode.visibility && !widget.scheme.isBuiltIn)
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
            child: Text(widget.scheme.isBuiltIn ? 'Viewing preset configuration.' : _getInstructionText(), textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: kNoteKeys.length,
              itemBuilder: (context, index) {
                final step = kNoteKeys[index];
                final noteKey = _getMappingKey(step);
                final currentColor = _octaveOverrides[noteKey] ?? _colors[step] ?? widget.scheme.colorForNote(step, 0, octave: _selectedOctave, context: context);
                final isHidden = _hiddenKeys.contains(step);
                final isInherited = _selectedOctave != null && !_octaveOverrides.containsKey(noteKey) && _mode != SetupMode.tuning;

                return Opacity(
                  opacity: (isHidden && _mode != SetupMode.visibility) ? 0.4 : 1.0,
                  child: ListTile(
                    onTap: widget.scheme.isBuiltIn ? null : () {
                      if (_isActionActive) return;
                      if (_mode == SetupMode.visuals) _pickColor(step, currentColor);
                      else if (_mode == SetupMode.visibility) _toggleVisibility(step);
                      else setState(() => _pendingNote = _pendingNote == step ? null : step);
                    },
                    leading: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: currentColor, shape: BoxShape.circle),
                      child: Center(child: Text(step, style: TextStyle(color: currentColor.computeLuminance() > 0.35 ? Colors.black87 : Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                    ),
                    title: Row(
                      children: [
                        Text(noteKey, style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: (isHidden && _mode != SetupMode.visibility) ? TextDecoration.lineThrough : null,
                        )),
                        if (isHidden && _mode != SetupMode.visibility) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.visibility_off, size: 14, color: Colors.grey),
                        ],
                        if (_isActionActive && _pendingNote == step && _liveDetection != null) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                          const SizedBox(width: 8),
                          Text(_liveDetection!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 18)),
                        ]
                      ],
                    ),
                    subtitle: Text(_getSubtitleText(step, noteKey, currentColor, isHidden, isInherited)),
                    trailing: widget.scheme.isBuiltIn 
                      ? (isHidden ? const Icon(Icons.visibility_off, size: 20, color: Colors.grey) : null)
                      : (_mode == SetupMode.tuning 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isActionActive && _pendingNote == step && _liveDetection != null) IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: _confirmTuning),
                                IconButton(icon: Icon(_isActionActive && _pendingNote == step ? Icons.stop : Icons.tune), color: _isActionActive && _pendingNote == step ? Colors.green : null, onPressed: () => _toggleTuning(step)),
                              ],
                            )
                          : (_mode == SetupMode.visibility ? Switch(value: !isHidden, onChanged: (_) => _toggleVisibility(step)) : null)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _getInstructionText() {
    final octaveLabel = _selectedOctave != null ? 'Octave $_selectedOctave' : 'Default settings';
    switch (_mode) {
      case SetupMode.visuals: return 'Editing Colors for $octaveLabel.';
      case SetupMode.visibility: return 'Hide notes that your instrument cannot play.';
      case SetupMode.tuning: return 'Set tuning overrides for $octaveLabel.';
    }
  }

  String _getSubtitleText(String step, String noteKey, Color color, bool isHidden, bool isInherited) {
    String prefix = '';
    if (isHidden && _mode != SetupMode.visibility) {
      prefix = '[HIDDEN] ';
    }
    
    if (_mode == SetupMode.visuals) return '$prefix${isInherited ? 'Default Color: #${colorToHex(color)}' : 'Specific Color: #${colorToHex(color)}'}';
    if (_mode == SetupMode.visibility) return isHidden ? 'Hidden' : 'Visible';
    if (_mode == SetupMode.tuning) return '$prefix${_tuningOverrides[noteKey] != null ? 'Tuned to ${_tuningOverrides[noteKey]}' : 'Standard'}';
    return '';
  }
}
