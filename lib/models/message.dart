/// 消息数据模型
/// 
/// 表示聊天界面中的一条消息
library;

import 'package:hive/hive.dart';

part 'message.g.dart';

/// 消息状态枚举
enum MessageStatus {
  /// 发送中
  sending,
  /// 发送成功
  sent,
  /// 发送失败
  failed,
  /// 接收到的消息
  received,
}

/// 消息模型
@HiveType(typeId: 0)
class Message {
  /// 消息唯一标识
  @HiveField(0)
  final String id;

  /// 消息内容
  @HiveField(1)
  final String content;

  /// 是否为用户发送的消息
  @HiveField(2)
  final bool isUser;

  /// 消息时间戳
  @HiveField(3)
  final DateTime timestamp;

  /// 消息状态
  @HiveField(4)
  final MessageStatus status;

  /// 会话ID（可选）
  @HiveField(5)
  final String? sessionId;

  const Message({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.received,
    this.sessionId,
  });

  /// 创建用户消息
  factory Message.user({
    required String content,
    String? sessionId,
  }) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      sessionId: sessionId,
    );
  }

  /// 创建 AI 消息
  factory Message.ai({
    required String id,
    required String content,
    String? sessionId,
  }) {
    return Message(
      id: id,
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.received,
      sessionId: sessionId,
    );
  }

  /// 复制并更新消息
  Message copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
    String? sessionId,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'sessionId': sessionId,
    };
  }

  /// 从 JSON 创建
  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.received,
      ),
      sessionId: json['sessionId'] as String?,
    );
  }

  @override
  String toString() {
    return 'Message(id: $id, content: ${content.substring(0, content.length > 20 ? 20 : content.length)}..., isUser: $isUser, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
