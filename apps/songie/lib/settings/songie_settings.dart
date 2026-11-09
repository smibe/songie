import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-configurable display preferences.
class SongieSettings extends ChangeNotifier {
  SongieSettings._(this._preferences);

  static const _showChordsKey = 'showGuitarChords';
  static const _lyricsFontSizeKey = 'lyricsFontSize';
  static const minLyricsFontSize = 16.0;
  static const maxLyricsFontSize = 36.0;
  static const defaultLyricsFontSize = 24.0;

  final SharedPreferencesAsync _preferences;

  bool _showChords = true;
  double _lyricsFontSize = defaultLyricsFontSize;

  bool get showChords => _showChords;
  double get lyricsFontSize => _lyricsFontSize;

  static Future<SongieSettings> load() async {
    final preferences = SharedPreferencesAsync();
    final settings = SongieSettings._(preferences);
    settings._showChords =
        await preferences.getBool(_showChordsKey) ?? true;
    settings._lyricsFontSize =
        await preferences.getDouble(_lyricsFontSizeKey) ??
        defaultLyricsFontSize;
    return settings;
  }

  Future<void> setShowChords(bool value) async {
    if (_showChords == value) return;
    _showChords = value;
    notifyListeners();
    await _preferences.setBool(_showChordsKey, value);
  }

  Future<void> setLyricsFontSize(double value) async {
    final clamped = value.clamp(minLyricsFontSize, maxLyricsFontSize);
    if (_lyricsFontSize == clamped) return;
    _lyricsFontSize = clamped;
    notifyListeners();
    await _preferences.setDouble(_lyricsFontSizeKey, clamped);
  }
}
