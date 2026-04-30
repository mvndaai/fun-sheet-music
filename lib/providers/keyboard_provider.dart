import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/keyboard_profile.dart';

class KeyboardProvider extends ChangeNotifier {
  static const String _activeIdKey = 'keyboard_active_id';
  static const String _customKey = 'keyboard_custom';

  final Uuid _uuid = const Uuid();

  String _activeId = KeyboardProfile.standard.id;
  List<KeyboardProfile> _customProfiles = [];
  final List<KeyboardProfile> _builtInProfiles = [KeyboardProfile.standard];

  String get activeId => _activeId;
  List<KeyboardProfile> get allProfiles => [..._builtInProfiles, ..._customProfiles];

  KeyboardProfile get activeProfile =>
      allProfiles.firstWhere(
        (s) => s.id == _activeId,
        orElse: () => KeyboardProfile.standard,
      );

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load built-in defaults from assets/instruments/defaults.json (or similar)
    // For now, just use standard and any persisted custom ones.
    
    _activeId = prefs.getString(_activeIdKey) ?? KeyboardProfile.standard.id;

    final raw = prefs.getString(_customKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _customProfiles = list.map((e) => KeyboardProfile.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeIdKey, id);
  }

  Future<KeyboardProfile> createCustom({String? name, String? icon, String? emoji}) async {
    final base = activeProfile;
    final profile = KeyboardProfile(
      id: _uuid.v7(),
      name: name ?? 'Custom Keyboard ${_customProfiles.length + 1}',
      icon: icon,
      emoji: emoji,
      keyboardOverrides: Map.from(base.keyboardOverrides),
      noteSounds: Map.from(base.noteSounds),
    );
    _customProfiles.add(profile);
    await _persistCustom();
    await setActive(profile.id);
    return profile;
  }

  Future<void> updateProfile(KeyboardProfile updated) async {
    final idx = _customProfiles.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      _customProfiles[idx] = updated;
      await _persistCustom();
    } else {
      final bIdx = _builtInProfiles.indexWhere((s) => s.id == updated.id);
      if (bIdx >= 0) {
        _builtInProfiles[bIdx] = updated;
        // In a real app, you might want to persist overrides for built-ins too.
      }
    }
    notifyListeners();
  }

  Future<void> deleteCustom(String id) async {
    _customProfiles.removeWhere((s) => s.id == id);
    if (_activeId == id) await setActive(KeyboardProfile.standard.id);
    await _persistCustom();
    notifyListeners();
  }

  Future<void> cloneProfile(KeyboardProfile profile) async {
    final cloned = profile.copyWith(
      id: _uuid.v7(),
      name: '${profile.name} (Copy)',
      isBuiltIn: false,
      isImported: false,
    );
    _customProfiles.add(cloned);
    await _persistCustom();
    await setActive(cloned.id);
  }

  Future<void> _persistCustom() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_customProfiles.map((s) => s.toJson()).toList());
    await prefs.setString(_customKey, encoded);
  }
}
