/// 连接状态指示器组件
///
/// 显示当前连接状态的小部件
library;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;

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
          _getStatusText(l10n),
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
      case ConnectionStatus.authenticated:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
        return Colors.red;
      case ConnectionStatus.reconnecting:
        return Colors.amber;
      case ConnectionStatus.authenticating:
        return Colors.blue;
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  /// 获取状态文本
  String _getStatusText(AppLocalizations l10n) {
    switch (status) {
      case ConnectionStatus.connected:
      case ConnectionStatus.authenticated:
        return l10n.connected;
      case ConnectionStatus.connecting:
        return l10n.connecting;
      case ConnectionStatus.disconnected:
        return l10n.disconnected;
      case ConnectionStatus.reconnecting:
        return l10n.reconnecting;
      case ConnectionStatus.authenticating:
        return l10n.connecting; // 使用 connecting 代替
      case ConnectionStatus.error:
        return l10n.connectionError;
    }
  }
}
