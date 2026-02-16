/// 语言管理 Provider
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 语言状态
class LanguageState {
  final Locale locale;

  const LanguageState({
    required this.locale,
  });

  LanguageState copyWith({
    Locale? locale,
  }) {
    return LanguageState(
      locale: locale ?? this.locale,
    );
  }
}

/// 语言管理器
class LanguageNotifier extends StateNotifier<LanguageState> {
  LanguageNotifier()
      : super(const LanguageState(
          locale: Locale('en', ''), // 默认英文
        )) {
    _loadLanguage();
  }

  /// 加载保存的语言设置
  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString('language_code');

      if (languageCode != null) {
        state = state.copyWith(locale: Locale(languageCode, ''));
      }
    } catch (e) {
      print('加载语言设置失败: $e');
    }
  }

  /// 设置语言
  Future<void> setLanguage(Locale locale) async {
    state = state.copyWith(locale: locale);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', locale.languageCode);
    } catch (e) {
      print('保存语言设置失败: $e');
    }
  }

  /// 切换到英文
  Future<void> setEnglish() async {
    await setLanguage(const Locale('en', ''));
  }

  /// 切换到中文
  Future<void> setChinese() async {
    await setLanguage(const Locale('zh', ''));
  }
}

/// 语言 Provider
final languageProvider =
    StateNotifierProvider<LanguageNotifier, LanguageState>((ref) {
  return LanguageNotifier();
});
