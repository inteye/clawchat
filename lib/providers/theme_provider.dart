/// 主题状态管理
/// 
/// 管理应用主题（深色/浅色模式）
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// 主题模式
enum ThemeMode {
  light,
  dark,
  system,
}

/// 主题状态类
class ThemeState {
  final ThemeMode mode;
  final bool isLoading;

  const ThemeState({
    this.mode = ThemeMode.system,
    this.isLoading = false,
  });

  ThemeState copyWith({
    ThemeMode? mode,
    bool? isLoading,
  }) {
    return ThemeState(
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool get isDark => mode == ThemeMode.dark;
  bool get isLight => mode == ThemeMode.light;
  bool get isSystem => mode == ThemeMode.system;
}

/// 主题状态管理器
class ThemeNotifier extends StateNotifier<ThemeState> {
  final StorageService _storage;
  static const String _themeKey = 'theme_mode';

  ThemeNotifier(this._storage) : super(const ThemeState()) {
    _loadTheme();
  }

  /// 加载主题设置
  Future<void> _loadTheme() async {
    state = state.copyWith(isLoading: true);

    try {
      final savedMode = await _storage.getString(_themeKey);
      final mode = _parseThemeMode(savedMode);
      state = ThemeState(mode: mode, isLoading: false);
    } catch (e) {
      state = const ThemeState(isLoading: false);
    }
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(mode: mode);
    await _storage.saveString(_themeKey, mode.toString());
  }

  /// 切换到浅色模式
  Future<void> setLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  /// 切换到深色模式
  Future<void> setDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  /// 切换到系统模式
  Future<void> setSystemMode() async {
    await setThemeMode(ThemeMode.system);
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    final newMode = state.isDark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// 解析主题模式
  ThemeMode _parseThemeMode(String? value) {
    if (value == null) return ThemeMode.system;
    
    switch (value) {
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
      case 'ThemeMode.system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }
}

/// 主题 Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier(StorageService());
});

/// 应用主题数据
class AppTheme {
  /// 浅色主题
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  /// 深色主题
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
      ),
      cardTheme: CardTheme(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// 便捷访问器
extension ThemeProviderExtension on WidgetRef {
  /// 当前主题模式
  ThemeMode get themeMode => read(themeProvider).mode;
  
  /// 是否深色模式
  bool get isDarkMode => read(themeProvider).isDark;
  
  /// 是否浅色模式
  bool get isLightMode => read(themeProvider).isLight;
}
