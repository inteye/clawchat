/// 聊天页
/// 
/// 主聊天界面，显示消息列表和输入框
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connection_provider.dart';
import '../providers/messages_provider.dart';
import '../providers/config_provider.dart';
import '../models/connection_state.dart';
import '../models/message.dart';
import 'settings_screen.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/connection_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _autoConnect = true;

  @override
  void initState() {
    super.initState();
    _connectIfNeeded();
  }

  /// 如果需要则自动连接
  Future<void> _connectIfNeeded() async {
    if (!_autoConnect) return;

    final connectionState = ref.read(connectionProvider);
    if (connectionState.isDisconnected) {
      await ref.read(connectionProvider.notifier).connect();
    }
  }

  /// 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  /// 发送消息
  Future<void> _sendMessage(String content) async {
    final success = await ref.read(messagesProvider.notifier).sendMessage(content);
    
    if (success) {
      // 滚动到底部
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  /// 重新发送消息
  Future<void> _resendMessage(String messageId) async {
    await ref.read(messagesProvider.notifier).resendMessage(messageId);
  }

  /// 删除消息
  Future<void> _deleteMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(messagesProvider.notifier).deleteMessage(messageId);
    }
  }

  /// 清空所有消息
  Future<void> _clearAllMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空消息'),
        content: const Text('确定要清空所有消息吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(messagesProvider.notifier).clearAllMessages();
    }
  }

  /// 显示菜单
  void _showMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('连接设置'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: const Text('清空消息'),
              onTap: () {
                Navigator.of(context).pop();
                _clearAllMessages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('关于'),
              onTap: () {
                Navigator.of(context).pop();
                _showAboutDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    showAboutDialog(
      context: context,
      applicationName: 'ClawChat',
      applicationVersion: '0.1.0',
      applicationIcon: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.chat_bubble_outline,
          color: Colors.white,
          size: 32,
        ),
      ),
      children: [
        const Text('OpenClaw 直连客户端'),
        const SizedBox(height: 8),
        const Text('一个简洁、高效的 AI 聊天应用'),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connectionState = ref.watch(connectionProvider);
    final messagesState = ref.watch(messagesProvider);
    final theme = Theme.of(context);

    // 监听消息变化，自动滚动
    ref.listen<MessagesState>(messagesProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ClawChat'),
            ConnectionIndicator(status: connectionState.status),
          ],
        ),
        actions: [
          // 连接/断开按钮
          IconButton(
            icon: Icon(
              connectionState.isConnected
                  ? Icons.cloud_done
                  : Icons.cloud_off,
            ),
            onPressed: () async {
              if (connectionState.isConnected) {
                await ref.read(connectionProvider.notifier).disconnect();
              } else {
                await ref.read(connectionProvider.notifier).connect();
              }
            },
            tooltip: connectionState.isConnected ? '断开连接' : '连接',
          ),
          // 菜单按钮
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          // 错误提示
          if (connectionState.hasError)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectionState.error!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      ref.read(connectionProvider.notifier).clearError();
                    },
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: messagesState.messages.isEmpty && !messagesState.isStreaming
                ? _buildEmptyState(theme)
                : _buildMessageList(messagesState),
          ),

          // 输入框
          MessageInput(
            onSend: _sendMessage,
            enabled: connectionState.isConnected,
          ),
        ],
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '还没有消息',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '发送一条消息开始对话吧',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(MessagesState state) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: state.messages.length + (state.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        // 流式消息
        if (state.isStreaming && index == state.messages.length) {
          return MessageBubble(
            message: state.streamingMessage!,
            onResend: null,
            onDelete: null,
            isStreaming: true,
          );
        }

        // 普通消息
        final message = state.messages[index];
        return MessageBubble(
          message: message,
          onResend: message.status == MessageStatus.failed
              ? () => _resendMessage(message.id)
              : null,
          onDelete: () => _deleteMessage(message.id),
        );
      },
    );
  }
}
