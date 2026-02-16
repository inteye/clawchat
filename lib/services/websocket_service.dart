/// WebSocket 服务
///
/// 负责与 OpenClaw Gateway 的 WebSocket 连接管理
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

/// WebSocket 服务
class WebSocketService {
  WebSocketChannel? _channel;
  StreamController<WebSocketEvent>? _eventController;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  Config? _config;
  int _reconnectAttempts = 0;
  bool _isManualDisconnect = false;

  /// 事件流
  Stream<WebSocketEvent> get events => _eventController!.stream;

  /// 消息流（仅消息事件）
  Stream<Map<String, dynamic>> get messageStream => events
      .where((event) => event.type == WebSocketEventType.message)
      .map((event) => event.data as Map<String, dynamic>);

  /// 状态流
  Stream<ConnectionState> get stateStream => events
          .where(
              (event) => event.type != WebSocketEventType.message) // 过滤掉普通消息事件
          .map((event) {
        switch (event.type) {
          case WebSocketEventType.connected:
            return ConnectionState.connected();
          case WebSocketEventType.disconnected:
            return ConnectionState(status: ConnectionStatus.disconnected);
          case WebSocketEventType.authenticated:
            return ConnectionState.authenticated();
          case WebSocketEventType.error:
            return ConnectionState.error(
                event.data?.toString() ?? 'Unknown error');
          default:
            // 不应该到达这里，因为已经过滤了 message 事件
            return ConnectionState(status: ConnectionStatus.disconnected);
        }
      });

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
    _reconnectAttempts = 0; // 重置重连计数
    _reconnectTimer?.cancel(); // 取消任何待处理的重连

