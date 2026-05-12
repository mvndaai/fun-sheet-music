import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../music_kit/models/sound_profile.dart';

class SoundProvider extends ChangeNotifier {
  static const String _activeIdKey = 'sound_active_id';
  static const String _customKey = 'sound_custom';

  final Uuid _uuid = const Uuid();
  SharedPreferences? _prefs;

  String _activeId = SoundProfile.standard.id;
  List<SoundProfile> _customProfiles = [];
  List<SoundProfile> _builtInProfiles = [SoundProfile.standard];

  Future<SharedPreferences> get _preferences async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String get activeId => _activeId;
  List<SoundProfile> get allProfiles => [..._builtInProfiles, ..._customProfiles];

  SoundProfile get activeProfile =>
      allProfiles.firstWhere(
        (s) => s.id == _activeId,
        orElse: () => SoundProfile.standard,
      );

  Future<void> load() async {
    final prefs = await _preferences;
    
    _builtInProfiles = [
      SoundProfile.standard,
      SoundProfile.piano,
      SoundProfile.xylophone,
      SoundProfile.flute,
    ];
    
    _activeId = prefs.getString(_activeIdKey) ?? SoundProfile.standard.id;

    final raw = prefs.getString(_customKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _customProfiles = list.map((e) => SoundProfile.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> setActive(String id) async {
    if (_activeId == id) return;
    _activeId = id;
    notifyListeners();
    final prefs = await _preferences;
    await prefs.setString(_activeIdKey, id);
  }

  Future<SoundProfile> createCustom({String? name, String? icon, String? emoji}) async {
    final profile = SoundProfile(
      id: _uuid.v7(),
      name: name ?? 'Custom Sound Set ${_customProfiles.length + 1}',
      icon: icon,
      emoji: emoji,
      noteSounds: {},
    );
    _customProfiles.add(profile);
    await _persistCustom();
    await setActive(profile.id);
    return profile;
  }

  Future<void> updateProfile(SoundProfile updated) async {
    if (updated.isBuiltIn) return;
    
    final idx = _customProfiles.indexWhere((s) => s.id == updated.id);
    if (idx >= 0) {
      _customProfiles[idx] = updated;
      await _persistCustom();
      notifyListeners();
    }
  }

  Future<void> deleteCustom(String id) async {
    _customProfiles.removeWhere((s) => s.id == id);
    if (_activeId == id) await setActive(SoundProfile.standard.id);
    await _persistCustom();
    notifyListeners();
  }

  Future<void> cloneProfile(SoundProfile profile) async {
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
    final prefs = await _preferences;
    final encoded = jsonEncode(_customProfiles.map((s) => s.toJson()).toList());
    await prefs.setString(_customKey, encoded);
  }
}
