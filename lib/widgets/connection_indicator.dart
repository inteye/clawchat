/// 连接状态指示器组件
/// 
/// 显示当前连接状态的小部件
library;

import 'package:flutter/material.dart';
import '../models/connection_state.dart';

class ConnectionIndicator extends StatelessWidget {
  final ConnectionStatus status;

  const ConnectionIndicator({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 状态点
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getStatusColor(theme),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        
        // 状态文本
        Text(
          _getStatusText(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  /// 获取状态颜色
  Color _getStatusColor(ThemeData theme) {
    switch (status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.reconnecting:
        return Colors.amber;
    }
  }

  /// 获取状态文本
  String _getStatusText() {
    switch (status) {
      case ConnectionStatus.connected:
        return '已连接';
      case ConnectionStatus.connecting:
        return '连接中...';
      case ConnectionStatus.disconnected:
        return '未连接';
      case ConnectionStatus.reconnecting:
        return '重连中...';
    }
  }
}
