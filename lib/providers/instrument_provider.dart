import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/instrument_profile.dart';
import '../music_kit/models/music_display_mode.dart';
import '../music_kit/models/legend_style.dart';

/// Manages the active instrument color scheme and the global note-label setting.
class InstrumentProvider extends ChangeNotifier {
  static const String _activeIdKey = 'color_scheme_active_id';
  static const String _customSchemesKey = 'color_scheme_custom';
  static const String _showLabelsKey = 'color_scheme_show_labels';
  static const String _showLetterKey = 'settings_show_letter';
  static const String _showSolfegeKey = 'settings_show_solfege';
  static const String _labelsBelowKey = 'settings_labels_below';
  static const String _coloredLabelsKey = 'settings_colored_labels';
  static const String _measuresPerRowKey = 'settings_measures_per_row';
  static const String _showLegendKey = 'settings_show_legend';
  static const String _legendStyleKey = 'settings_legend_style';
  static const String _themeModeKey = 'app_theme_mode';
  static const String _metronomeSoundKey = 'settings_metronome_sound';
  static const String _displayModeKey = 'settings_display_mode';
  static const String _builtInKeyboardOverridesKey = 'color_scheme_builtin_keyboard';
  static const String _builtInNoteSoundsKey = 'color_scheme_builtin_note_sounds';
  static const String _builtInTuningOverridesKey = 'color_scheme_builtin_tuning';

  final Uuid _uuid = const Uuid();

  String _activeId = 'builtin_rainbow'; // Default to rainbow on first install
  List<InstrumentProfile> _customSchemes = [];
  List<InstrumentProfile> _builtInSchemes = [InstrumentProfile.black];

  bool _showNoteLabels = true;
  bool _showLetter = true;
  bool _showSolfege = false;
  bool _labelsBelow = true;
  bool _coloredLabels = false;
  int _measuresPerRow = 4;
  bool _showLegend = true;
  LegendStyle _legendStyle = LegendStyle.circles;
  ThemeMode _themeMode = ThemeMode.system;
  String _metronomeSound = 'tick';
  MusicDisplayMode _displayMode = MusicDisplayMode.view;

  bool get showNoteLabels => _showNoteLabels;
  bool get showLetter => _showLetter;
  bool get showSolfege => _showSolfege;
  bool get labelsBelow => _labelsBelow;
  bool get coloredLabels => _coloredLabels;
  int get measuresPerRow => _measuresPerRow;
  bool get showLegend => _showLegend;
  LegendStyle get legendStyle => _legendStyle;
  String get activeId => _activeId;
  ThemeMode get themeMode => _themeMode;
  String get metronomeSound => _metronomeSound;
  MusicDisplayMode get displayMode => _displayMode;

  List<InstrumentProfile> get allSchemes => [
        ..._builtInSchemes,
        ..._customSchemes,
      ];

