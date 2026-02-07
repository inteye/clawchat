/// 启动页
/// 
/// 应用启动时的欢迎页面，检查配置并自动跳转
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';
import '../providers/theme_provider.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _checkConfigAndNavigate();
  }

  /// 设置动画
  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ));

    _animationController.forward();
  }

  /// 检查配置并导航
  Future<void> _checkConfigAndNavigate() async {
    // 等待动画完成
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    final configState = ref.read(configProvider);

    // 检查是否有有效配置
    if (configState.hasConfig && configState.isValid) {
      // 有配置，跳转到聊天页
      _navigateToChat();
    } else {
      // 无配置，跳转到设置页
      _navigateToSettings();
    }
  }

  /// 跳转到聊天页
  void _navigateToChat() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ChatScreen(),
      ),
    );
  }

  /// 跳转到设置页
  void _navigateToSettings() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(isFirstTime: true),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.blue.shade900,
                    Colors.purple.shade900,
                  ]
                : [
                    Colors.blue.shade400,
                    Colors.purple.shade400,
                  ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // 应用名称
                      Text(
                        'ClawChat',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // 副标题
                      Text(
                        'OpenClaw 直连客户端',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 50),
                      
                      // 加载指示器
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
