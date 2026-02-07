/// 配置数据模型
/// 
/// 存储 OpenClaw Gateway 连接配置
library;

import 'package:hive/hive.dart';

part 'config.g.dart';

/// 配置模型
@HiveType(typeId: 1)
class Config {
  /// Gateway WebSocket URL
  @HiveField(0)
  final String gatewayUrl;

  /// 认证密码（可选）
  @HiveField(1)
  final String? password;

  /// 是否自动重连
  @HiveField(2)
  final bool autoReconnect;

  /// 重连间隔（毫秒）
  @HiveField(3)
  final int reconnectInterval;

  /// 最大重连次数
  @HiveField(4)
  final int maxReconnectAttempts;

  /// Agent ID（可选，指定路由到特定 Agent）
  @HiveField(5)
  final String? agentId;

  const Config({
    required this.gatewayUrl,
    this.password,
    this.autoReconnect = true,
    this.reconnectInterval = 3000,
    this.maxReconnectAttempts = 5,
    this.agentId,
  });

  /// 默认配置
  factory Config.defaultConfig() {
    return const Config(
      gatewayUrl: '',
      autoReconnect: true,
      reconnectInterval: 3000,
      maxReconnectAttempts: 5,
    );
  }

  /// 验证配置是否有效
  bool get isValid {
    if (gatewayUrl.isEmpty) return false;
    if (!gatewayUrl.startsWith('wss://') && !gatewayUrl.startsWith('ws://')) {
      return false;
    }
    return true;
  }

  /// 是否强制使用安全连接
  bool get isSecure => gatewayUrl.startsWith('wss://');

  /// 复制并更新配置
  Config copyWith({
    String? gatewayUrl,
    String? password,
    bool? autoReconnect,
    int? reconnectInterval,
    int? maxReconnectAttempts,
    String? agentId,
  }) {
    return Config(
      gatewayUrl: gatewayUrl ?? this.gatewayUrl,
      password: password ?? this.password,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectInterval: reconnectInterval ?? this.reconnectInterval,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      agentId: agentId ?? this.agentId,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'gatewayUrl': gatewayUrl,
      'password': password,
      'autoReconnect': autoReconnect,
      'reconnectInterval': reconnectInterval,
      'maxReconnectAttempts': maxReconnectAttempts,
      'agentId': agentId,
    };
  }

  /// 从 JSON 创建
  factory Config.fromJson(Map<String, dynamic> json) {
    return Config(
      gatewayUrl: json['gatewayUrl'] as String,
      password: json['password'] as String?,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      reconnectInterval: json['reconnectInterval'] as int? ?? 3000,
      maxReconnectAttempts: json['maxReconnectAttempts'] as int? ?? 5,
      agentId: json['agentId'] as String?,
    );
  }

  @override
  String toString() {
    return 'Config(gatewayUrl: $gatewayUrl, autoReconnect: $autoReconnect, agentId: $agentId)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Config &&
        other.gatewayUrl == gatewayUrl &&
        other.password == password &&
        other.autoReconnect == autoReconnect &&
        other.reconnectInterval == reconnectInterval &&
        other.maxReconnectAttempts == maxReconnectAttempts &&
        other.agentId == agentId;
  }

  @override
  int get hashCode {
    return Object.hash(
      gatewayUrl,
      password,
      autoReconnect,
      reconnectInterval,
      maxReconnectAttempts,
      agentId,
    );
  }
}
