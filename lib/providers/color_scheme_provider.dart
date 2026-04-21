import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/instrument_color_scheme.dart';

/// Manages the active instrument color scheme and the global note-label setting.
///
/// Persists both the active scheme ID and any custom schemes to SharedPreferences.
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

  final Uuid _uuid = const Uuid();

  String _activeId = InstrumentColorScheme.defaultXylophone.id;
  List<InstrumentColorScheme> _customSchemes = [];

  /// When false, note circles show only color – no text label at all.
  bool _showNoteLabels = true;

  bool _showLetter = true;
  bool _showSolfege = false;
  bool _labelsBelow = true;
  bool _coloredLabels = false;
  int _measuresPerRow = 4;

  /// App theme mode: system, light, or dark
  ThemeMode _themeMode = ThemeMode.system;

  bool get showNoteLabels => _showNoteLabels;
  bool get showLetter => _showLetter;
  bool get showSolfege => _showSolfege;
  bool get labelsBelow => _labelsBelow;
  bool get coloredLabels => _coloredLabels;
  int get measuresPerRow => _measuresPerRow;
  String get activeId => _activeId;
  ThemeMode get themeMode => _themeMode;

  List<InstrumentColorScheme> get allSchemes => [
        ...InstrumentColorScheme.builtIns,
        ..._customSchemes,
      ];

  InstrumentColorScheme get activeScheme =>
      allSchemes.firstWhere(
        (s) => s.id == _activeId,
        orElse: () => InstrumentColorScheme.defaultXylophone,
      );

  /// Loads persisted preferences.  Call once at startup.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _activeId =
        prefs.getString(_activeIdKey) ?? InstrumentColorScheme.defaultXylophone.id;
    _showNoteLabels = prefs.getBool(_showLabelsKey) ?? true;
    _showLetter = prefs.getBool(_showLetterKey) ?? true;
    _showSolfege = prefs.getBool(_showSolfegeKey) ?? false;
    _labelsBelow = prefs.getBool(_labelsBelowKey) ?? true;
    _coloredLabels = prefs.getBool(_coloredLabelsKey) ?? false;
    _measuresPerRow = prefs.getInt(_measuresPerRowKey) ?? 4;

    // Load theme mode
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

  /// Returns the color for a note using the active scheme.
  Color colorForNote(String step, double alter, {int? octave}) =>
      activeScheme.colorForNote(step, alter, octave: octave);

  /// Activates the scheme with the given [id].
  Future<void> setActive(String id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, id);
  }

  /// Toggles (or explicitly sets) the note-label visibility.
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

  /// Sets the app theme mode.
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

  /// Creates a new custom scheme as a copy of the active scheme.
  Future<InstrumentColorScheme> createCustom({String? name}) async {
    final base = activeScheme;
    final scheme = InstrumentColorScheme(
      id: _uuid.v7(),
      name: name ?? 'Custom ${_customSchemes.length + 1}',
      colors: Map.from(base.colors),
      octaveOverrides: Map.from(base.octaveOverrides),
    );
    _customSchemes.add(scheme);
    await _persistCustom();
    notifyListeners();
    return scheme;
  }

  /// Saves changes to an existing custom scheme.
  Future<void> updateCustom(InstrumentColorScheme updated) async {
    final idx = _customSchemes.indexWhere((s) => s.id == updated.id);
    if (idx < 0) return;
    _customSchemes[idx] = updated;
    await _persistCustom();
    notifyListeners();
  }

  /// Deletes a custom scheme. Switches to default if it was active.
  Future<void> deleteCustom(String id) async {
    _customSchemes.removeWhere((s) => s.id == id);
    if (_activeId == id) {
      _activeId = InstrumentColorScheme.defaultXylophone.id;
    }
    await _persistCustom();
    notifyListeners();
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(_customSchemes.map((s) => s.toJson()).toList());
    await prefs.setString(_customSchemesKey, encoded);
  }
}
