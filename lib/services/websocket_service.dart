/// WebSocket 服务
/// 
/// 负责与 OpenClaw Gateway 的 WebSocket 连接管理
library;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/config.dart';
import '../models/connection_state.dart';
import '../utils/constants.dart';

/// WebSocket 事件类型
enum WebSocketEventType {
  connected,
  disconnected,
  message,
  error,
  authenticated,
}

/// WebSocket 事件
class WebSocketEvent {
  final WebSocketEventType type;
  final dynamic data;

  const WebSocketEvent(this.type, [this.data]);
}

/// WebSocket 服务（单例）
class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  StreamController<WebSocketEvent>? _eventController;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  
  Config? _config;
  int _reconnectAttempts = 0;
  bool _isManualDisconnect = false;

  /// 事件流
  Stream<WebSocketEvent> get events => _eventController!.stream;

  /// 是否已连接
  bool get isConnected => _channel != null;

  /// 初始化服务
  void initialize() {
    _eventController ??= StreamController<WebSocketEvent>.broadcast();
  }

  /// 连接到 Gateway
  Future<void> connect(Config config) async {
    if (isConnected) {
      await disconnect();
    }

    _config = config;
    _isManualDisconnect = false;
    _reconnectAttempts = 0;

    await _performConnect();
  }

  /// 执行连接
  Future<void> _performConnect() async {
    if (_config == null) return;

    try {
      print('正在连接到: ${_config!.gatewayUrl}');
      
      final uri = Uri.parse(_config!.gatewayUrl);
      _channel = WebSocketChannel.connect(uri);

      // 等待连接建立
      await _channel!.ready;
      
      print('WebSocket 连接已建立');
      _eventController?.add(const WebSocketEvent(WebSocketEventType.connected));
      
      // 重置重连计数
      _reconnectAttempts = 0;

      // 如果需要认证，发送认证消息
      if (_config!.password != null && _config!.password!.isNotEmpty) {
        await _authenticate(_config!.password!);
      } else {
        _eventController?.add(const WebSocketEvent(WebSocketEventType.authenticated));
      }

      // 开始监听消息
      _listenToMessages();

      // 启动心跳
      _startHeartbeat();

    } catch (e) {
      print('连接失败: $e');
      _eventController?.add(WebSocketEvent(WebSocketEventType.error, e.toString()));
      
      // 尝试重连
      if (_config!.autoReconnect && !_isManualDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// 认证
  Future<void> _authenticate(String password) async {
    try {
      final authMessage = {
        'type': ProtocolConstants.typeAuth,
        'mode': ProtocolConstants.authModePassword,
        'password': password,
      };

      await sendMessage(authMessage);
      print('认证消息已发送');
    } catch (e) {
      print('认证失败: $e');
      _eventController?.add(WebSocketEvent(WebSocketEventType.error, '认证失败: $e'));
    }
  }

  /// 监听消息
  void _listenToMessages() {
    _channel?.stream.listen(
      (data) {
        try {
          final message = jsonDecode(data as String) as Map<String, dynamic>;
          _handleMessage(message);
        } catch (e) {
          print('解析消息失败: $e');
        }
      },
      onError: (error) {
        print('WebSocket 错误: $error');
        _eventController?.add(WebSocketEvent(WebSocketEventType.error, error.toString()));
        _handleDisconnect();
      },
      onDone: () {
        print('WebSocket 连接已关闭');
        _handleDisconnect();
      },
      cancelOnError: false,
    );
  }

  /// 处理接收到的消息
  void _handleMessage(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    
    print('收到消息: $type');

    switch (type) {
      case ProtocolConstants.typeAuthSuccess:
        _eventController?.add(const WebSocketEvent(WebSocketEventType.authenticated));
        break;
      
      case ProtocolConstants.typeAuthFailed:
        _eventController?.add(
          WebSocketEvent(WebSocketEventType.error, ErrorMessages.authFailed),
        );
        break;
      
      case ProtocolConstants.typeResponseChunk:
      case ProtocolConstants.typeResponseComplete:
      case ProtocolConstants.typeToolCall:
      case ProtocolConstants.typeSessionUpdate:
      case ProtocolConstants.typeTyping:
        _eventController?.add(WebSocketEvent(WebSocketEventType.message, message));
        break;
      
      case ProtocolConstants.typeError:
        final error = message['error'] ?? ErrorMessages.unknownError;
        _eventController?.add(WebSocketEvent(WebSocketEventType.error, error));
        break;
      
      default:
        // 未知消息类型，也转发出去
        _eventController?.add(WebSocketEvent(WebSocketEventType.message, message));
    }
  }

  /// 发送消息
  Future<void> sendMessage(Map<String, dynamic> message) async {
    if (!isConnected) {
      throw Exception(ErrorMessages.connectionFailed);
    }

    try {
      final jsonString = jsonEncode(message);
      _channel?.sink.add(jsonString);
      print('消息已发送: ${message['type']}');
    } catch (e) {
      print('发送消息失败: $e');
      throw Exception('${ErrorMessages.sendMessageFailed}: $e');
    }
  }

  /// 发送用户消息到 Agent
  Future<void> sendUserMessage(String content, {String? agentId}) async {
    final message = {
      'type': ProtocolConstants.typeAgentProcess,
      'message': content,
      'thinking': ProtocolConstants.thinkingHigh,
      if (agentId != null) 'agentId': agentId,
    };

    await sendMessage(message);
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: AppConstants.heartbeatInterval),
      (timer) {
        if (isConnected) {
          try {
            _channel?.sink.add('ping');
          } catch (e) {
            print('心跳发送失败: $e');
          }
        }
      },
    );
  }

  /// 处理断开连接
  void _handleDisconnect() {
    _heartbeatTimer?.cancel();
    _channel = null;
    
    _eventController?.add(const WebSocketEvent(WebSocketEventType.disconnected));

    // 如果不是手动断开且启用了自动重连，则尝试重连
    if (!_isManualDisconnect && _config?.autoReconnect == true) {
      _scheduleReconnect();
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_config == null) return;
    
    _reconnectAttempts++;
    
    if (_reconnectAttempts > _config!.maxReconnectAttempts) {
      print('达到最大重连次数，停止重连');
      _eventController?.add(
        const WebSocketEvent(WebSocketEventType.error, '连接失败，已达到最大重连次数'),
      );
      return;
    }

    // 指数退避
    final delay = _config!.reconnectInterval * _reconnectAttempts;
    print('将在 ${delay}ms 后重连 (尝试 $_reconnectAttempts/${_config!.maxReconnectAttempts})');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_isManualDisconnect) {
        _performConnect();
      }
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    
    await _channel?.sink.close();
    _channel = null;
    
    _eventController?.add(const WebSocketEvent(WebSocketEventType.disconnected));
  }

  /// 释放资源
  void dispose() {
    disconnect();
    _eventController?.close();
    _eventController = null;
  }
}