    await _performConnect();
  }

  /// 执行连接
  Future<void> _performConnect() async {
    if (_config == null) return;

    try {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('🔌 开始 WebSocket 连接');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📍 原始 URL: ${_config!.gatewayUrl}');

      // 解析 URL
      var uri = Uri.parse(_config!.gatewayUrl);

      // 移除 URL 中的 token 参数（challenge-response 不需要在 URL 中传递 token）
      if (uri.queryParameters.containsKey('token')) {
        final params = Map<String, String>.from(uri.queryParameters);
        params.remove('token');
        uri = uri.replace(queryParameters: params.isEmpty ? null : params);
        print('🔑 已移除 URL 中的 token 参数（将使用 challenge-response 认证）');
      }

      // 如果是 http/https，转换为 ws/wss
      if (uri.scheme == 'http') {
        uri = uri.replace(scheme: 'ws');
        print('🔄 转换 http -> ws: $uri');
      } else if (uri.scheme == 'https') {
        uri = uri.replace(scheme: 'wss');
        print('🔄 转换 https -> wss: $uri');
      }

      print('✅ URL 解析成功:');
      print('   - scheme: ${uri.scheme}');
      print('   - host: ${uri.host}');
      print(
          '   - port: ${uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80)}');
      print('   - path: ${uri.path.isEmpty ? '/' : uri.path}');
      if (uri.query.isNotEmpty) {
        print('   - query: ${uri.query}');
      }

      // 检查是否为 Tailscale 域名
      if (uri.host.contains('.ts.net')) {
        print('🌐 检测到 Tailscale 域名');
      }

      print('🔄 正在建立连接...');
      _channel = WebSocketChannel.connect(uri);

      // 等待连接建立（添加超时）
      await _channel!.ready.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('❌ 连接超时（10秒）');
          throw TimeoutException('连接超时（10秒）');
        },
      );

      print('✅ WebSocket 连接已建立');
      print('⏳ 等待服务器发送 challenge...');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      _eventController?.add(const WebSocketEvent(WebSocketEventType.connected));

      // 重置重连计数
      _reconnectAttempts = 0;

      // 开始监听消息（会收到 challenge）
      _listenToMessages();

      // 启动心跳
      _startHeartbeat();

      // 注意：不在这里发送 connect 请求，等待服务器发送 challenge
    } catch (e) {
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('❌ 连接失败');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('错误类型: ${e.runtimeType}');
      print('错误详情: $e');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _eventController?.add(WebSocketEvent(WebSocketEventType.error, e));

      // 尝试重连
      if (_config!.autoReconnect && !_isManualDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// 获取当前平台
  String _getPlatform() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }

  /// 获取客户端 ID（根据平台返回官方允许的值）
  String _getClientId() {
    if (Platform.isAndroid) return 'openclaw-android';
    if (Platform.isIOS) return 'openclaw-ios';
    if (Platform.isMacOS) return 'openclaw-macos';
    // 其他平台使用通用客户端 ID
    return 'gateway-client';
  }

  /// 获取设备 ID（生成稳定的标识符）
  Future<String> _getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString('device_id');

      if (deviceId == null || deviceId.isEmpty) {
        deviceId = 'clawchat-${DateTime.now().millisecondsSinceEpoch}';
        await prefs.setString('device_id', deviceId);
        print('生成新的设备 ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      return 'clawchat-temp-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// 获取或生成设备密钥对
  Future<Map<String, String>> _getDeviceKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 尝试获取现有的密钥
      String? deviceId = prefs.getString('device_id');
      String? publicKey = prefs.getString('device_public_key');

      if (deviceId == null || publicKey == null) {
        // 生成新的设备 ID 和公钥
        deviceId = 'clawchat-${DateTime.now().millisecondsSinceEpoch}';

        // 生成一个简单的公钥（使用设备 ID 的 SHA256 哈希）
        final bytes = utf8.encode(deviceId);
        final digest = sha256.convert(bytes);
        publicKey = digest.toString();

        // 保存到存储
        await prefs.setString('device_id', deviceId);
        await prefs.setString('device_public_key', publicKey);

        print('生成新的设备密钥:');
        print('   device_id: $deviceId');
        print('   public_key: $publicKey');
      }

      return {
        'deviceId': deviceId,
        'publicKey': publicKey,
      };
    } catch (e) {
      // 如果无法访问存储，使用临时值
      final tempId = 'clawchat-temp-${DateTime.now().millisecondsSinceEpoch}';
      final bytes = utf8.encode(tempId);
      final digest = sha256.convert(bytes);

      return {
        'deviceId': tempId,
        'publicKey': digest.toString(),
      };
    }
  }

  /// 发送 connect 请求（符合 OpenClaw Gateway 规范）
  Future<void> _sendConnectRequest() async {
    try {
      print('🔐 准备发送认证请求...');

      // 从 URL 中提取 token（如果有）
      String authToken = '';
      final uri = Uri.parse(_config!.gatewayUrl);

      if (uri.queryParameters.containsKey('token')) {
        // URL 中包含 token 参数
        authToken = uri.queryParameters['token']!;
        print('✅ 使用 URL 中的 token (长度: ${authToken.length})');
      } else if (_config!.token != null && _config!.token!.isNotEmpty) {
        // 使用配置中的 token
        authToken = _config!.token!;
        print('✅ 使用配置中的 token (长度: ${authToken.length})');
      } else if (_config!.password != null && _config!.password!.isNotEmpty) {
        // 使用配置中的 password 作为 token
        authToken = _config!.password!;
        print('✅ 使用配置中的 password 作为 token (长度: ${authToken.length})');
      } else {
        print('⚠️  警告: 未配置认证 token，跳过认证');
        _eventController
            ?.add(const WebSocketEvent(WebSocketEventType.authenticated));
        return;
      }

      final connectRequest = {
        'type': ProtocolConstants.typeRequest,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': ProtocolConstants.methodConnect,
        'params': {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': {
            'id': _getClientId(), // 使用官方允许的 client.id
            'version': AppConstants.appVersion,
            'platform': _getPlatform(),
            'mode': 'ui', // 使用 'ui' 模式
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'locale': 'zh-CN',
          'userAgent': 'ClawChat/${AppConstants.appVersion}',
          'auth': {
            'token': authToken,
          },
        },
      };

      await sendMessage(connectRequest);
      print('✅ Connect 请求已发送');
      print('   - client.id: ${_getClientId()}');
      print('   - client.mode: ui');
      print('   - platform: ${_getPlatform()}');
      print('   - role: operator');
      print('   - scopes: [operator.read, operator.write]');
      print('   - protocol: 3-3');
    } catch (e) {
      print('❌ 发送 connect 请求失败: $e');
      _eventController
          ?.add(WebSocketEvent(WebSocketEventType.error, '认证失败: $e'));
    }
  }

  /// 获取认证 token
  String _getAuthToken() {
    final uri = Uri.parse(_config!.gatewayUrl);

    if (uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token']!;
    } else if (_config!.token != null && _config!.token!.isNotEmpty) {
      return _config!.token!;
    } else if (_config!.password != null && _config!.password!.isNotEmpty) {
      return _config!.password!;
    }

    return '';
  }

  /// 发送带签名的 connect 请求（正确的认证方式）
  Future<void> _sendConnectWithSignature(String nonce, int timestamp) async {
    try {
      String authToken = _getAuthToken();
      if (authToken.isEmpty) {
        print('❌ 未配置认证 token');
        _eventController?.add(
          const WebSocketEvent(WebSocketEventType.error, '未配置认证 token'),
        );
        return;
      }

      print('🔐 准备发送 connect 请求:');
      print('   token 长度: ${authToken.length}');
      print('   nonce: $nonce');
      print('   timestamp: $timestamp');

      // 尝试方案 1: 只使用 auth.token（不发送 device 对象）
      final connectRequest = {
        'type': ProtocolConstants.typeRequest,
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'method': ProtocolConstants.methodConnect,
        'params': {
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': {
            'id': _getClientId(), // ✅ 使用官方允许的 client.id
            'version': AppConstants.appVersion,
            'platform': _getPlatform(),
            'mode': 'ui',
          },
          'role': 'operator',
          'scopes': ['operator.read', 'operator.write'],
          'auth': {
            'token': authToken,
          },
          // 不发送 device 对象，因为可能导致 identity mismatch
        },
      };

      await sendMessage(connectRequest);
      print('✅ Connect 请求已发送（简化版 - 只使用 token）');
      print('   - client.id: ${_getClientId()}');
      print('   - client.mode: ui');
      print('   - platform: ${_getPlatform()}');
      print('   - auth: token only (no device signature)');
    } catch (e) {
      print('❌ 发送 connect 请求失败: $e');
      _eventController?.add(
        WebSocketEvent(WebSocketEventType.error, '发送 connect 请求失败: $e'),
      );
    }
  }

  /// 处理 challenge
  void _handleChallenge(Map<String, dynamic> message) {
    try {
      final payload = message['payload'] as Map<String, dynamic>?;
      if (payload == null) {
        print('❌ Challenge 消息格式错误：缺少 payload');
        return;
      }

      final nonce = payload['nonce'] as String?;
      final ts = payload['ts'] as int?;

      if (nonce == null || ts == null) {
        print('❌ Challenge 消息格式错误：缺少 nonce 或 ts');
        return;
      }

      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('📨 收到 challenge:');
      print('   nonce: $nonce');
      print('   timestamp: $ts');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      _sendConnectWithSignature(nonce, ts);
    } catch (e) {
      print('❌ 处理 challenge 失败: $e');
      _eventController?.add(
        WebSocketEvent(WebSocketEventType.error, '处理 challenge 失败: $e'),
      );
    }
  }

  /// 认证（旧版本，保留用于兼容）
  @Deprecated('使用 _sendConnectWithSignature 代替')
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
      _eventController
          ?.add(WebSocketEvent(WebSocketEventType.error, '认证失败: $e'));
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
        _eventController
            ?.add(WebSocketEvent(WebSocketEventType.error, error.toString()));
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
    final event = message['event'] as String?;

    print('收到消息: type=$type, event=$event');

    // 打印完整消息内容（用于调试）
    if (type == 'event' && (event == 'agent' || event == 'chat')) {
      print('📨 完整消息内容: ${jsonEncode(message)}');
    }

    // 处理 Gateway 心跳事件（health, tick）
    if (type == ProtocolConstants.typeEvent) {
      if (event == 'health' || event == 'tick') {
        // Gateway 的心跳事件，不需要特殊处理，只记录日志
        print('💓 收到 Gateway 心跳: $event');
        return;
      }

      // 处理 challenge
      if (event == ProtocolConstants.eventConnectChallenge) {
        _handleChallenge(message);
        return;
      }

      // 处理 agent 和 chat 事件（可能包含消息内容）
      if (event == 'agent' || event == 'chat') {
        print('📬 收到 $event 事件，转发到消息流');
        _eventController
            ?.add(WebSocketEvent(WebSocketEventType.message, message));
        return;
      }
    }

    switch (type) {
      case ProtocolConstants.typeResponse:
        // 处理响应（包括 connect 响应）
        // OpenClaw Gateway 响应格式: {"type": "res", "id": "xxx", "result": {...}} 或 {"type": "res", "id": "xxx", "error": {...}}
        final error = message['error'];
        if (error == null) {
          // 响应成功，假设是 connect 成功
          print('✅ Connect 响应成功');
          _eventController
              ?.add(const WebSocketEvent(WebSocketEventType.authenticated));
        } else {
          print('❌ Connect 响应失败: $error');
          _eventController?.add(
            WebSocketEvent(WebSocketEventType.error, 'Connect 失败: $error'),
          );
        }
        break;

      case ProtocolConstants.typeAuthSuccess:
        _eventController
            ?.add(const WebSocketEvent(WebSocketEventType.authenticated));
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
        _eventController
            ?.add(WebSocketEvent(WebSocketEventType.message, message));
        break;

      case ProtocolConstants.typeError:
        final error = message['error'] ?? ErrorMessages.unknownError;
        _eventController?.add(WebSocketEvent(WebSocketEventType.error, error));
        break;

      default:
        // 未知消息类型，也转发出去
        _eventController
            ?.add(WebSocketEvent(WebSocketEventType.message, message));
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

  /// 发送消息（简化版，用于兼容）
  void send(Map<String, dynamic> message) {
    sendMessage(message);
  }

  /// 发送用户消息到 Agent（使用官方 chat.send 方法）
  Future<void> sendUserMessage(String content, {String? agentId}) async {
    // 生成唯一的请求 ID
    final requestId = DateTime.now().millisecondsSinceEpoch.toString();

    // 生成幂等键（防止重复发送）
    final idempotencyKey = 'msg-${DateTime.now().millisecondsSinceEpoch}';

    // 构建 sessionKey
    final sessionKey =
        agentId != null ? 'agent:$agentId:main' : 'agent:main:main';

    // 使用官方的 chat.send 方法
    final message = {
      'type': 'req',
      'id': requestId,
      'method': 'chat.send',
      'params': {
        'message': content,
        'sessionKey': sessionKey,
        'idempotencyKey': idempotencyKey,
        'thinking': 'high', // 可选：思考级别
      },
    };

    print('📤 发送消息 (chat.send):');
    print('   - requestId: $requestId');
    print('   - sessionKey: $sessionKey');
    print(
        '   - message: ${content.length > 50 ? content.substring(0, 50) + '...' : content}');

    await sendMessage(message);
  }

  /// 启动心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // 暂时禁用心跳，因为 OpenClaw Gateway 可能不需要或使用不同的心跳格式
    // TODO: 实现符合 OpenClaw Gateway 规范的心跳机制
    print('⏸️  心跳已禁用（OpenClaw Gateway 使用 tick 事件）');

    /* 原始心跳代码（已禁用）
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
    */
  }

  /// 处理断开连接
  void _handleDisconnect() {
    print(
        '🔌 处理断开连接: isManualDisconnect=$_isManualDisconnect, autoReconnect=${_config?.autoReconnect}');

    _heartbeatTimer?.cancel();
    _channel = null;

    _eventController
        ?.add(const WebSocketEvent(WebSocketEventType.disconnected));

    // 如果不是手动断开且启用了自动重连，则尝试重连
    if (!_isManualDisconnect && _config?.autoReconnect == true) {
      print('🔄 准备自动重连...');
      _scheduleReconnect();
    } else {
      print('⏸️  不进行自动重连');
    }
  }

  /// 安排重连
  void _scheduleReconnect() {
    if (_config == null) return;

    _reconnectAttempts++;

    if (_reconnectAttempts > _config!.maxReconnectAttempts) {
      print('❌ 达到最大重连次数 ($_reconnectAttempts)，停止重连');
      _eventController?.add(
        const WebSocketEvent(WebSocketEventType.error, '连接失败，已达到最大重连次数'),
      );
      return;
    }

    // 指数退避：基础延迟 * 2^(尝试次数-1)，最大 30 秒
    final baseDelay = _config!.reconnectInterval;
    final exponentialDelay = baseDelay * (1 << (_reconnectAttempts - 1));
    final delay = exponentialDelay > 30000 ? 30000 : exponentialDelay;

    print(
        '🔄 将在 ${delay}ms 后重连 (尝试 $_reconnectAttempts/${_config!.maxReconnectAttempts})');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (!_isManualDisconnect) {
        print('⏰ 重连定时器触发，开始重连...');
        _performConnect();
      } else {
        print('⏸️  手动断开，取消重连');
      }
    });
  }

  /// 断开连接
  Future<void> disconnect() async {
    print('🔌 WebSocketService.disconnect() 被调用');
    _isManualDisconnect = true;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    if (_channel != null) {
      try {
        await _channel?.sink.close();
        print('✅ WebSocket 连接已关闭');
      } catch (e) {
        print('⚠️  关闭 WebSocket 连接时出错: $e');
      }
      _channel = null;
    }

    _eventController
        ?.add(const WebSocketEvent(WebSocketEventType.disconnected));
  }

  /// 释放资源
  void dispose() {
    print('🔌 WebSocketService.dispose() 被调用');
    disconnect();
    _eventController?.close();
    _eventController = null;
  }
}
