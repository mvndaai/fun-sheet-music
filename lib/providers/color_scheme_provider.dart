import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/instrument_color_scheme.dart';

/// Manages the active instrument color scheme and the global note-label setting.
class ColorSchemeProvider extends ChangeNotifier {
  static const String _activeIdKey = 'color_scheme_active_id';
  static const String _customSchemesKey = 'color_scheme_custom';
  static const String _showLabelsKey = 'color_scheme_show_labels';
  static const String _showLetterKey = 'settings_show_letter';
  static const String _showSolfegeKey = 'settings_show_solfege';
  static const String _labelsBelowKey = 'settings_labels_below';
  static const String _coloredLabelsKey = 'settings_colored_labels';
  static const String _measuresPerRowKey = 'settings_measures_per_row';
  static const String _themeModeKey = 'app_theme_mode';
  static const String _metronomeSoundKey = 'settings_metronome_sound';

  final Uuid _uuid = const Uuid();

  String _activeId = 'builtin_rainbow'; // Default to rainbow on first install
  List<InstrumentColorScheme> _customSchemes = [];
  List<InstrumentColorScheme> _builtInSchemes = [InstrumentColorScheme.black];

  bool _showNoteLabels = true;
  bool _showLetter = true;
  bool _showSolfege = false;
  bool _labelsBelow = true;
  bool _coloredLabels = false;
  int _measuresPerRow = 4;
  ThemeMode _themeMode = ThemeMode.system;
  String _metronomeSound = 'tick';

  bool get showNoteLabels => _showNoteLabels;
  bool get showLetter => _showLetter;
  bool get showSolfege => _showSolfege;
  bool get labelsBelow => _labelsBelow;
  bool get coloredLabels => _coloredLabels;
  int get measuresPerRow => _measuresPerRow;
  String get activeId => _activeId;
  ThemeMode get themeMode => _themeMode;
  String get metronomeSound => _metronomeSound;

  List<InstrumentColorScheme> get allSchemes => [
        ..._builtInSchemes,
        ..._customSchemes,
      ];

  InstrumentColorScheme get activeScheme =>
      allSchemes.firstWhere(
        (s) => s.id == _activeId,
        orElse: () => allSchemes.firstWhere(
          (s) => s.id == 'builtin_rainbow',
          orElse: () => InstrumentColorScheme.black,
        ),
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load built-in defaults from assets/instruments/defaults.json
    await _loadDefaults();

    _activeId = prefs.getString(_activeIdKey) ?? 'builtin_rainbow';
    _showNoteLabels = prefs.getBool(_showLabelsKey) ?? true;
    _showLetter = prefs.getBool(_showLetterKey) ?? true;
    _showSolfege = prefs.getBool(_showSolfegeKey) ?? false;
    _labelsBelow = prefs.getBool(_labelsBelowKey) ?? true;
    _coloredLabels = prefs.getBool(_coloredLabelsKey) ?? false;
    _measuresPerRow = prefs.getInt(_measuresPerRowKey) ?? 4;
    _metronomeSound = prefs.getString(_metronomeSoundKey) ?? 'tick';

    final themeModeStr = prefs.getString(_themeModeKey) ?? 'system';
    _themeMode = switch (themeModeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    final raw = prefs.getString(_customSchemesKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _customSchemes = list
            .map((e) =>
                InstrumentColorScheme.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _customSchemes = [];
      }
    }
    notifyListeners();
  }

  Future<void> _loadDefaults() async {
    try {
      final content = await rootBundle.loadString('assets/instruments/defaults.json');
      final List<dynamic> list = jsonDecode(content);
      _builtInSchemes = list.map((e) => InstrumentColorScheme.fromJson(e as Map<String, dynamic>)).toList();
      
      // Ensure "Standard" is always there if missing from JSON
      if (!_builtInSchemes.any((s) => s.id == InstrumentColorScheme.black.id)) {
        _builtInSchemes.insert(0, InstrumentColorScheme.black);
      }
    } catch (e) {
      debugPrint('Error loading defaults: $e');
      _builtInSchemes = [InstrumentColorScheme.black];
    }
  }

  /// Loads the library for searching. This is NOT stored in the provider's main list.
  Future<List<InstrumentColorScheme>> loadLibrary() async {
    try {
      final content = await rootBundle.loadString('assets/instruments/library.json');
      final List<dynamic> list = jsonDecode(content);
      return list.map((e) => InstrumentColorScheme.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error loading library: $e');
      return [];
    }
  }

  Color colorForNote(
    String step,
    double alter, {
    int? octave,
    BuildContext? context,
    Brightness? brightness,
  }) =>
      activeScheme.colorForNote(
        step,
        alter,
        octave: octave,
        context: context,
        brightness: brightness,
      );

  Future<void> setActive(String id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, id);
  }

  Future<void> setShowNoteLabels(bool value) async {
    if (_showNoteLabels == value) return;
    _showNoteLabels = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLabelsKey, value);
  }

