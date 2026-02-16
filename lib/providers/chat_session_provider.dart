/// 聊天会话管理
///
/// 为每个服务创建独立的聊天会话
library;

import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';
import '../models/connection_state.dart';
import '../models/service_config.dart';
import '../models/config.dart';
import '../services/websocket_service.dart';
import '../services/storage_service.dart';
import '../services/protocol_parser.dart';
import '../utils/connection_diagnostics.dart';
import 'service_manager_provider.dart';

/// 聊天会话状态
class ChatSessionState {
  final String serviceId;
  final ServiceConfig serviceConfig;
  final ConnectionState connectionState;
  final List<Message> messages;
  final Message? streamingMessage;
  final bool isLoading;
  final String? error;

  const ChatSessionState({
    required this.serviceId,
    required this.serviceConfig,
    this.connectionState = const ConnectionState(
      status: ConnectionStatus.disconnected,
    ),
    this.messages = const [],
    this.streamingMessage,
    this.isLoading = false,
    this.error,
  });

  ChatSessionState copyWith({
    String? serviceId,
    ServiceConfig? serviceConfig,
    ConnectionState? connectionState,
    List<Message>? messages,
    Message? streamingMessage,
    bool clearStreamingMessage = false,
    bool? isLoading,
    String? error,
  }) {
    return ChatSessionState(
      serviceId: serviceId ?? this.serviceId,
      serviceConfig: serviceConfig ?? this.serviceConfig,
      connectionState: connectionState ?? this.connectionState,
      messages: messages ?? this.messages,
      streamingMessage: clearStreamingMessage
          ? null
          : (streamingMessage ?? this.streamingMessage),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isConnected => connectionState.isConnected;
  bool get isConnecting => connectionState.isConnecting;
  bool get hasMessages => messages.isNotEmpty;
  bool get isStreaming => streamingMessage != null;
}

/// 聊天会话管理器
class ChatSessionNotifier extends StateNotifier<ChatSessionState> {
  final String serviceId;
  final ServiceConfig serviceConfig;
  final StorageService _storage;

  late final WebSocketService _wsService;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _stateSubscription;
  final Map<String, StreamingAccumulator> _accumulators = {};

  ChatSessionNotifier({
    required this.serviceId,
    required this.serviceConfig,
    required StorageService storage,
  })  : _storage = storage,
        super(ChatSessionState(
          serviceId: serviceId,
          serviceConfig: serviceConfig,
        )) {
    _wsService = WebSocketService();
    _init();
  }

  /// 初始化
  void _init() {
    _wsService.initialize();
    _loadMessages();
    _listenToConnection();
    _listenToMessages();
  }

  /// 加载历史消息
  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final messages = _storage.getMessagesBySession(serviceId);
      state = state.copyWith(
        messages: messages,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '加载消息失败: $e',
      );
    }
  }

