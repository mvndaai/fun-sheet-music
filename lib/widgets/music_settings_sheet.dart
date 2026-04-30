import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../providers/keyboard_provider.dart';
import '../providers/payment_provider.dart';
import '../screens/instruments_screen.dart';
import '../screens/keyboards_screen.dart';
import '../music_kit/models/music_display_mode.dart';
import '../music_kit/models/legend_style.dart';
import '../platform/platform.dart';

/// A shared settings bottom sheet for music display and playback settings.
class MusicSettingsSheet extends StatefulWidget {
  final double? tempo;
  final ValueChanged<double>? onTempoChanged;
  final VoidCallback? onPrint;
  final bool showPrint;
  final bool showInstrument;

  const MusicSettingsSheet({
    super.key,
    this.tempo,
    this.onTempoChanged,
    this.onPrint,
    this.showPrint = false,
    this.showInstrument = true,
  });

  static void show(
    BuildContext context, {
    double? tempo,
    ValueChanged<double>? onTempoChanged,
    VoidCallback? onPrint,
    bool showPrint = false,
    bool showInstrument = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => MusicSettingsSheet(
        tempo: tempo,
        onTempoChanged: onTempoChanged,
        onPrint: onPrint,
        showPrint: showPrint,
        showInstrument: showInstrument,
      ),
    );
  }

  @override
  State<MusicSettingsSheet> createState() => _MusicSettingsSheetState();
}

