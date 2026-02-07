/// 配置状态管理
/// 
/// 管理应用配置的加载、保存和验证
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/config.dart';
import '../services/storage_service.dart';
import 'messages_provider.dart'; // 导入 storageServiceProvider

/// 配置状态类
class ConfigState {
  final Config? config;
  final bool isLoading;
  final String? error;
  final bool hasUnsavedChanges;

  const ConfigState({
    this.config,
    this.isLoading = false,
    this.error,
    this.hasUnsavedChanges = false,
  });

  ConfigState copyWith({
    Config? config,
    bool? isLoading,
    String? error,
    bool? hasUnsavedChanges,
  }) {
    return ConfigState(
      config: config ?? this.config,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      hasUnsavedChanges: hasUnsavedChanges ?? this.hasUnsavedChanges,
    );
  }

  bool get hasConfig => config != null;
  bool get isValid => config?.isValid ?? false;
}

/// 配置验证结果
class ConfigValidation {
  final bool isValid;
  final String? error;

  const ConfigValidation({
    required this.isValid,
    this.error,
  });

  factory ConfigValidation.valid() => const ConfigValidation(isValid: true);
  factory ConfigValidation.invalid(String error) => ConfigValidation(
        isValid: false,
        error: error,
      );
}

/// 配置状态管理器
class ConfigNotifier extends StateNotifier<ConfigState> {
  final StorageService _storage;

  ConfigNotifier(this._storage) : super(const ConfigState()) {
    _loadConfig();
  }

  /// 加载配置
  Future<void> _loadConfig() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final config = _storage.getConfig();
      state = ConfigState(
        config: config,
        isLoading: false,
      );
    } catch (e) {
      state = ConfigState(
        isLoading: false,
        error: '加载配置失败: $e',
      );
    }
  }

  /// 更新配置（不保存）
  void updateConfig(Config config) {
    state = state.copyWith(
      config: config,
      hasUnsavedChanges: true,
      error: null,
    );
  }

  /// 保存配置
  Future<bool> saveConfig() async {
    if (state.config == null) {
      state = state.copyWith(error: '没有可保存的配置');
      return false;
    }

    // 验证配置
    final validation = validateConfig(state.config!);
    if (!validation.isValid) {
      state = state.copyWith(error: validation.error);
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _storage.saveConfig(state.config!);
      state = state.copyWith(
        isLoading: false,
        hasUnsavedChanges: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '保存配置失败: $e',
      );
      return false;
    }
  }

  /// 删除配置
  Future<void> deleteConfig() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _storage.deleteConfig();
      state = const ConfigState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '删除配置失败: $e',
      );
    }
  }

  /// 重新加载配置
  Future<void> reloadConfig() async {
    await _loadConfig();
  }

  /// 验证配置
  ConfigValidation validateConfig(Config config) {
    // 验证 Gateway URL
    if (config.gatewayUrl.isEmpty) {
      return ConfigValidation.invalid('Gateway URL 不能为空');
    }

    if (!config.gatewayUrl.startsWith('ws://') &&
        !config.gatewayUrl.startsWith('wss://')) {
      return ConfigValidation.invalid('Gateway URL 必须以 ws:// 或 wss:// 开头');
    }

    // 验证密码长度（如果提供）
    if (config.password != null &&
        config.password!.isNotEmpty &&
        config.password!.length < 6) {
      return ConfigValidation.invalid('密码长度至少 6 个字符');
    }

    // 验证重连间隔
    if (config.reconnectInterval < 1 || config.reconnectInterval > 60) {
      return ConfigValidation.invalid('重连间隔必须在 1-60 秒之间');
    }

    // 验证最大重连次数
    if (config.maxReconnectAttempts < 0 || config.maxReconnectAttempts > 100) {
      return ConfigValidation.invalid('最大重连次数必须在 0-100 之间');
    }

    return ConfigValidation.valid();
  }

  /// 更新 Gateway URL
  void updateGatewayUrl(String url) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(gatewayUrl: url);
      updateConfig(newConfig);
    }
  }

  /// 更新密码
  void updatePassword(String? password) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(password: password);
      updateConfig(newConfig);
    }
  }

  /// 更新 Agent ID
  void updateAgentId(String? agentId) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(agentId: agentId);
      updateConfig(newConfig);
    }
  }

  /// 更新自动重连设置
  void updateAutoReconnect(bool enabled) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(autoReconnect: enabled);
      updateConfig(newConfig);
    }
  }

  /// 更新重连间隔
  void updateReconnectInterval(int seconds) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(reconnectInterval: seconds);
      updateConfig(newConfig);
    }
  }

  /// 更新最大重连次数
  void updateMaxReconnectAttempts(int attempts) {
    if (state.config != null) {
      final newConfig = state.config!.copyWith(maxReconnectAttempts: attempts);
      updateConfig(newConfig);
    }
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取配置摘要
  Map<String, dynamic> getConfigSummary() {
    if (state.config == null) {
      return {'hasConfig': false};
    }

    return {
      'hasConfig': true,
      'gatewayUrl': state.config!.gatewayUrl,
      'hasPassword': state.config!.password != null,
      'hasAgentId': state.config!.agentId != null,
      'autoReconnect': state.config!.autoReconnect,
      'reconnectInterval': state.config!.reconnectInterval,
      'maxReconnectAttempts': state.config!.maxReconnectAttempts,
      'isValid': state.config!.isValid,
    };
  }
}

/// 配置 Provider
final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ConfigNotifier(storage);
});

/// 便捷访问器
extension ConfigProviderExtension on WidgetRef {
  /// 当前配置
  Config? get config => read(configProvider).config;
  
  /// 是否有配置
  bool get hasConfig => read(configProvider).hasConfig;
  
  /// 配置是否有效
  bool get isConfigValid => read(configProvider).isValid;
  
  /// Gateway URL
  String? get gatewayUrl => read(configProvider).config?.gatewayUrl;
}
