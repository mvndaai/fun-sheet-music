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

  final Uuid _uuid = const Uuid();

  String _activeId = InstrumentColorScheme.defaultXylophone.id;
  List<InstrumentColorScheme> _customSchemes = [];

  /// When false, note circles show only color – no text label at all.
  bool _showNoteLabels = true;

  bool get showNoteLabels => _showNoteLabels;
  String get activeId => _activeId;

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