class _MusicSettingsSheetState extends State<MusicSettingsSheet> {
  late double _localTempo;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _localTempo = widget.tempo ?? context.read<InstrumentProvider>().tempo;
    // Ensure focus is requested for keyboard shortcuts (esc key)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
    if (kIsWeb) {
      setOnBeforeInstallPrompt(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (context.mounted) Navigator.of(context).maybePop();
          },
          if (widget.showPrint && widget.onPrint != null) ...{
            const SingleActivator(LogicalKeyboardKey.keyP, control: true):
                widget.onPrint!,
            const SingleActivator(LogicalKeyboardKey.keyP, meta: true):
                widget.onPrint!,
          },
        },
        child: Focus(
          focusNode: _focusNode,
          autofocus: true,
          child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Consumer2<InstrumentProvider, KeyboardProvider>(
          builder: (context, provider, keyboardProvider, _) => SingleChildScrollView(
            primary: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 24),

                // 1. Display Mode
                _SegmentedSetting<MusicDisplayMode>(
                  title: 'Display Mode',
                  value: provider.displayMode,
                  options: const [
                    (value: MusicDisplayMode.view, label: 'View', icon: Icons.visibility),
                    (value: MusicDisplayMode.practice, label: 'Practice', icon: Icons.mic),
                    (value: MusicDisplayMode.game, label: 'Game', icon: Icons.sports_esports),
                  ],
                  onChanged: (v) => provider.setDisplayMode(v),
                ),

                // 2. Instrument
                if (widget.showInstrument)
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Instrument (Visuals)'),
                    subtitle: Text(provider.activeScheme.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const InstrumentsScreen()),
                      );
                    },
                  ),

                // 2.1 Keyboard
                ListTile(
                  leading: const Icon(Icons.keyboard),
                  title: const Text('Keyboard & Sounds'),
                  subtitle: Text(keyboardProvider.activeProfile.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const KeyboardsScreen()),
                    );
                  },
                ),

                // 2.2 Install App (Web PWA)
                if (kIsWeb && canInstallApp())
                  ListTile(
                    leading: const Icon(Icons.install_mobile),
                    title: const Text('Install App'),
                    subtitle: const Text('Add to your home screen for easy access'),
                    onTap: () async {
                      final result = await installApp();
                      if (result == 'accepted' && context.mounted) {
                        Navigator.pop(context);
                      } else if (result == 'not_available' && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Installation prompt not ready yet or not supported by this browser.')),
                        );
                      }
                    },
                  ),

                // 3. Print
                if (widget.showPrint && widget.onPrint != null)
                  ListTile(
                    leading: const Icon(Icons.print),
                    title: const Text('Print'),
                    subtitle: const Text('Generate a PDF of this song'),
                    onTap: () {
                      Navigator.pop(context);
                      widget.onPrint!();
                    },
                  ),

                const Divider(height: 24),
                const _SectionHeader(title: 'Display'),

                // 4. Measures per row
                _SegmentedSetting<int>(
                  title: 'Measures per row',
                  value: provider.measuresPerRow,
                  options: const [
                    (value: 2, label: '2', icon: null),
                    (value: 3, label: '3', icon: null),
                    (value: 4, label: '4', icon: null),
                    (value: 6, label: '6', icon: null),
                  ],
                  onChanged: (v) => provider.setMeasuresPerRow(v),
                ),

                // 4.1 PDF Orientation
                _SegmentedSetting<bool>(
                  title: 'PDF Orientation',
                  value: provider.pdfLandscape,
                  options: const [
                    (value: false, label: 'Portrait', icon: Icons.portrait),
                    (value: true, label: 'Landscape', icon: Icons.landscape),
                  ],
                  onChanged: (v) => provider.setPdfLandscape(v),
                ),

                // 5. Theme
                _SegmentedSetting<ThemeMode>(
                  title: 'Theme',
                  value: provider.themeMode,
                  options: const [
                    (value: ThemeMode.system, label: 'System', icon: Icons.brightness_auto),
                    (value: ThemeMode.light, label: 'Light', icon: Icons.light_mode),
                    (value: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode),
                  ],
                  onChanged: (v) => provider.setThemeMode(v),
                ),

                // 6. Note Letters (A, B, C…)
                _SegmentedSetting<bool>(
                  title: 'Note Letters (A, B, C…)',
                  value: provider.showLetter,
                  options: const [
                    (value: true, label: 'Show', icon: null),
                    (value: false, label: 'Hide', icon: null),
                  ],
                  onChanged: (v) => provider.setShowLetter(v),
                ),

                // 7. Solfège Names (Do, Re, Mi…)
                _SegmentedSetting<bool>(
                  title: 'Solfège Names (Do, Re, Mi…)',
                  value: provider.showSolfege,
                  options: const [
                    (value: true, label: 'Show', icon: null),
                    (value: false, label: 'Hide', icon: null),
                  ],
                  onChanged: (v) => provider.setShowSolfege(v),
                ),

                // 8. Label Position
                _SegmentedSetting<bool>(
                  title: 'Label Position',
                  value: provider.labelsBelow,
                  options: const [
                    (value: true, label: 'Below Note', icon: null),
                    (value: false, label: 'Inside Note', icon: null),
                  ],
                  onChanged: (v) => provider.setLabelsBelow(v),
                ),

                // 9. Label Color
                _SegmentedSetting<bool>(
                  title: 'Label Color',
                  value: provider.coloredLabels,
                  options: const [
                    (value: true, label: 'Match Note', icon: null),
                    (value: false, label: 'Standard', icon: null),
                  ],
                  onChanged: (v) => provider.setColoredLabels(v),
                ),

                // 10. Top Color Legend
                _SegmentedSetting<bool>(
                  title: 'Top Color Legend',
                  value: provider.showLegend,
                  options: const [
                    (value: true, label: 'Show', icon: null),
                    (value: false, label: 'Hide', icon: null),
                  ],
                  onChanged: (v) => provider.setShowLegend(v),
                ),

                if (provider.showLegend)
                  _SegmentedSetting<LegendStyle>(
                    title: 'Legend Style',
                    value: provider.legendStyle,
                    options: const [
                      (value: LegendStyle.circles, label: 'Circles', icon: Icons.circle),
                      (value: LegendStyle.piano, label: 'Piano', icon: Icons.piano),
                    ],
                    onChanged: (v) => provider.setLegendStyle(v),
                  ),

                const Divider(height: 24),
                const _SectionHeader(title: 'Sound'),

                // 11. Metronome Sound
                _SegmentedSetting<String>(
                  title: 'Metronome Sound',
                  value: provider.metronomeSound,
                  options: const [
                    (value: 'tick', label: 'Tick', icon: null),
                    (value: 'beep', label: 'Beep', icon: null),
                  ],
                  onChanged: (v) => provider.setMetronomeSound(v),
                ),

                // 12. Tempo
                ListTile(
                  title: const Text('Tempo'),
                  subtitle: Text('${_localTempo.round()} BPM'),
                  trailing: SizedBox(
                    width: 200, // Increased width for better dragging
                    child: Slider(
                      value: _localTempo,
                      min: 40,
                      max: 240,
                      divisions: 200, // Smoother 1-BPM increments
                      onChanged: (v) {
                        setState(() => _localTempo = v);
                        if (widget.onTempoChanged != null) {
                          widget.onTempoChanged!(v);
                        }
                      },
                      onChangeEnd: (v) {
                        if (widget.onTempoChanged == null) {
                          provider.setTempo(v);
                        }
                      },
                    ),
                  ),
                ),

                if (!kIsWeb) ...[
                  const Divider(height: 24),
                  const _SectionHeader(title: 'Support & Ads'),

                  if (provider.isAdFree)
                    const ListTile(
                      leading: Icon(Icons.check_circle, color: Colors.green),
                      title: Text('Ad-Free Enabled'),
                      subtitle: Text('Thank you for supporting Fun Sheet Music!'),
                    )
                  else ...[
                    Consumer<PaymentProvider>(
                      builder: (context, payment, _) => Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.star_outline),
                            title: const Text('Remove Ads (Yearly)'),
                            subtitle: const Text('\$1 / year subscription'),
                            trailing: const Text('\$1.00', style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () async {
                              // In production, this would call real IAP
                              await payment.simulatePurchase(PaymentProvider.adFreeYearId);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.favorite_border),
                            title: const Text('Remove Ads (Lifetime)'),
                            subtitle: const Text('\$5 forever - Best value!'),
                            trailing: const Text('\$5.00', style: TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () async {
                              await payment.simulatePurchase(PaymentProvider.adFreeForeverId);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
}
}

class _SegmentedSetting<T> extends StatelessWidget {
  final String title;
  final T value;
  final List<({T value, String label, IconData? icon})> options;
  final ValueChanged<T> onChanged;

  const _SegmentedSetting({
    required this.title,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<T>(
              segments: options
                  .map((opt) => ButtonSegment<T>(
                        value: opt.value,
                        icon: opt.icon != null ? Icon(opt.icon) : null,
                        label: Text(opt.label),
                      ))
                  .toList(),
              selected: {value},
              onSelectionChanged: (set) => onChanged(set.first),
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}