  Future<void> setShowLetter(bool value) async {
    if (_showLetter == value) return;
    _showLetter = value;
    _showNoteLabels = _showLetter || _showSolfege;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLetterKey, value);
    await prefs.setBool(_showLabelsKey, _showNoteLabels);
  }

  Future<void> setShowSolfege(bool value) async {
    if (_showSolfege == value) return;
    _showSolfege = value;
    _showNoteLabels = _showLetter || _showSolfege;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showSolfegeKey, value);
    await prefs.setBool(_showLabelsKey, _showNoteLabels);
  }

  Future<void> setLabelsBelow(bool value) async {
    if (_labelsBelow == value) return;
    _labelsBelow = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_labelsBelowKey, value);
  }

  Future<void> setColoredLabels(bool value) async {
    if (_coloredLabels == value) return;
    _coloredLabels = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_coloredLabelsKey, value);
  }

  Future<void> setMeasuresPerRow(int value) async {
    if (_measuresPerRow == value) return;
    _measuresPerRow = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_measuresPerRowKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final modeStr = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, modeStr);
  }

  Future<void> setMetronomeSound(String sound) async {
    if (_metronomeSound == sound) return;
    _metronomeSound = sound;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metronomeSoundKey, sound);
  }

  Future<InstrumentColorScheme> createCustom({String? name, String? icon, String? emoji}) async {
    final base = activeScheme;
    final scheme = InstrumentColorScheme(
      id: _uuid.v7(),
      name: name ?? 'Custom ${_customSchemes.length + 1}',
      icon: icon,
      emoji: emoji,
      colors: Map.from(base.colors),
      octaveOverrides: Map.from(base.octaveOverrides),
    );
    _customSchemes.add(scheme);
    await _persistCustom();
    notifyListeners();
    return scheme;
  }

  Future<void> updateCustom(InstrumentColorScheme updated) async {
    final idx = _customSchemes.indexWhere((s) => s.id == updated.id);
    if (idx < 0) return;
    _customSchemes[idx] = updated;
    await _persistCustom();
    notifyListeners();
  }

  Future<void> deleteCustom(String id) async {
    _customSchemes.removeWhere((s) => s.id == id);
    if (_activeId == id) {
      _activeId = 'builtin_rainbow';
    }
    await _persistCustom();
    notifyListeners();
  }

  Future<void> cloneScheme(InstrumentColorScheme scheme) async {
    final cloned = scheme.copyWith(
      id: _uuid.v7(),
      name: '${scheme.name} (Copy)',
      isBuiltIn: false,
      isImported: false,
    );
    _customSchemes.add(cloned);
    await _persistCustom();
    notifyListeners();
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_customSchemes.map((s) => s.toJson()).toList());
    await prefs.setString(_customSchemesKey, encoded);
  }

  Future<void> importScheme(InstrumentColorScheme scheme) async {
    // If it's already in custom schemes, update it; otherwise add it.
    final index = _customSchemes.indexWhere((s) => s.id == scheme.id);
    final imported = scheme.copyWith(isImported: true, isBuiltIn: false);
    if (index >= 0) {
      _customSchemes[index] = imported;
    } else {
      _customSchemes.add(imported);
    }
    await _persistCustom();
    notifyListeners();
  }
}
