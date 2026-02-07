/// 本地存储服务
/// 
/// 使用 Hive 管理本地数据存储
library;

import 'package:hive_flutter/hive_flutter.dart';
import '../models/config.dart';
import '../models/message.dart';
import '../utils/constants.dart';

/// 存储服务（单例）
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  Box<Config>? _configBox;
  Box<Message>? _messagesBox;
  Box? _settingsBox;

  /// 初始化 Hive
  Future<void> initialize() async {
    await Hive.initFlutter();

    // 注册适配器
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConfigAdapter());
    }

    // 打开 Box
    _configBox = await Hive.openBox<Config>(
      AppConstants.configBoxName,
      // 可以添加加密
      // encryptionCipher: HiveAesCipher(encryptionKey),
    );

    _messagesBox = await Hive.openBox<Message>(
      AppConstants.messagesBoxName,
    );

    _settingsBox = await Hive.openBox('settings');

    print('存储服务初始化完成');
  }

  // ==================== 通用键值存储 ====================

  /// 保存字符串
  Future<void> saveString(String key, String value) async {
    await _settingsBox?.put(key, value);
  }

  /// 获取字符串
  Future<String?> getString(String key) async {
    return _settingsBox?.get(key);
  }

  /// 保存整数
  Future<void> saveInt(String key, int value) async {
    await _settingsBox?.put(key, value);
  }

  /// 获取整数
  Future<int?> getInt(String key) async {
    return _settingsBox?.get(key);
  }

  /// 保存布尔值
  Future<void> saveBool(String key, bool value) async {
    await _settingsBox?.put(key, value);
  }

  /// 获取布尔值
  Future<bool?> getBool(String key) async {
    return _settingsBox?.get(key);
  }

  /// 删除键
  Future<void> deleteKey(String key) async {
    await _settingsBox?.delete(key);
  }

  // ==================== 配置管理 ====================

  /// 保存配置
  Future<void> saveConfig(Config config) async {
    await _configBox?.put('current', config);
    print('配置已保存');
  }

  /// 获取配置
  Config? getConfig() {
    return _configBox?.get('current');
  }

  /// 删除配置
  Future<void> deleteConfig() async {
    await _configBox?.delete('current');
    print('配置已删除');
  }

  /// 是否有配置
  bool hasConfig() {
    return _configBox?.containsKey('current') ?? false;
  }

  // ==================== 消息管理 ====================

  /// 保存消息
  Future<void> saveMessage(Message message) async {
    await _messagesBox?.put(message.id, message);
  }

  /// 批量保存消息
  Future<void> saveMessages(List<Message> messages) async {
    final map = {for (var msg in messages) msg.id: msg};
    await _messagesBox?.putAll(map);
  }

  /// 获取所有消息
  List<Message> getAllMessages() {
    return _messagesBox?.values.toList() ?? [];
  }

  /// 获取指定会话的消息
  List<Message> getMessagesBySession(String? sessionId) {
    if (sessionId == null) {
      return getAllMessages();
    }
    
    return _messagesBox?.values
        .where((msg) => msg.sessionId == sessionId)
        .toList() ?? [];
  }

  /// 获取最近的消息
  List<Message> getRecentMessages({int limit = 50}) {
    final messages = getAllMessages();
    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return messages.take(limit).toList();
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    await _messagesBox?.delete(messageId);
  }

  /// 清空所有消息
  Future<void> clearAllMessages() async {
    await _messagesBox?.clear();
    print('所有消息已清空');
  }

  /// 清空指定会话的消息
  Future<void> clearSessionMessages(String sessionId) async {
    final messages = getMessagesBySession(sessionId);
    for (var msg in messages) {
      await deleteMessage(msg.id);
    }
    print('会话 $sessionId 的消息已清空');
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String messageId, MessageStatus status) async {
    final message = _messagesBox?.get(messageId);
    if (message != null) {
      final updated = message.copyWith(status: status);
      await _messagesBox?.put(messageId, updated);
    }
  }

  /// 获取消息数量
  int getMessageCount() {
    return _messagesBox?.length ?? 0;
  }

  /// 获取指定会话的消息数量
  int getSessionMessageCount(String? sessionId) {
    if (sessionId == null) {
      return getMessageCount();
    }
    return getMessagesBySession(sessionId).length;
  }

  // ==================== 统计信息 ====================

  /// 获取存储统计信息
  Map<String, dynamic> getStorageStats() {
    return {
      'totalMessages': getMessageCount(),
      'hasConfig': hasConfig(),
      'configBoxSize': _configBox?.length ?? 0,
      'messagesBoxSize': _messagesBox?.length ?? 0,
    };
  }

  // ==================== 清理与维护 ====================

  /// 清理旧消息（保留最近 N 条）
  Future<void> cleanupOldMessages({int keepRecent = 1000}) async {
    final messages = getAllMessages();
    if (messages.length <= keepRecent) return;

    messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final toDelete = messages.skip(keepRecent);

    for (var msg in toDelete) {
      await deleteMessage(msg.id);
    }

    print('已清理 ${toDelete.length} 条旧消息');
  }

  /// 压缩数据库
  Future<void> compact() async {
    await _configBox?.compact();
    await _messagesBox?.compact();
    print('数据库已压缩');
  }

  /// 关闭所有 Box
  Future<void> close() async {
    await _configBox?.close();
    await _messagesBox?.close();
    await _settingsBox?.close();
    print('存储服务已关闭');
  }

  /// 释放资源
  void dispose() {
    close();
  }
}

// ==================== Hive 适配器（需要代码生成） ====================

// 这些适配器需要通过 build_runner 生成
// 运行: flutter pub run build_runner build

/// Message 适配器（占位，实际由 build_runner 生成）
class MessageAdapter extends TypeAdapter<Message> {
  @override
  final int typeId = 0;

  @override
  Message read(BinaryReader reader) {
    return Message(
      id: reader.readString(),
      content: reader.readString(),
      isUser: reader.readBool(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      status: MessageStatus.values[reader.readInt()],
      sessionId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Message obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.content);
    writer.writeBool(obj.isUser);
    writer.writeInt(obj.timestamp.millisecondsSinceEpoch);
    writer.writeInt(obj.status.index);
    writer.writeString(obj.sessionId ?? '');
  }
}

/// Config 适配器（占位，实际由 build_runner 生成）
class ConfigAdapter extends TypeAdapter<Config> {
  @override
  final int typeId = 1;

  @override
  Config read(BinaryReader reader) {
    return Config(
      gatewayUrl: reader.readString(),
      password: reader.readString(),
      autoReconnect: reader.readBool(),
      reconnectInterval: reader.readInt(),
      maxReconnectAttempts: reader.readInt(),
      agentId: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Config obj) {
    writer.writeString(obj.gatewayUrl);
    writer.writeString(obj.password ?? '');
    writer.writeBool(obj.autoReconnect);
    writer.writeInt(obj.reconnectInterval);
    writer.writeInt(obj.maxReconnectAttempts);
    writer.writeString(obj.agentId ?? '');
  }
}
