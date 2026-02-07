/// 消息状态管理
/// 
/// 管理聊天消息的发送、接收和存储
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../services/protocol_parser.dart';
import 'connection_provider.dart';
import 'config_provider.dart';

/// 存储服务 Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// 消息状态类
class MessagesState {
  final List<Message> messages;
  final bool isLoading;
  final String? error;
  final Message? streamingMessage; // 当前正在接收的流式消息

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
    this.streamingMessage,
  });

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoading,
    String? error,
    Message? streamingMessage,
    bool clearStreamingMessage = false,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      streamingMessage: clearStreamingMessage ? null : (streamingMessage ?? this.streamingMessage),
    );
  }

  bool get hasMessages => messages.isNotEmpty;
  bool get isStreaming => streamingMessage != null;
}

/// 消息状态管理器
class MessagesNotifier extends StateNotifier<MessagesState> {
  final WebSocketService _wsService;
  final StorageService _storage;
  final Ref _ref;
  
  StreamSubscription? _messageSubscription;
  final Map<String, StreamingAccumulator> _accumulators = {};

  MessagesNotifier(this._wsService, this._storage, this._ref) 
      : super(const MessagesState()) {
    _init();
  }

  /// 初始化
  void _init() {
    _loadMessages();
    _listenToMessages();
  }

  /// 加载历史消息
  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = _storage.getAllMessages();
      state = MessagesState(
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = MessagesState(
        isLoading: false,
        error: '加载消息失败: $e',
      );
    }
  }

  /// 监听新消息
  void _listenToMessages() {
    _messageSubscription = _wsService.messageStream.listen(
      _handleIncomingMessage,
      onError: (error) {
        state = state.copyWith(error: '接收消息失败: $error');
      },
    );
  }

  /// 处理接收到的消息
  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final parsed = ProtocolParser.parseMessage(data);
      
      if (parsed.isStreamChunk) {
        _handleStreamChunk(parsed);
      } else if (parsed.isComplete) {
        _handleCompleteMessage(parsed);
      }
    } catch (e) {
      state = state.copyWith(error: '解析消息失败: $e');
    }
  }

  /// 处理流式消息块
  void _handleStreamChunk(ParsedMessage parsed) {
    final messageId = parsed.messageId ?? 'unknown';
    
    // 获取或创建累加器
    if (!_accumulators.containsKey(messageId)) {
      _accumulators[messageId] = StreamingAccumulator();
    }
    
    final accumulator = _accumulators[messageId]!;
    accumulator.addChunk(parsed.content ?? '');
    
    // 更新流式消息状态
    final streamingMessage = Message(
      id: messageId,
      content: accumulator.fullContent,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    state = state.copyWith(streamingMessage: streamingMessage);
  }

  /// 处理完整消息
  void _handleCompleteMessage(ParsedMessage parsed) {
    final messageId = parsed.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();
    
    // 如果有累加器，使用累加的内容
    String content = parsed.content ?? '';
    if (_accumulators.containsKey(messageId)) {
      content = _accumulators[messageId]!.fullContent;
      _accumulators.remove(messageId);
    }
    
    final message = Message(
      id: messageId,
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );
    
    // 添加到消息列表
    _addMessage(message);
    
    // 清除流式消息状态
    state = state.copyWith(clearStreamingMessage: true);
  }

  /// 发送消息
  Future<bool> sendMessage(String content) async {
    // 检查连接状态
    final connectionState = _ref.read(connectionProvider);
    if (!connectionState.isConnected) {
      state = state.copyWith(error: '未连接到服务器');
      return false;
    }

    // 获取配置
    final config = _ref.read(configProvider).config;
    
    // 创建用户消息
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    // 添加到列表
    _addMessage(userMessage);

    try {
      // 发送消息
      final payload = ProtocolParser.createMessagePayload(
        content: content,
        agentId: config?.agentId,
      );
      
      _wsService.send(payload);
      
      // 更新消息状态为已发送
      _updateMessageStatus(userMessage.id, MessageStatus.sent);
      
      return true;
    } catch (e) {
      // 更新消息状态为失败
      _updateMessageStatus(userMessage.id, MessageStatus.failed);
      state = state.copyWith(error: '发送消息失败: $e');
      return false;
    }
  }

  /// 重新发送失败的消息
  Future<bool> resendMessage(String messageId) async {
    final message = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw Exception('消息不存在'),
    );
    
    if (message.status != MessageStatus.failed) {
      return false;
    }
    
    // 更新状态为发送中
    _updateMessageStatus(messageId, MessageStatus.sending);
    
    // 重新发送
    return await sendMessage(message.content);
  }

  /// 添加消息
  void _addMessage(Message message) {
    final updatedMessages = [...state.messages, message];
    state = state.copyWith(messages: updatedMessages);
    
    // 保存到本地
    _storage.saveMessage(message);
  }

  /// 更新消息状态
  void _updateMessageStatus(String messageId, MessageStatus status) {
    final updatedMessages = state.messages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(status: status);
      }
      return m;
    }).toList();
    
    state = state.copyWith(messages: updatedMessages);
    
    // 更新本地存储
    final message = updatedMessages.firstWhere((m) => m.id == messageId);
    _storage.saveMessage(message);
  }

  /// 删除消息
  Future<void> deleteMessage(String messageId) async {
    final updatedMessages = state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);
    
    await _storage.deleteMessage(messageId);
  }

  /// 清空所有消息
  Future<void> clearAllMessages() async {
    state = const MessagesState();
    await _storage.clearAllMessages();
  }

  /// 获取当前会话的消息
  List<Message> getSessionMessages(String? sessionId) {
    if (sessionId == null) return state.messages;
    return _storage.getMessagesBySession(sessionId);
  }

  /// 清除错误
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// 获取消息统计
  Map<String, dynamic> getMessageStats() {
    return {
      'total': state.messages.length,
      'user': state.messages.where((m) => m.isUser).length,
      'ai': state.messages.where((m) => !m.isUser).length,
      'failed': state.messages.where((m) => m.status == MessageStatus.failed).length,
      'isStreaming': state.isStreaming,
    };
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _accumulators.clear();
    super.dispose();
  }
}

/// 消息 Provider
final messagesProvider = StateNotifierProvider<MessagesNotifier, MessagesState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  final storage = ref.watch(storageServiceProvider);
  return MessagesNotifier(wsService, storage, ref);
});

/// 便捷访问器
extension MessagesProviderExtension on WidgetRef {
  /// 获取所有消息
  List<Message> get messages => read(messagesProvider).messages;
  
  /// 是否有消息
  bool get hasMessages => read(messagesProvider).hasMessages;
  
  /// 是否正在接收流式消息
  bool get isStreaming => read(messagesProvider).isStreaming;
  
  /// 当前流式消息
  Message? get streamingMessage => read(messagesProvider).streamingMessage;
}
