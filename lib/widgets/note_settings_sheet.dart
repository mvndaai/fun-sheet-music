import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.pop(context),
      },
      child: StatefulBuilder(
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
                    if (showInstrument)
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

                    // 3. Print
                    if (showPrint && onPrint != null)
                      ListTile(
                        leading: const Icon(Icons.print),
                        title: const Text('Print'),
                        subtitle: const Text('Generate a PDF of this song'),
                        onTap: () {
                          Navigator.pop(context);
                          onPrint!();
                        },
                      ),

                    const Divider(height: 24),
                    _SectionHeader(title: 'Display'),

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

                    // 6. Letters
                    SwitchListTile(
                      title: const Text('Letters'),
                      subtitle: const Text('Show letter names on notes (A, B, C…)'),
                      value: provider.showLetter,
                      onChanged: (v) => provider.setShowLetter(v),
                    ),

                    // 7. Solfege
                    SwitchListTile(
                      title: const Text('Solfège'),
                      subtitle: const Text('Show solfège names on notes (Do, Re, Mi…)'),
                      value: provider.showSolfege,
                      onChanged: (v) => provider.setShowSolfege(v),
                    ),

                    // 8. Labels below notes
                    SwitchListTile(
                      title: const Text('Labels Below Notes'),
                      subtitle: const Text('Show labels under notes instead of inside'),
                      value: provider.labelsBelow,
                      onChanged: (v) => provider.setLabelsBelow(v),
                    ),

                    // 9. Colored Labels
                    SwitchListTile(
                      title: const Text('Colored Labels'),
                      subtitle: const Text('Match label color to note color'),
                      value: provider.coloredLabels,
                      onChanged: (v) => provider.setColoredLabels(v),
                    ),

                    // 10. Show Legend
                    SwitchListTile(
                      title: const Text('Show Legend'),
                      subtitle: const Text('Show the color key at the top'),
                      value: provider.showLegend,
                      onChanged: (v) => provider.setShowLegend(v),
                    ),

                    const Divider(height: 24),
                    _SectionHeader(title: 'Sound'),

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
                    if (showTempo && tempo != null && onTempoChanged != null)
                      ListTile(
                        title: const Text('Tempo'),
                        subtitle: Text('${tempo!.round()} BPM'),
                        trailing: SizedBox(
                          width: 150,
                          child: Slider(
                            value: tempo!,
                            min: 40,
                            max: 240,
                            divisions: 40,
                            onChanged: (v) {
                              setSheetState(() => onTempoChanged!(v));
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
    if (options.length > 3) {
      return ListTile(
        title: Text(title),
        trailing: DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          items: options
              .map((opt) => DropdownMenuItem(
                    value: opt.value,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (opt.icon != null) ...[Icon(opt.icon, size: 20), const SizedBox(width: 10)],
                        Text(opt.label),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      );
    }

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