  /// 监听连接状态
  void _listenToConnection() {
    _stateSubscription = _wsService.stateStream.listen((connectionState) {
      print('📡 ChatSession 收到连接状态更新: ${connectionState.status}');
      state = state.copyWith(connectionState: connectionState);
      print(
          '📡 ChatSession 状态已更新: isConnected=${state.isConnected}, status=${state.connectionState.status}');
    });
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

      print(
          '🔍 解析消息: type=${parsed.type}, isComplete=${parsed.isComplete}, messageId=${parsed.messageId}');
      print('🔍 内容长度: ${parsed.content?.length ?? 0}');

      if (parsed.isStreamChunk) {
        print('📝 处理流式消息块');
        _handleStreamChunk(parsed);
      } else if (parsed.isComplete) {
        print('✅ 处理完整消息');
        _handleCompleteMessage(parsed);
      } else {
        print('⚠️  未知消息类型');
      }
    } catch (e) {
      print('❌ 解析消息失败: $e');
      state = state.copyWith(error: '解析消息失败: $e');
    }
  }

  /// 处理流式消息块
  void _handleStreamChunk(ParsedMessage parsed) {
    final messageId = parsed.messageId ?? 'unknown';
    final chunk = parsed.content ?? '';

    // 如果 chunk 为空，跳过（避免无意义的更新）
    if (chunk.isEmpty) {
      print('⚠️  收到空的消息块，跳过');
      return;
    }

    // 获取或创建累加器
    if (!_accumulators.containsKey(messageId)) {
      _accumulators[messageId] = StreamingAccumulator(messageId);
      print('📝 创建新的累加器: $messageId');
    }

    final accumulator = _accumulators[messageId]!;
    accumulator.addChunk(chunk);

    print('📝 添加消息块: "${chunk}" (累积长度: ${accumulator.fullContent.length})');

    // 更新流式消息状态
    final streamingMessage = Message(
      id: messageId,
      content: accumulator.fullContent,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      sessionId: serviceId,
    );

    state = state.copyWith(streamingMessage: streamingMessage);
  }

  /// 处理完整消息
  void _handleCompleteMessage(ParsedMessage parsed) {
    final messageId =
        parsed.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    // 优先使用累加器中的内容（流式消息的完整累积）
    String content;
    if (_accumulators.containsKey(messageId)) {
      content = _accumulators[messageId]!.fullContent;
      _accumulators.remove(messageId);
      print('✅ 使用累加器内容，长度: ${content.length}');
    } else if (parsed.content != null && parsed.content!.isNotEmpty) {
      // 如果没有累加器但有完整内容（chat final 事件）
      content = parsed.content!;
      print('✅ 使用 final 事件内容，长度: ${content.length}');
    } else {
      print('⚠️  完整消息没有内容');
      return;
    }

    final message = Message(
      id: messageId,
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
      sessionId: serviceId,
    );

    // 添加到消息列表
    _addMessage(message);

    // 清除流式消息状态
    state = state.copyWith(clearStreamingMessage: true);
  }

  /// 连接到服务
  Future<bool> connect() async {
    if (state.isConnected) {
      return true;
    }

    try {
      print('🔌 开始连接到服务: ${serviceConfig.name}');
      print('📍 URL: ${serviceConfig.wsUrl}');

      // 验证 URL 格式
      final urlError = ConnectionDiagnostics.validateUrl(serviceConfig.wsUrl);
      if (urlError != null) {
        final errorMsg = 'URL 格式错误: $urlError';
        print('❌ $errorMsg');
        state = state.copyWith(error: errorMsg);
        return false;
      }

      // 将 ServiceConfig 转换为 Config
      final config = Config(
        gatewayUrl: serviceConfig.wsUrl,
        token: serviceConfig.token,
        agentId: null,
        autoReconnect: true,
        reconnectInterval: 3000,
        maxReconnectAttempts: 5,
        minProtocol: 1,
        maxProtocol: 1,
        role: 'user',
        scopes: ['chat'],
      );

      await _wsService.connect(config);
      print('✅ 连接成功');
      return true;
    } on SocketException catch (e) {
      final errorMsg = ConnectionDiagnostics.getUserFriendlyMessage(e);
      final diagnostics =
          ConnectionDiagnostics.getDiagnostics(serviceConfig.wsUrl, e);
      print(diagnostics);
      state = state.copyWith(error: errorMsg);
      return false;
    } on TimeoutException catch (e) {
      final errorMsg = ConnectionDiagnostics.getUserFriendlyMessage(e);
      final diagnostics =
          ConnectionDiagnostics.getDiagnostics(serviceConfig.wsUrl, e);
      print(diagnostics);
      state = state.copyWith(error: errorMsg);
      return false;
    } on HandshakeException catch (e) {
      final errorMsg = ConnectionDiagnostics.getUserFriendlyMessage(e);
      final diagnostics =
          ConnectionDiagnostics.getDiagnostics(serviceConfig.wsUrl, e);
      print(diagnostics);
      state = state.copyWith(error: errorMsg);
      return false;
    } catch (e) {
      final errorMsg = ConnectionDiagnostics.getUserFriendlyMessage(e);
      final diagnostics =
          ConnectionDiagnostics.getDiagnostics(serviceConfig.wsUrl, e);
      print(diagnostics);
      state = state.copyWith(error: errorMsg);
      return false;
    }
  }

  /// 断开连接
  Future<void> disconnect() async {
    await _wsService.disconnect();
  }

  /// 发送消息
  Future<bool> sendMessage(String content) async {
    // 检查连接状态
    if (!state.isConnected) {
      state = state.copyWith(error: '未连接到服务器');
      return false;
    }

    // 创建用户消息
    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
      sessionId: serviceId,
    );

    // 添加到列表
    _addMessage(userMessage);

    try {
      // 使用官方的 chat.send 方法发送消息
      await _wsService.sendUserMessage(content, agentId: null);

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
    final updatedMessages =
        state.messages.where((m) => m.id != messageId).toList();
    state = state.copyWith(messages: updatedMessages);

    await _storage.deleteMessage(messageId);
  }

  /// 清空所有消息
  Future<void> clearAllMessages() async {
    state = state.copyWith(messages: []);
    await _storage.clearSessionMessages(serviceId);
  }

  /// 清除错误
  void clearError() {
    // 清除错误信息，同时保持其他状态不变
    state = state.copyWith(
      connectionState: state.connectionState.copyWith(clearError: true),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _stateSubscription?.cancel();
    _wsService.dispose();
    _accumulators.clear();
    super.dispose();
  }
}

/// 聊天会话 Provider (Family)
final chatSessionProvider =
    StateNotifierProvider.family<ChatSessionNotifier, ChatSessionState, String>(
        (ref, serviceId) {
  // 从 service manager 获取服务配置
  final serviceManager = ref.watch(serviceManagerProvider);
  final service = serviceManager.services.firstWhere(
    (s) => s.id == serviceId,
    orElse: () => throw Exception('Service not found: $serviceId'),
  );

  final storage = ref.watch(storageServiceProvider);

  return ChatSessionNotifier(
    serviceId: serviceId,
    serviceConfig: service,
    storage: storage,
  );
});

/// 存储服务 Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});
