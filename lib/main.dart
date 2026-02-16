import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/chat_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart' as providers;
import 'providers/service_manager_provider.dart';
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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // 应用进入后台或被销毁，断开所有连接
        _disconnectAllServices();
        break;
      case AppLifecycleState.resumed:
        // 应用恢复，重新连接活跃服务
        _reconnectActiveService();
        break;
      default:
        break;
    }
  }

  void _disconnectAllServices() {
    // 应用进入后台或被销毁时，连接会在 ChatScreen 的生命周期中处理
    // 这里只记录日志
    print('📱 应用进入后台/被销毁');
  }

  void _reconnectActiveService() {
    // 应用恢复时，连接会在 ChatScreen 的生命周期中处理
    // 这里只记录日志
    print('📱 应用恢复前台');
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(providers.themeProvider);

    return MaterialApp(
      title: 'ClawChat',
      debugShowCheckedModeBanner: false,
      theme: providers.AppTheme.lightTheme,
      darkTheme: providers.AppTheme.darkTheme,
      themeMode: _getThemeMode(themeState.mode),
      home: const AppHome(),
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

/// 应用主页 - 根据是否有服务显示不同页面
class AppHome extends ConsumerWidget {
  const AppHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceManager = ref.watch(serviceManagerProvider);

    // 如果没有服务，显示欢迎页
    if (!serviceManager.hasServices) {
      return const WelcomeScreen();
    }

    // 有服务，显示聊天页面
    return const ChatScreen();
  }
}

/// 欢迎页面 - 引导用户添加第一个服务
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo 或图标
                Icon(
                  Icons.chat_bubble_outline,
                  size: 120,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),

                // 欢迎标题
                Text(
                  '欢迎使用 ClawChat',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 描述文字
                Text(
                  '开始之前，请先添加一个 OpenClaw 服务',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // 添加服务按钮
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加服务'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
