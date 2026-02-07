/// 消息气泡组件
/// 
/// 显示单条消息的气泡样式
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final VoidCallback? onResend;
  final VoidCallback? onDelete;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.onResend,
    this.onDelete,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI 头像
          if (!isUser) ...[
            _buildAvatar(theme, isUser),
            const SizedBox(width: 8),
          ],

          // 消息内容
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageMenu(context),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 消息气泡
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 消息内容
                        Text(
                          message.content,
                          style: TextStyle(
                            color: isUser
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),

                        // 流式动画指示器
                        if (isStreaming) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildTypingDot(theme, 0),
                              const SizedBox(width: 4),
                              _buildTypingDot(theme, 1),
                              const SizedBox(width: 4),
                              _buildTypingDot(theme, 2),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // 时间和状态
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 时间
                        Text(
                          _formatTime(message.timestamp),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),

                        // 状态图标
                        if (isUser) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(theme),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 用户头像
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(theme, isUser),
          ],
        ],
      ),
    );
  }

  /// 构建头像
  Widget _buildAvatar(ThemeData theme, bool isUser) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: isUser
          ? theme.colorScheme.primary
          : theme.colorScheme.secondary,
      child: Icon(
        isUser ? Icons.person : Icons.smart_toy,
        size: 20,
        color: Colors.white,
      ),
    );
  }

  /// 构建状态图标
  Widget _buildStatusIcon(ThemeData theme) {
    switch (message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: theme.colorScheme.error,
        );
    }
  }

  /// 构建打字动画点
  Widget _buildTypingDot(ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = (value + delay) % 1.0;
        final opacity = (animValue < 0.5 ? animValue * 2 : (1 - animValue) * 2);
        
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// 显示消息菜单
  void _showMessageMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制到剪贴板')),
                );
              },
            ),

            // 重新发送（仅失败消息）
            if (onResend != null)
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('重新发送'),
                onTap: () {
                  Navigator.of(context).pop();
                  onResend!();
                },
              ),

            // 删除
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }
}
