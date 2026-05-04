import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/models/instrument_profile.dart'; // For kNoteKeys
import '../music_kit/models/keyboard_profile.dart';
import '../providers/keyboard_provider.dart';
import '../music_kit/utils/keyboard_utils.dart';
import '../widgets/name_icon_emoji_dialog.dart';

enum KeyboardSetupMode { keys, editor }

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
  int? _selectedOctave;

  late Map<String, String> _keyboardOverrides;
  late Map<String, String> _editorShortcuts;
  late String _name;
  late String? _icon;
  late String? _emoji;

  String? _pendingNote;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _keyboardOverrides = Map.from(widget.profile.keyboardOverrides);
    _editorShortcuts = Map.from(widget.profile.editorShortcuts);
    _name = widget.profile.name;
    _icon = widget.profile.icon;
    _emoji = widget.profile.emoji;
  }

  void _save() {
    if (widget.profile.isBuiltIn) return;

    final provider = context.read<KeyboardProvider>();
    final updated = widget.profile.copyWith(
      name: _name,
      icon: _icon,
      emoji: _emoji,
      keyboardOverrides: _keyboardOverrides,
      editorShortcuts: _editorShortcuts,
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
        title: 'Keyboard info',
        nameHint: 'e.g. My Custom Keyboard',
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

  void _onKey(KeyEvent event) {
    if (_pendingNote == null || event is! KeyDownEvent) return;
    final mapping = KeyboardUtils.getMappingName(event);

    if (_mode == KeyboardSetupMode.keys) {
      final noteKey = _getMappingKey(_pendingNote!);
      setState(() {
        _keyboardOverrides.forEach((note, m) {
          if (m == mapping && note != noteKey) _keyboardOverrides[note] = '';
        });
        _keyboardOverrides[noteKey] = mapping;
        _pendingNote = null;
      });
    } else if (_mode == KeyboardSetupMode.editor) {
      final actionKey = _pendingNote!;
      setState(() {
        _editorShortcuts.forEach((action, m) {
          if (m == mapping && action != actionKey) _editorShortcuts[action] = '';
        });
        _editorShortcuts[actionKey] = mapping;
        _pendingNote = null;
      });
    }
    _save();
  }

  String _getMappingKey(String step) => _selectedOctave != null ? '$step$_selectedOctave' : step;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        _onKey(event);
        return _pendingNote != null ? KeyEventResult.handled : KeyEventResult.ignored;
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
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SegmentedButton<KeyboardSetupMode>(
                    segments: const [
                      ButtonSegment(value: KeyboardSetupMode.keys, icon: Icon(Icons.keyboard), label: Text('Keys')),
                      ButtonSegment(value: KeyboardSetupMode.editor, icon: Icon(Icons.edit_note), label: Text('Editor')),
                    ],
                    selected: {_mode},
                    onSelectionChanged: (val) {
                      setState(() { _mode = val.first; _pendingNote = null; });
                    },
                  ),
                ),
                if (_mode != KeyboardSetupMode.editor)
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
                key: ValueKey('$_mode-$_selectedOctave'),
                itemCount: _mode == KeyboardSetupMode.editor 
                    ? KeyboardProfile.standard.editorShortcuts.length 
                    : kNoteKeys.length,
                itemBuilder: (context, index) {
                  if (_mode == KeyboardSetupMode.editor) {
                    final action = KeyboardProfile.standard.editorShortcuts.keys.elementAt(index);
                    final mapping = _editorShortcuts[action] ?? KeyboardProfile.standard.editorShortcuts[action];
                    final isInherited = !_editorShortcuts.containsKey(action);

                    return ListTile(
                      onTap: widget.profile.isBuiltIn ? null : () {
                        setState(() => _pendingNote = _pendingNote == action ? null : action);
                      },
                      selected: _pendingNote == action,
                      leading: const CircleAvatar(child: Icon(Icons.shortcut)),
                      title: Text(_formatActionName(action), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(isInherited ? 'Default: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}' : 'Specific: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}'),
                      trailing: widget.profile.isBuiltIn || isInherited ? null : IconButton(
                        icon: const Icon(Icons.close, size: 20), 
                        onPressed: () {
                          setState(() => _editorShortcuts.remove(action));
                          _save();
                        },
                      ),
                    );
                  }

                  final step = kNoteKeys[index];
                  final noteKey = _getMappingKey(step);
                  
                  final hasCustomKey = _keyboardOverrides.containsKey(noteKey);
                  final isInherited = !hasCustomKey;
                  
                  final instrument = context.watch<InstrumentProvider>().activeScheme;
                  final isHidden = instrument.hiddenKeys.contains(step);
                  final color = instrument.colorForNote(step, 0, octave: _selectedOctave, context: context);
                  final textColor = color.computeLuminance() > 0.35 ? Colors.black87 : Colors.white;

                  return Opacity(
                    opacity: isHidden ? 0.4 : 1.0,
                    child: ListTile(
                      onTap: widget.profile.isBuiltIn ? null : () {
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
                      trailing: widget.profile.isBuiltIn || isInherited ? null : IconButton(
                        icon: const Icon(Icons.close, size: 20), 
                        onPressed: () {
                          setState(() => _keyboardOverrides.remove(noteKey));
                          _save();
                        },
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
    return _pendingNote == null ? 'Tap an action to remap its shortcut.' : 'Press a key for ${_formatActionName(_pendingNote!)}...';
  }

  String _formatActionName(String action) {
    final result = action.replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(0)}');
    return result[0].toUpperCase() + result.substring(1);
  }

  String _getSubtitleText(String noteKey, bool isInherited, bool isHidden) {
    String prefix = isHidden ? '[HIDDEN] ' : '';
    final mapping = _keyboardOverrides[noteKey] ?? KeyboardProfile.standard.keyboardOverrides[noteKey];
    return '$prefix${isInherited ? 'Default: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}' : 'Specific: ${KeyboardUtils.formatForDisplay(mapping ?? 'Not mapped')}'}';
  }
}
