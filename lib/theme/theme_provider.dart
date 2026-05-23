import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_config.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_index';

  int _index = 0;
  int get index => _index;
  ThemeConfig get config => ThemeConfig.all[_index];
  ThemeData get themeData => config.toThemeData();

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _index = prefs.getInt(_key) ?? 0;
    notifyListeners();
  }

  Future<void> setTheme(int i) async {
    _index = i;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, i);
  }
}

class ThemeProviderScope extends InheritedWidget {
  final ThemeProvider themeProvider;

  const ThemeProviderScope({
    super.key,
    required this.themeProvider,
    required super.child,
  });

  static ThemeProvider? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ThemeProviderScope>()
        ?.themeProvider;
  }

  @override
  bool updateShouldNotify(ThemeProviderScope oldWidget) => true;
}
