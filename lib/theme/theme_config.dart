import 'package:flutter/material.dart';

class ThemeConfig {
  final String name;
  final Color accent;
  final Color bg;
  final Color surface;
  final Color fg;
  final Color muted;
  final Color border;
  final Color inputBg;
  final Color bubbleAiBg;
  final Color drawerBg;
  final bool isDark;

  const ThemeConfig({
    required this.name,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.border,
    required this.inputBg,
    required this.bubbleAiBg,
    required this.drawerBg,
    required this.isDark,
  });

  static const deepseek = ThemeConfig(
    name: 'DeepSeek 蓝',
    accent: Color(0xFF4F6CEB),
    bg: Color(0xFFF6F7FB),
    surface: Color(0xC8FFFFFF),
    fg: Color(0xFF181B2E),
    muted: Color(0xFF9094A8),
    border: Color(0x0F000000),
    inputBg: Color(0xC8FFFFFF),
    bubbleAiBg: Colors.white,
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const claude = ThemeConfig(
    name: 'Claude 橙',
    accent: Color(0xFFD9744B),
    bg: Color(0xFFFCF9F6),
    surface: Color(0xC2FFFFFF),
    fg: Color(0xFF241A14),
    muted: Color(0xFF9B8676),
    border: Color(0x0D000000),
    inputBg: Color(0xC2FFFFFF),
    bubbleAiBg: Color(0xFFFFFBF8),
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const trae = ThemeConfig(
    name: 'Trae 绿',
    accent: Color(0xFF12B886),
    bg: Color(0xFF191C1D),
    surface: Color(0xB0242826),
    fg: Color(0xFFE4E6EA),
    muted: Color(0xFF7A8A82),
    border: Color(0x14FFFFFF),
    inputBg: Color(0xA6282C2E),
    bubbleAiBg: Color(0xFF25292B),
    drawerBg: Color(0xF5191C1D),
    isDark: true,
  );

  static const apple = ThemeConfig(
    name: '苹果白',
    accent: Color(0xFF007AFF),
    bg: Colors.white,
    surface: Color(0xCCFFFFFF),
    fg: Color(0xFF1C1C1E),
    muted: Color(0xFF8E8E93),
    border: Color(0x12000000),
    inputBg: Color(0xFFF5F5F5),
    bubbleAiBg: Color(0xFFF5F5F5),
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const List<ThemeConfig> all = [deepseek, claude, trae, apple];

  ThemeData toThemeData() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      surface: surface,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withAlpha(200),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
