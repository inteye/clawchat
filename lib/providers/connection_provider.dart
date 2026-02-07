/// 连接状态管理
/// 
/// 管理 WebSocket 连接状态和生命周期
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/connection_state.dart';
import '../services/websocket_service.dart';
import 'config_provider.dart';

/// WebSocket 服务 Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  return WebSocketService();
});

/// 连接状态管理器
class ConnectionNotifier extends StateNotifier<ConnectionState> {
  final WebSocketService _wsService;
  final Ref _ref;
  StreamSubscription? _stateSubscription;

  ConnectionNotifier(this._wsService, this._ref) 
      : super(const ConnectionState()) {
    _init();
  }

  /// 初始化
  void _init() {
    // 监听 WebSocket 状态变化
    _stateSubscription = _wsService.stateStream.listen((wsState) {
      state = ConnectionState(
        status: wsState.status,
        error: wsState.error,
        reconnectAttempts: wsState.reconnectAttempts,
        isTyping: state.isTyping,
      );
    });
  }

  /// 连接到 Gateway
  Future<bool> connect() async {
    // 获取配置
    final configState = _ref.read(configProvider);
    if (configState.config == null) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        error: '请先配置 Gateway 连接信息',
      );
      return false;
    }

    final config = configState.config!;

    // 验证配置
    final validation = _ref.read(configProvider.notifier).validateConfig(config);
    if (!validation.isValid) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        error: validation.error,
      );
      return false;
    }

    // 开始连接
    state = state.copyWith(
      status: ConnectionStatus.connecting,
      error: null,
    );

    try {
      await _wsService.connect(
        url: config.gatewayUrl,
        password: config.password,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        status: ConnectionStatus.disconnected,
        error: '连接失败: $e',
      );
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _wsService.disconnect();
  }

  /// 重新连接
  Future<bool> reconnect() async {
    await disconnect();
    await Future.delayed(const Duration(milliseconds: 500));
    return await connect();
  }

  /// 设置正在输入状态
  void setTyping(bool isTyping) {
    state = state.copyWith(isTyping: isTyping);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取连接统计信息
  Map<String, dynamic> getConnectionStats() {
    return {
      'status': state.status.toString(),
      'isConnected': state.isConnected,
      'reconnectAttempts': state.reconnectAttempts,
      'hasError': state.hasError,
      'error': state.error,
    };
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

/// 连接 Provider
final connectionProvider = StateNotifierProvider<ConnectionNotifier, ConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return ConnectionNotifier(wsService, ref);
});

/// 便捷访问器
extension ConnectionProviderExtension on WidgetRef {
  /// 是否已连接
  bool get isConnected => read(connectionProvider).isConnected;
  
  /// 是否正在连接
  bool get isConnecting => read(connectionProvider).isConnecting;
  
  /// 是否已断开
  bool get isDisconnected => read(connectionProvider).isDisconnected;
  
  /// 连接状态
  ConnectionStatus get connectionStatus => read(connectionProvider).status;
  
  /// 连接错误
  String? get connectionError => read(connectionProvider).error;
}
