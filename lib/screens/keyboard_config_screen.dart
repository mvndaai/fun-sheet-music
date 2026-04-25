import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../music_kit/models/instrument_profile.dart';
import '../providers/instrument_provider.dart';
import '../music_kit/utils/music_constants.dart';

/// Screen for configuring keyboard-to-note mappings for an instrument.
class KeyboardConfigScreen extends StatefulWidget {
  final InstrumentProfile scheme;
  const KeyboardConfigScreen({super.key, required this.scheme});

  @override
  State<KeyboardConfigScreen> createState() => _KeyboardConfigScreenState();
}

class _KeyboardConfigScreenState extends State<KeyboardConfigScreen> {
  late Map<String, String> _overrides;
  String? _pendingNote;

  @override
  void initState() {
    super.initState();
    _overrides = Map.from(widget.scheme.keyboardOverrides);
  }

  void _save() {
    context.read<InstrumentProvider>().updateKeyboardOverrides(widget.scheme.id, _overrides);
  }

  Future<void> _exportOverrides() async {
    final jsonStr = jsonEncode(_overrides);
    await Clipboard.setData(ClipboardData(text: jsonStr));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyboard mapping copied to clipboard')),
      );
    }
  }

  Future<void> _importOverrides() async {
    final controller = TextEditingController();
    final jsonStr = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Keyboard Mapping'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Paste JSON here...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (jsonStr == null || jsonStr.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map) {
        setState(() {
          _overrides = Map<String, String>.from(decoded.cast<String, String>());
        });
        _save();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Keyboard mapping imported')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Collect all notes to show. 
    // 1. Common notes in a reasonable range (C3-C6)
    // 2. Any notes that already have a mapping
    final Set<String> allNotes = {};
    for (int octave = 3; octave <= 6; octave++) {
      for (final note in kNoteKeys) {
        allNotes.add('$note$octave');
      }
    }
    allNotes.addAll(_overrides.keys);

    final sortedNotes = allNotes.toList()
      ..sort((a, b) => MusicConstants.noteNameToMidi(a)
          .compareTo(MusicConstants.noteNameToMidi(b)));

    final isStandard = widget.scheme.id == InstrumentProfile.black.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(isStandard
            ? 'Default Keyboard'
            : 'Keyboard: ${widget.scheme.name}'),
        actions: [
          IconButton(
            icon: Icon(isStandard ? Icons.restore : Icons.delete_sweep),
            tooltip: isStandard ? 'Reset to Default' : 'Clear All Overrides',
            onPressed: () {
              setState(() {
                if (isStandard) {
                  _overrides = Map.from(InstrumentProfile.black.keyboardOverrides);
                } else {
                  _overrides = {};
                }
              });
              _save();
            },
          ),
          IconButton(
            icon: const Icon(Icons.file_upload),
            tooltip: 'Import Mappings',
            onPressed: _importOverrides,
          ),
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Export Mappings',
            onPressed: _exportOverrides,
          ),
        ],
      ),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (_pendingNote == null) return KeyEventResult.ignored;

          final isShift = HardwareKeyboard.instance.isShiftPressed;
          final isAlt = HardwareKeyboard.instance.isAltPressed;
          
          final physicalKeyName = event.physicalKey.debugName?.replaceAll(' ', '') ?? '';
          
          String mapping = physicalKeyName;
          if (isShift) mapping = 'Shift+$physicalKeyName';
          else if (isAlt) mapping = 'Alt+$physicalKeyName';

          setState(() {
            // Do not let one key be mapped to multiple tones.
            // If that happens, set the older one to an empty string (not set override).
            
            // Check current overrides
            _overrides.forEach((note, mappingStr) {
              if (mappingStr == mapping && note != _pendingNote) {
                _overrides[note] = '';
              }
            });

            // Also check default mappings if we're not editing the standard scheme
            if (widget.scheme.id != InstrumentProfile.black.id) {
              InstrumentProfile.black.keyboardOverrides.forEach((note, mappingStr) {
                if (mappingStr == mapping && note != _pendingNote) {
                  // If the default has this mapping, we must explicitly unset it in our overrides
                  // if we haven't already mapped this note to something else.
                  if (_overrides[note] == null || _overrides[note] == mappingStr) {
                    _overrides[note] = '';
                  }
                }
              });
            }

            _overrides[_pendingNote!] = mapping;
            _pendingNote = null;
          });
          _save();
          return KeyEventResult.handled;
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _pendingNote == null
                    ? 'Tap a note to change its keyboard mapping.'
                    : 'Press a key on your keyboard for $_pendingNote...',
                style: TextStyle(
                  color: _pendingNote == null ? Colors.grey.shade600 : Theme.of(context).colorScheme.primary,
                  fontWeight: _pendingNote == null ? FontWeight.normal : FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                primary: true,
                itemCount: sortedNotes.length,
                itemBuilder: (context, index) {
                  final note = sortedNotes[index];
                  final mapping = _overrides[note];
                  final isPending = _pendingNote == note;

                  final defaultMapping =
                      InstrumentProfile.black.keyboardOverrides[note];
                  final isStandard =
                      widget.scheme.id == InstrumentProfile.black.id;

                  String displayMapping;
                  bool isFallback = false;
                  bool isUnset = mapping == '';
                  bool hasExplicitMapping = mapping != null && mapping.isNotEmpty;

                  if (hasExplicitMapping) {
                    displayMapping = mapping;
                  } else if (isUnset) {
                    displayMapping = 'Unset';
                  } else if (!isStandard &&
                      defaultMapping != null &&
                      defaultMapping.isNotEmpty) {
                    displayMapping = defaultMapping;
                    isFallback = true;
                  } else {
                    displayMapping = 'None';
                  }

                  displayMapping = displayMapping
                      .replaceAll('Key', '')
                      .replaceAll('Shift+', '⇧')
                      .replaceAll('Alt+', '⌥');

                  return ListTile(
                    title: Text(note,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      isPending ? 'WAITING FOR KEY...' : displayMapping,
                      style: TextStyle(
                        color: isFallback
                            ? Colors.grey.shade500
                            : isUnset
                                ? Colors.red.shade300
                                : null,
                        fontStyle: isFallback ? FontStyle.italic : null,
                      ),
                    ),
                    trailing: (hasExplicitMapping || isUnset) && !isPending
                        ? IconButton(
                            icon: Icon(isUnset ? Icons.refresh : Icons.close,
                                size: 20),
                            tooltip: isUnset ? 'Restore default' : 'Unset',
                            onPressed: () {
                              setState(() {
                                if (isUnset) {
                                  _overrides.remove(note);
                                } else {
                                  _overrides[note] = '';
                                }
                              });
                              _save();
                            },
                          )
                        : const Icon(Icons.keyboard,
                            size: 20, color: Colors.grey),
                    selected: isPending,
                    selectedTileColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.1),
                    onTap: () {
                      setState(() {
                        _pendingNote = isPending ? null : note;
                      });
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
}
