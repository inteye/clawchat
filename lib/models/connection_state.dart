/// 连接状态模型
///
/// 表示 WebSocket 连接的当前状态
library;

/// 连接状态枚举
enum ConnectionStatus {
  /// 未连接
  disconnected,

  /// 连接中
  connecting,

  /// 已连接
  connected,

  /// 认证中
  authenticating,

  /// 已认证
  authenticated,

  /// 重连中
  reconnecting,

  /// 连接错误
  error,
}

/// 连接状态模型
class ConnectionState {
  /// 当前状态
  final ConnectionStatus status;

  /// 错误信息（如果有）
  final String? error;

  /// 重连尝试次数
  final int reconnectAttempts;

  /// 最后连接时间
  final DateTime? lastConnectedAt;

  /// 是否正在输入
  final bool isTyping;

  const ConnectionState({
    required this.status,
    this.error,
    this.reconnectAttempts = 0,
    this.lastConnectedAt,
    this.isTyping = false,
  });

  /// 初始状态
  factory ConnectionState.initial() {
    return const ConnectionState(
      status: ConnectionStatus.disconnected,
    );
  }

  /// 连接中状态
  factory ConnectionState.connecting() {
    return const ConnectionState(
      status: ConnectionStatus.connecting,
    );
  }

  /// 已连接状态
  factory ConnectionState.connected() {
    return ConnectionState(
      status: ConnectionStatus.connected,
      lastConnectedAt: DateTime.now(),
    );
  }

  /// 已认证状态
  factory ConnectionState.authenticated() {
    return ConnectionState(
      status: ConnectionStatus.authenticated,
      lastConnectedAt: DateTime.now(),
    );
  }

  /// 重连中状态
  factory ConnectionState.reconnecting(int attempts) {
    return ConnectionState(
      status: ConnectionStatus.reconnecting,
      reconnectAttempts: attempts,
    );
  }

  /// 错误状态
  factory ConnectionState.error(String error) {
    return ConnectionState(
      status: ConnectionStatus.error,
      error: error,
    );
  }

  /// 是否已连接
  bool get isConnected =>
      status == ConnectionStatus.connected ||
      status == ConnectionStatus.authenticated;

  /// 是否已断开
  bool get isDisconnected => status == ConnectionStatus.disconnected;

  /// 是否正在连接
  bool get isConnecting => status == ConnectionStatus.connecting;

  /// 是否有错误
  bool get hasError => status == ConnectionStatus.error || error != null;

  /// 是否可以发送消息
  bool get canSendMessage => isConnected && !isTyping;

  /// 状态描述
  String get statusText {
    switch (status) {
      case ConnectionStatus.disconnected:
        return '未连接';
      case ConnectionStatus.connecting:
        return '连接中...';
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.authenticating:
        return '认证中...';
      case ConnectionStatus.authenticated:
        return '已认证';
      case ConnectionStatus.reconnecting:
        return '重连中... (尝试 $reconnectAttempts)';
      case ConnectionStatus.error:
        return '连接错误';
    }
  }

  /// 复制并更新状态
  ConnectionState copyWith({
    ConnectionStatus? status,
    String? error,
    bool clearError = false,
    int? reconnectAttempts,
    DateTime? lastConnectedAt,
    bool? isTyping,
  }) {
    return ConnectionState(
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      lastConnectedAt: lastConnectedAt ?? this.lastConnectedAt,
      isTyping: isTyping ?? this.isTyping,
    );
  }

  @override
  String toString() {
    return 'ConnectionState(status: $status, error: $error, reconnectAttempts: $reconnectAttempts)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectionState &&
        other.status == status &&
        other.error == error &&
        other.reconnectAttempts == reconnectAttempts &&
        other.lastConnectedAt == lastConnectedAt &&
        other.isTyping == isTyping;
  }

  @override
  int get hashCode {
    return Object.hash(
      status,
      error,
      reconnectAttempts,
      lastConnectedAt,
      isTyping,
    );
  }
}
