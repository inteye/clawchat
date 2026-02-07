import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/splash_screen.dart';
import 'providers/theme_provider.dart' as providers;
import 'services/storage_service.dart';

void main() async {
  // 确保 Flutter 绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化存储服务
  await StorageService().initialize();

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(providers.themeProvider);

    return MaterialApp(
      title: 'ClawChat',
      debugShowCheckedModeBanner: false,
      theme: providers.AppTheme.lightTheme,
      darkTheme: providers.AppTheme.darkTheme,
      themeMode: _getThemeMode(themeState.mode),
      home: const SplashScreen(),
    );
  }

  /// 转换主题模式
  ThemeMode _getThemeMode(providers.ThemeMode mode) {
    switch (mode) {
      case providers.ThemeMode.light:
        return ThemeMode.light;
      case providers.ThemeMode.dark:
        return ThemeMode.dark;
      case providers.ThemeMode.system:
        return ThemeMode.system;
    }
  }
}
