import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vidhai/services/data_service.dart';

/// Provides the app-wide accent color selection and persists the
/// user's choice so it survives app restarts.
class AccentColorController extends ChangeNotifier {
  AccentColorController._();
  static final AccentColorController instance = AccentColorController._();

  static const String _prefsKey = 'accent_color_index';

  // Available accent colors with their display names (localized via keys)
  static const List<AccentColorOption> options = [
    AccentColorOption(
      index: 0,
      nameKey: 'accent_fresh_green',
      lightPrimary: Color(0xFF2E7D32),
      lightAccent: Color(0xFF4CAF6C),
      darkPrimary: Color(0xFF4CAF6C),
      darkAccent: Color(0xFF4CAF6C),
    ),
    AccentColorOption(
      index: 1,
      nameKey: 'accent_blue',
      lightPrimary: Color(0xFF1976D2),
      lightAccent: Color(0xFF2196F3),
      darkPrimary: Color(0xFF2196F3),
      darkAccent: Color(0xFF2196F3),
    ),
    AccentColorOption(
      index: 2,
      nameKey: 'accent_orange',
      lightPrimary: Color(0xFFF57C00),
      lightAccent: Color(0xFFFF9800),
      darkPrimary: Color(0xFFFF9800),
      darkAccent: Color(0xFFFF9800),
    ),
    AccentColorOption(
      index: 3,
      nameKey: 'accent_purple',
      lightPrimary: Color(0xFF7B1FA2),
      lightAccent: Color(0xFF9C27B0),
      darkPrimary: Color(0xFF9C27B0),
      darkAccent: Color(0xFF9C27B0),
    ),
    AccentColorOption(
      index: 4,
      nameKey: 'accent_red',
      lightPrimary: Color(0xFFC62828),
      lightAccent: Color(0xFFEF5350),
      darkPrimary: Color(0xFFEF5350),
      darkAccent: Color(0xFFEF5350),
    ),
    AccentColorOption(
      index: 5,
      nameKey: 'accent_teal',
      lightPrimary: Color(0xFF00796B),
      lightAccent: Color(0xFF009688),
      darkPrimary: Color(0xFF009688),
      darkAccent: Color(0xFF009688),
    ),
    AccentColorOption(
      index: 6,
      nameKey: 'accent_indigo',
      lightPrimary: Color(0xFF3F51B5),
      lightAccent: Color(0xFF5C6BC0),
      darkPrimary: Color(0xFF5C6BC0),
      darkAccent: Color(0xFF5C6BC0),
    ),
    AccentColorOption(
      index: 7,
      nameKey: 'accent_pink',
      lightPrimary: Color(0xFFC2185B),
      lightAccent: Color(0xFFE91E63),
      darkPrimary: Color(0xFFE91E63),
      darkAccent: Color(0xFFE91E63),
    ),
  ];

  int _index = 0;
  AccentColorOption get current => options[_index];

  int get index => _index;

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _index = prefs.getInt(_prefsKey) ?? 0;
      notifyListeners();
    } catch (_) {
      _index = 0;
    }
  }

  Future<void> setIndex(int index) async {
    if (index < 0 || index >= options.length) return;
    _index = index;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey, index);
    } catch (_) {}
  }

  // Sync with DataService for backup/restore
  Future<void> syncWithDataService() async {
    final dsIndex = await DataService().getAccentColorIndex();
    if (dsIndex != _index) {
      _index = dsIndex;
      notifyListeners();
    }
  }
}

class AccentColorOption {
  final int index;
  final String nameKey;
  final Color lightPrimary;
  final Color lightAccent;
  final Color darkPrimary;
  final Color darkAccent;

  const AccentColorOption({
    required this.index,
    required this.nameKey,
    required this.lightPrimary,
    required this.lightAccent,
    required this.darkPrimary,
    required this.darkAccent,
  });
}
