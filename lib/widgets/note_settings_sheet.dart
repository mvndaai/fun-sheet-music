import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/instrument_provider.dart';
import '../screens/instruments_screen.dart';
import '../music_kit/models/music_display_mode.dart';

/// A shared settings bottom sheet for music display and playback settings.
class NoteSettingsSheet extends StatelessWidget {
  final double? tempo;
  final ValueChanged<double>? onTempoChanged;
  final VoidCallback? onPrint;
  final bool showTempo;
  final bool showPrint;
  final bool showInstrument;

  const NoteSettingsSheet({
    super.key,
    this.tempo,
    this.onTempoChanged,
    this.onPrint,
    this.showTempo = false,
    this.showPrint = false,
    this.showInstrument = true,
  });

  static void show(
    BuildContext context, {
    double? tempo,
    ValueChanged<double>? onTempoChanged,
    VoidCallback? onPrint,
    bool showTempo = false,
    bool showPrint = false,
    bool showInstrument = true,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => NoteSettingsSheet(
        tempo: tempo,
        onTempoChanged: onTempoChanged,
        onPrint: onPrint,
        showTempo: showTempo,
        showPrint: showPrint,
        showInstrument: showInstrument,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Consumer<InstrumentProvider>(
            builder: (context, provider, _) => SingleChildScrollView(
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

                  // Display Mode
                  ListTile(
                    title: const Text('Display Mode'),
                    trailing: DropdownButton<MusicDisplayMode>(
                      value: provider.displayMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: MusicDisplayMode.view, child: Text('View')),
                        DropdownMenuItem(value: MusicDisplayMode.practice, child: Text('Practice')),
                        DropdownMenuItem(value: MusicDisplayMode.game, child: Text('Game')),
                      ],
                      onChanged: (v) {
                        if (v != null) provider.setDisplayMode(v);
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Display toggles
                  SwitchListTile(
                    title: const Text('Letters'),
                    subtitle: const Text('Show letter names on notes (A, B, C…)'),
                    value: provider.showLetter,
                    onChanged: (v) => provider.setShowLetter(v),
                  ),
                  SwitchListTile(
                    title: const Text('Solfège'),
                    subtitle: const Text('Show solfège names on notes (Do, Re, Mi…)'),
                    value: provider.showSolfege,
                    onChanged: (v) => provider.setShowSolfege(v),
                  ),
                  SwitchListTile(
                    title: const Text('Labels Below Notes'),
                    subtitle: const Text('Show labels under notes instead of inside'),
                    value: provider.labelsBelow,
                    onChanged: (v) => provider.setLabelsBelow(v),
                  ),
                  SwitchListTile(
                    title: const Text('Colored Labels'),
                    subtitle: const Text('Match label color to note color'),
                    value: provider.coloredLabels,
                    onChanged: (v) => provider.setColoredLabels(v),
                  ),
                  SwitchListTile(
                    title: const Text('Show Legend'),
                    subtitle: const Text('Show the color key at the top'),
                    value: provider.showLegend,
                    onChanged: (v) => provider.setShowLegend(v),
                  ),

                  const Divider(height: 24),

                  // Optional Tempo Control
                  if (showTempo && tempo != null && onTempoChanged != null) ...[
                    ListTile(
                      title: const Text('Tempo'),
                      subtitle: Text('${tempo!.round()} BPM'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Slider(
                        value: tempo!,
                        min: 40,
                        max: 240,
                        divisions: 40,
                        label: '${tempo!.round()} BPM',
                        onChanged: (v) {
                          setSheetState(() => onTempoChanged!(v));
                        },
                      ),
                    ),
                    const Divider(height: 24),
                  ],

                  // Metronome Sound (only if tempo is shown)
                  if (showTempo) ...[
                    ListTile(
                      title: const Text('Metronome Sound'),
                      trailing: DropdownButton<String>(
                        value: provider.metronomeSound,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'tick', child: Text('Tick')),
                          DropdownMenuItem(value: 'beep', child: Text('Beep')),
                        ],
                        onChanged: (v) {
                          if (v != null) provider.setMetronomeSound(v);
                        },
                      ),
                    ),
                    const Divider(height: 24),
                  ],

                  // Layout settings
                  ListTile(
                    title: const Text('Measures per row'),
                    trailing: DropdownButton<int>(
                      value: provider.measuresPerRow,
                      underline: const SizedBox.shrink(),
                      items: [2, 3, 4, 6]
                          .map((v) => DropdownMenuItem(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) provider.setMeasuresPerRow(v);
                      },
                    ),
                  ),

                  const Divider(height: 24),

                  // Theme
                  ListTile(
                    title: const Text('Theme'),
                    trailing: DropdownButton<ThemeMode>(
                      value: provider.themeMode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
                      ],
                      onChanged: (v) {
                        if (v != null) provider.setThemeMode(v);
                      },
                    ),
                  ),

                  if (showInstrument) ...[
                    const Divider(height: 24),
                    ListTile(
                      leading: const Icon(Icons.piano),
                      title: const Text('Instrument'),
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
                  ],

                  if (showPrint && onPrint != null) ...[
                    const Divider(height: 24),
                    ListTile(
                      leading: const Icon(Icons.print),
                      title: const Text('Print'),
                      subtitle: const Text('Generate a PDF of this song'),
                      onTap: () {
                        Navigator.pop(context);
                        onPrint!();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
