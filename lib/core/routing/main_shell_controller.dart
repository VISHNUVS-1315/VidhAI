import 'package:flutter/material.dart';

/// Allows AI tools (and any code) to switch the bottom-nav shell tab
/// without breaking the existing navigation structure.
class MainShellController extends ChangeNotifier {
  MainShellController._();
  static final MainShellController instance = MainShellController._();

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  /// Bottom-nav tab order: 0 Home, 1 Farm, 2 AI Chat, 3 Tools, 4 Profile.
  static const indexHome = 0;
  static const indexFarm = 1;
  static const indexAi = 2;
  static const indexTools = 3;
  static const indexProfile = 4;

  void switchTab(int index) {
    if (index < 0 || index > 4 || index == _currentIndex) return;
    _currentIndex = index;
    notifyListeners();
  }
}