  InstrumentProfile get activeScheme =>
      allSchemes.firstWhere(
        (s) => s.id == _activeId,
        orElse: () => allSchemes.firstWhere(
          (s) => s.id == 'builtin_rainbow',
          orElse: () => InstrumentProfile.black,
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
    _showLegend = prefs.getBool(_showLegendKey) ?? true;
    
    final legendStyleIndex = prefs.getInt(_legendStyleKey) ?? 0;
    _legendStyle = LegendStyle.values[legendStyleIndex.clamp(0, LegendStyle.values.length - 1)];

    _metronomeSound = prefs.getString(_metronomeSoundKey) ?? 'tick';

    final modeIndex = prefs.getInt(_displayModeKey) ?? 0;
    _displayMode = MusicDisplayMode.values[modeIndex.clamp(0, MusicDisplayMode.values.length - 1)];

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
                InstrumentProfile.fromJson(e as Map<String, dynamic>))
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
      _builtInSchemes = list.map((e) => InstrumentProfile.fromJson(e as Map<String, dynamic>)).toList();
      
      // Ensure "Standard" is always there if missing from JSON
      if (!_builtInSchemes.any((s) => s.id == InstrumentProfile.black.id)) {
        _builtInSchemes.insert(0, InstrumentProfile.black);
      }

      // Apply persisted overrides for built-in schemes
      final prefs = await SharedPreferences.getInstance();
      final overridesRaw = prefs.getString(_builtInKeyboardOverridesKey);
      final soundsRaw = prefs.getString(_builtInNoteSoundsKey);
      final tuningRaw = prefs.getString(_builtInTuningOverridesKey);
      
      Map<String, dynamic> allOverrides = {};
      if (overridesRaw != null) {
        try {
          allOverrides = jsonDecode(overridesRaw);
        } catch (_) {}
      }

      Map<String, dynamic> allSounds = {};
      if (soundsRaw != null) {
        try {
          allSounds = jsonDecode(soundsRaw);
        } catch (_) {}
      }

      Map<String, dynamic> allTuning = {};
      if (tuningRaw != null) {
        try {
          allTuning = jsonDecode(tuningRaw);
        } catch (_) {}
      }

      for (var i = 0; i < _builtInSchemes.length; i++) {
        final id = _builtInSchemes[i].id;
        var updated = _builtInSchemes[i];
        bool changed = false;

        if (allOverrides.containsKey(id)) {
          final overrides = Map<String, String>.from(allOverrides[id] as Map);
          updated = updated.copyWith(keyboardOverrides: overrides);
          changed = true;
        }

        if (allSounds.containsKey(id)) {
          final sounds = Map<String, String>.from(allSounds[id] as Map);
          updated = updated.copyWith(noteSounds: sounds);
          changed = true;
        }

        if (allTuning.containsKey(id)) {
          final tuning = Map<String, String>.from(allTuning[id] as Map);
          updated = updated.copyWith(tuningOverrides: tuning);
          changed = true;
        }

        if (changed) {
          _builtInSchemes[i] = updated;
        }
      }
    } catch (e) {
      debugPrint('Error loading defaults: $e');
      _builtInSchemes = [InstrumentProfile.black];
    }
  }

  /// Loads the library for searching. This is NOT stored in the provider's main list.
  Future<List<InstrumentProfile>> loadLibrary() async {
    try {
      final content = await rootBundle.loadString('assets/instruments/library.json');
      final List<dynamic> list = jsonDecode(content);
      return list.map((e) => InstrumentProfile.fromJson(e as Map<String, dynamic>)).toList();
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

  Future<void> setShowLegend(bool value) async {
    if (_showLegend == value) return;
    _showLegend = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showLegendKey, value);
  }

  Future<void> setLegendStyle(LegendStyle style) async {
    if (_legendStyle == style) return;
    _legendStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_legendStyleKey, style.index);
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

  Future<void> setDisplayMode(MusicDisplayMode mode) async {
    if (_displayMode == mode) return;
    _displayMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayModeKey, mode.index);
  }

  Future<InstrumentProfile> createCustom({String? name, String? icon, String? emoji}) async {
    final base = activeScheme;
    final scheme = InstrumentProfile(
      id: _uuid.v7(),
      name: name ?? 'Custom ${_customSchemes.length + 1}',
      icon: icon,
      emoji: emoji,
      colors: Map.from(base.colors),
      octaveOverrides: Map.from(base.octaveOverrides),
      keyboardOverrides: Map.from(base.keyboardOverrides),
    );
    _customSchemes.add(scheme);
    await _persistCustom();
    await setActive(scheme.id);
    return scheme;
  }

  Future<void> updateCustom(InstrumentProfile updated) async {
    final idx = _customSchemes.indexWhere((s) => s.id == updated.id);
    if (idx < 0) return;
    _customSchemes[idx] = updated;
    await _persistCustom();
    notifyListeners();
  }

  Future<void> updateKeyboardOverrides(String schemeId, Map<String, String> overrides) async {
    final customIdx = _customSchemes.indexWhere((s) => s.id == schemeId);
    if (customIdx >= 0) {
      _customSchemes[customIdx] = _customSchemes[customIdx].copyWith(keyboardOverrides: overrides);
      await _persistCustom();
      notifyListeners();
      return;
    }

    final builtInIdx = _builtInSchemes.indexWhere((s) => s.id == schemeId);
    if (builtInIdx >= 0) {
      _builtInSchemes[builtInIdx] = _builtInSchemes[builtInIdx].copyWith(keyboardOverrides: overrides);
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_builtInKeyboardOverridesKey);
      Map<String, dynamic> allOverrides = {};
      if (existingRaw != null) {
        try {
          allOverrides = jsonDecode(existingRaw);
        } catch (_) {}
      }
      allOverrides[schemeId] = overrides;
      await prefs.setString(_builtInKeyboardOverridesKey, jsonEncode(allOverrides));
      notifyListeners();
    }
  }

  Future<void> updateNoteSounds(String schemeId, Map<String, String> noteSounds) async {
    final customIdx = _customSchemes.indexWhere((s) => s.id == schemeId);
    if (customIdx >= 0) {
      _customSchemes[customIdx] = _customSchemes[customIdx].copyWith(noteSounds: noteSounds);
      await _persistCustom();
      notifyListeners();
      return;
    }

    final builtInIdx = _builtInSchemes.indexWhere((s) => s.id == schemeId);
    if (builtInIdx >= 0) {
      _builtInSchemes[builtInIdx] = _builtInSchemes[builtInIdx].copyWith(noteSounds: noteSounds);
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_builtInNoteSoundsKey);
      Map<String, dynamic> allNoteSounds = {};
      if (existingRaw != null) {
        try {
          allNoteSounds = jsonDecode(existingRaw);
        } catch (_) {}
      }
      allNoteSounds[schemeId] = noteSounds;
      await prefs.setString(_builtInNoteSoundsKey, jsonEncode(allNoteSounds));
      notifyListeners();
    }
  }

  Future<void> updateTuningOverrides(String schemeId, Map<String, String> tuning) async {
    final customIdx = _customSchemes.indexWhere((s) => s.id == schemeId);
    if (customIdx >= 0) {
      _customSchemes[customIdx] = _customSchemes[customIdx].copyWith(tuningOverrides: tuning);
      await _persistCustom();
      notifyListeners();
      return;
    }

    final builtInIdx = _builtInSchemes.indexWhere((s) => s.id == schemeId);
    if (builtInIdx >= 0) {
      _builtInSchemes[builtInIdx] = _builtInSchemes[builtInIdx].copyWith(tuningOverrides: tuning);
      final prefs = await SharedPreferences.getInstance();
      final existingRaw = prefs.getString(_builtInTuningOverridesKey);
      Map<String, dynamic> allTuning = {};
      if (existingRaw != null) {
        try {
          allTuning = jsonDecode(existingRaw);
        } catch (_) {}
      }
      allTuning[schemeId] = tuning;
      await prefs.setString(_builtInTuningOverridesKey, jsonEncode(allTuning));
      notifyListeners();
    }
  }

  Future<void> deleteCustom(String id) async {
    _customSchemes.removeWhere((s) => s.id == id);
    if (_activeId == id) {
      await setActive('builtin_rainbow');
    }
    await _persistCustom();
    notifyListeners();
  }

  Future<void> cloneScheme(InstrumentProfile scheme) async {
    final cloned = scheme.copyWith(
      id: _uuid.v7(),
      name: '${scheme.name} (Copy)',
      isBuiltIn: false,
      isImported: false,
    );
    _customSchemes.add(cloned);
    await _persistCustom();
    await setActive(cloned.id);
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_customSchemes.map((s) => s.toJson()).toList());
    await prefs.setString(_customSchemesKey, encoded);
  }

  Future<void> importScheme(InstrumentProfile scheme) async {
    // If it's already in custom schemes, update it; otherwise add it.
    final index = _customSchemes.indexWhere((s) => s.id == scheme.id);
    final imported = scheme.copyWith(isImported: true, isBuiltIn: false);
    if (index >= 0) {
      _customSchemes[index] = imported;
    } else {
      _customSchemes.add(imported);
    }
    await _persistCustom();
    await setActive(scheme.id);
    // If it was already active, we still notify because content might have changed.
    notifyListeners();
  }
}
