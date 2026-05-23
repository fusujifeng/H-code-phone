import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme_provider.dart';
import 'screens/home_page.dart';

class HCodeApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const HCodeApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        return ProviderScope(
          child: ThemeProviderScope(
            themeProvider: themeProvider,
            child: MaterialApp(
              title: 'AI 指挥中心',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.themeData,
              home: const HomePage(),
            ),
          ),
        );
      },
    );
  }
}
