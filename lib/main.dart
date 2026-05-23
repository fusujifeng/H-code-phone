import 'package:flutter/material.dart';
import 'theme/theme_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  runApp(HCodeApp(themeProvider: themeProvider));
}
