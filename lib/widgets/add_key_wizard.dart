import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import 'note_color_picker.dart';

// Luminance threshold above which black text is readable on the color swatch.
const double _kContrastLuminanceThreshold = 0.35;
// Note keys longer than this character count get a smaller font in the swatch.
const int _kLongNoteLengthThreshold = 3;
const double _kSmallNoteFontSize = 10;
const double _kNormalNoteFontSize = 14;

/// Result returned by [showAddKeyWizard].
class AddKeyResult {
  /// The note key string, e.g. `"C5"`, `"F#4"`.
  final String noteKey;
  final Color color;

  const AddKeyResult({required this.noteKey, required this.color});
}

/// Opens the add-key wizard as a full-screen dialog.
///
/// Returns an [AddKeyResult] when the user completes the wizard, or `null`
/// if they cancel.
Future<AddKeyResult?> showAddKeyWizard(
  BuildContext context, {
  Color initialColor = const Color(0xFF1E88E5),
}) {
  return Navigator.push<AddKeyResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _AddKeyWizardScreen(initialColor: initialColor),
    ),
  );
}

// ── Wizard screen ─────────────────────────────────────────────────────────────

class _AddKeyWizardScreen extends StatefulWidget {
  final Color initialColor;
  const _AddKeyWizardScreen({required this.initialColor});

  @override
  State<_AddKeyWizardScreen> createState() => _AddKeyWizardScreenState();
}

class _AddKeyWizardScreenState extends State<_AddKeyWizardScreen> {
  // Step 0 = listen, Step 1 = choose color
  int _step = 0;

  // ── Step 0 state ──────────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  StreamSubscription<String>? _noteSub;
  bool _micActive = false;
  String _liveNote = '';
  final TextEditingController _manualCtrl = TextEditingController();

  // ── Step 1 state ──────────────────────────────────────────────────────────
  String _confirmedNote = '';
  late Color _selectedColor;
  late final TextEditingController _hexCtrl;
  bool _hexError = false;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    _hexCtrl = TextEditingController(text: colorToHex(_selectedColor));
  }

  @override
  void dispose() {
    _stopMic();
    _audio.dispose();
    _manualCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // ── Mic handling ─────────────────────────────────────────────────────────

  Future<void> _startMic() async {
    final ok = await _audio.startListening();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission denied. '
                'Please allow microphone access and try again.'),
          ),
        );
      }
      return;
    }
    setState(() {
      _micActive = true;
      _liveNote = '';
    });
    _noteSub = _audio.noteStream.listen((note) {
      if (mounted && note.isNotEmpty) {
        setState(() => _liveNote = note);
      }
    });
  }

  Future<void> _stopMic() async {
    await _noteSub?.cancel();
    _noteSub = null;
    await _audio.stopListening();
    if (mounted) setState(() => _micActive = false);
  }

  // ── Step transitions ──────────────────────────────────────────────────────

  void _confirmNote(String note) {
    _stopMic();
    setState(() {
      _confirmedNote = note;
      _step = 1;
    });
  }

  void _backToListen() {
    setState(() {
      _step = 0;
      _liveNote = '';
    });
  }

  // ── Color step helpers ────────────────────────────────────────────────────

  void _onHexChanged(String value) {
    final color = hexToColor(value);
    if (color != null) {
      setState(() {
        _selectedColor = color;
        _hexError = false;
      });
      return;
    }
    setState(() => _hexError = value.isNotEmpty && value.length != 6);
  }

  void _pickPaletteColor(Color color) {
    setState(() {
      _selectedColor = color;
      _hexCtrl.text = colorToHex(color);
      _hexError = false;
    });
  }

  void _done() {
    Navigator.pop(
      context,
      AddKeyResult(noteKey: _confirmedNote, color: _selectedColor),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 0 ? 'Step 1 – Hit a Key' : 'Step 2 – Choose Color'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _step == 0 ? _buildListenStep() : _buildColorStep(),
    );
  }

  // ── Step 0: Listen ────────────────────────────────────────────────────────

  Widget _buildListenStep() {
    final hasNote = _liveNote.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tap the microphone, then strike a key on your instrument.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // ── Mic button ───────────────────────────────────────────────────
          Center(
            child: GestureDetector(
              onTap: _micActive ? _stopMic : _startMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _micActive
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                  boxShadow: _micActive
                      ? [
                          BoxShadow(
                            color: Colors.green.withValues(alpha: 0.5),
                            blurRadius: 16,
                            spreadRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Icon(
                  _micActive ? Icons.mic : Icons.mic_off,
                  size: 48,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _micActive ? 'Tap to stop' : 'Tap to listen',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),

          const SizedBox(height: 32),

          // ── Detected note display ────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: hasNote
                ? Column(
                    key: ValueKey(_liveNote),
                    children: [
                      Text(
                        'Detected:',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      Text(
                        _liveNote,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                : Padding(
                    key: const ValueKey('placeholder'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _micActive ? 'Listening…' : 'Tap the mic to start',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 18,
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 20),

          // ── Use detected note button ─────────────────────────────────────
          FilledButton.icon(
            onPressed: hasNote ? () => _confirmNote(_liveNote) : null,
            icon: const Icon(Icons.check),
            label: Text(hasNote ? 'Use "$_liveNote"' : 'Waiting for note…'),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ── Manual entry ─────────────────────────────────────────────────
          Text(
            'Or enter the note manually:',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _manualCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. C5 or F#4',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[A-Ga-g0-9#b\-]')),
                    LengthLimitingTextInputFormatter(4),
                  ],
                  onSubmitted: (v) {
                    final t = v.trim().toUpperCase();
                    if (t.isNotEmpty) _confirmNote(t);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final t = _manualCtrl.text.trim().toUpperCase();
                  if (t.isNotEmpty) _confirmNote(t);
                },
                child: const Text('Use'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 1: Color ─────────────────────────────────────────────────────────

  Widget _buildColorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Note + preview header ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.6),
          child: Row(
            children: [
              // Color circle preview
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    _confirmedNote,
                    style: TextStyle(
                      color: _selectedColor.computeLuminance() >
                              _kContrastLuminanceThreshold
                          ? Colors.black87
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: _confirmedNote.length > _kLongNoteLengthThreshold
                          ? _kSmallNoteFontSize
                          : _kNormalNoteFontSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _confirmedNote,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _backToListen,
                    child: const Text('← Change key'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Hex input ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  decoration: InputDecoration(
                    prefixText: '#',
                    labelText: 'Hex color',
                    hintText: 'RRGGBB',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    errorText: _hexError ? 'Enter 6 hex digits' : null,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                    LengthLimitingTextInputFormatter(6),
                  ],
                  onChanged: _onHexChanged,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Or choose from palette:',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
        ),

        // ── Color palette ──────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kNoteColorPalette.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => _pickPaletteColor(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        // ── Done button ────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _done,
            icon: const Icon(Icons.check),
            label: Text('Add Key "$_confirmedNote"'),
          ),
        ),
      ],
    );
  }
}
