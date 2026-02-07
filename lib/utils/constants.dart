/// 常量定义
/// 
/// 应用中使用的所有常量
library;

/// 应用常量
class AppConstants {
  AppConstants._();

  /// 应用名称
  static const String appName = 'ClawChat';

  /// 应用版本
  static const String appVersion = '0.1.0';

  /// OpenClaw 默认端口
  static const int defaultPort = 18789;

  /// 默认超时时间（毫秒）
  static const int defaultTimeout = 30000;

  /// 心跳间隔（毫秒）
  static const int heartbeatInterval = 30000;

  /// 最大消息长度
  static const int maxMessageLength = 10000;

  /// 本地存储 Box 名称
  static const String configBoxName = 'config';
  static const String messagesBoxName = 'messages';

  /// 加密密钥（实际使用时应该从安全存储获取）
  static const String encryptionKey = 'clawchat_secure_key_2024';
}

/// WebSocket 协议常量
class ProtocolConstants {
  ProtocolConstants._();

  /// 消息类型
  static const String typeMessageSend = 'message.send';
  static const String typeAgentProcess = 'agent.process';
  static const String typeResponseChunk = 'response.chunk';
  static const String typeResponseComplete = 'response.complete';
  static const String typeToolCall = 'tool.call';
  static const String typeSessionUpdate = 'session.update';
  static const String typeTyping = 'typing';
  static const String typeError = 'error';
  static const String typeAuth = 'auth';
  static const String typeAuthSuccess = 'auth.success';
  static const String typeAuthFailed = 'auth.failed';

  /// 认证模式
  static const String authModePassword = 'password';

  /// Thinking 级别
  static const String thinkingHigh = 'high';
  static const String thinkingMedium = 'medium';
  static const String thinkingLow = 'low';
}

/// UI 常量
class UIConstants {
  UIConstants._();

  /// 边距
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;

  /// 圆角
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;

  /// 消息气泡最大宽度比例
  static const double messageBubbleMaxWidthRatio = 0.75;

  /// 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration typingIndicatorDuration = Duration(milliseconds: 500);
}

/// 错误消息
class ErrorMessages {
  ErrorMessages._();

  static const String invalidUrl = '请输入有效的 WebSocket URL';
  static const String urlMustBeSecure = 'URL 必须使用 wss:// 协议';
  static const String connectionFailed = '连接失败，请检查网络和配置';
  static const String authFailed = '认证失败，请检查密码';
  static const String sendMessageFailed = '发送消息失败';
  static const String messageEmpty = '消息不能为空';
  static const String messageTooLong = '消息过长，请缩短后重试';
  static const String networkError = '网络错误，请检查网络连接';
  static const String unknownError = '未知错误';
}

/// 成功消息
class SuccessMessages {
  SuccessMessages._();

  static const String connected = '连接成功';
  static const String authenticated = '认证成功';
  static const String messageSent = '消息已发送';
  static const String configSaved = '配置已保存';
}
