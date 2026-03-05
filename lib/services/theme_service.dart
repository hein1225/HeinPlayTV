import 'package:flutter/material.dart';
import 'dart:io' show Platform;

class ThemeService extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    // 当为系统模式时，需要根据当前系统主题判断
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  ThemeService() {
    _loadTheme();
  }

  void _loadTheme() async {
    // 每次启动都默认跟随系统主题，不保存用户的手动选择
    _themeMode = ThemeMode.system;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    // 不再保存到 SharedPreferences，每次启动都重新遵循系统主题
    notifyListeners();
  }

  void toggleTheme(BuildContext context) async {
    switch (_themeMode) {
      case ThemeMode.light:
        setThemeMode(ThemeMode.dark);
        break;
      case ThemeMode.dark:
        setThemeMode(ThemeMode.light);
        break;
      case ThemeMode.system:
        // 当为系统模式时，检测当前系统主题并切换到相反模式
        final brightness = MediaQuery.of(context).platformBrightness;
        if (brightness == Brightness.light) {
          setThemeMode(ThemeMode.dark);
        } else {
          setThemeMode(ThemeMode.light);
        }
        break;
    }
  }

  ThemeData get lightTheme {
    // Windows 下使用微软雅黑以获得更好的中文渲染
    final textTheme = Platform.isWindows
        ? ThemeData.light().textTheme.copyWith(
              bodyLarge: const TextStyle(
                color: Color(0xFF1e293b),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFF1e293b),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodySmall: const TextStyle(
                color: Color(0xFF64748b),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              titleLarge: const TextStyle(
                color: Color(0xFF1e293b),
                fontWeight: FontWeight.w600,
                fontFamily: 'Microsoft YaHei',
              ),
              titleMedium: const TextStyle(
                color: Color(0xFF1e293b),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleSmall: const TextStyle(
                color: Color(0xFF1e293b),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
            )
        : const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFF1e293b)),
            bodyMedium: TextStyle(color: Color(0xFF1e293b)),
            bodySmall: TextStyle(color: Color(0xFF64748b)),
            titleLarge: TextStyle(color: Color(0xFF1e293b)),
            titleMedium: TextStyle(color: Color(0xFF1e293b)),
            titleSmall: TextStyle(color: Color(0xFF1e293b)),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3b82f6),
        brightness: Brightness.light,
        primary: const Color(0xFF3b82f6),
        secondary: const Color(0xFF10b981),
        surface: const Color(0xFFffffff),
        background: const Color(0xFFf8fafc),
        error: const Color(0xFFef4444),
      ),
      scaffoldBackgroundColor: const Color(0xFFf8fafc),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFffffff),
        foregroundColor: Color(0xFF1e293b),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFFffffff),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: textTheme,
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3b82f6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFe2e8f0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFe2e8f0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3b82f6), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFf1f5f9),
      ),
    );
  }

  ThemeData get darkTheme {
    // Windows 下使用微软雅黑以获得更好的中文渲染
    final textTheme = Platform.isWindows
        ? ThemeData.dark().textTheme.copyWith(
              bodyLarge: const TextStyle(
                color: Color(0xFFf8fafc),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodyMedium: const TextStyle(
                color: Color(0xFFf8fafc),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              bodySmall: const TextStyle(
                color: Color(0xFF94a3b8),
                fontWeight: FontWeight.w400,
                fontFamily: 'Microsoft YaHei',
              ),
              titleLarge: const TextStyle(
                color: Color(0xFFf8fafc),
                fontWeight: FontWeight.w600,
                fontFamily: 'Microsoft YaHei',
              ),
              titleMedium: const TextStyle(
                color: Color(0xFFf8fafc),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
              titleSmall: const TextStyle(
                color: Color(0xFFf8fafc),
                fontWeight: FontWeight.w500,
                fontFamily: 'Microsoft YaHei',
              ),
            )
        : const TextTheme(
            bodyLarge: TextStyle(color: Color(0xFFf8fafc)),
            bodyMedium: TextStyle(color: Color(0xFFf8fafc)),
            bodySmall: TextStyle(color: Color(0xFF94a3b8)),
            titleLarge: TextStyle(color: Color(0xFFf8fafc)),
            titleMedium: TextStyle(color: Color(0xFFf8fafc)),
            titleSmall: TextStyle(color: Color(0xFFf8fafc)),
          );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3b82f6),
        brightness: Brightness.dark,
        primary: const Color(0xFF60a5fa),
        secondary: const Color(0xFF34d399),
        surface: const Color(0xFF1e293b),
        background: const Color(0xFF0f172a),
        error: const Color(0xFFf87171),
      ),
      scaffoldBackgroundColor: const Color(0xFF0f172a),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1e293b),
        foregroundColor: Color(0xFFf8fafc),
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: const CardThemeData(
        color: Color(0xFF1e293b),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textTheme: textTheme,
      fontFamily: Platform.isWindows ? 'Microsoft YaHei' : null,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3b82f6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF334155)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF60a5fa), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFF334155),
      ),
    );
  }
}
