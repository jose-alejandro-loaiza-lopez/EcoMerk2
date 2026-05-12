
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum NavigationMode { bottomNav, drawer }

class NavigationModeService extends ChangeNotifier {
  NavigationModeService._internal();

  static const String _prefsKey = 'navigation_mode';
  static final NavigationModeService instance =
      NavigationModeService._internal();

  NavigationMode _mode = NavigationMode.bottomNav;

  NavigationMode get mode => _mode;

  bool get isDrawerMode => _mode == NavigationMode.drawer;
  bool get isBottomNavMode => _mode == NavigationMode.bottomNav;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final storedMode = prefs.getString(_prefsKey);
    if (storedMode != null) {
      _mode = storedMode == 'drawer'
          ? NavigationMode.drawer
          : NavigationMode.bottomNav;
      notifyListeners();
    }
  }

  Future<void> setMode(NavigationMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      mode == NavigationMode.drawer ? 'drawer' : 'bottomNav',
    );
    notifyListeners();
  }

  Future<void> toggle() async {
    await setMode(
      isDrawerMode ? NavigationMode.bottomNav : NavigationMode.drawer,
    );
  }
}
