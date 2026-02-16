/// 聊天页
///
/// 主聊天界面，显示消息列表和输入框
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../providers/chat_session_provider.dart';
import '../providers/service_manager_provider.dart';
import '../providers/language_provider.dart';
import '../models/message.dart';
import 'settings_screen.dart';
import 'service_list_screen.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input.dart';
import '../widgets/connection_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  bool _autoConnect = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectIfNeeded();
      // 初始加载后滚动到底部
      _scrollToBottom();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final serviceManager = ref.read(serviceManagerProvider);
    if (!serviceManager.hasActiveService) return;

    final activeServiceId = serviceManager.activeServiceId!;

    switch (state) {
      case AppLifecycleState.paused:
        // 应用进入后台，断开当前服务连接
        print('📱 应用进入后台，断开连接');
        ref.read(chatSessionProvider(activeServiceId).notifier).disconnect();
        break;
      case AppLifecycleState.resumed:
        // 应用恢复，重新连接
        print('📱 应用恢复，重新连接');
        ref.read(chatSessionProvider(activeServiceId).notifier).connect();
        break;
      default:
        break;
    }
  }

  /// 如果需要则自动连接
  Future<void> _connectIfNeeded() async {
    if (!_autoConnect) return;

    final serviceManager = ref.read(serviceManagerProvider);
    if (!serviceManager.hasActiveService) return;

    final activeServiceId = serviceManager.activeServiceId!;
    final session = ref.read(chatSessionProvider(activeServiceId));

    if (!session.isConnected) {
      await ref.read(chatSessionProvider(activeServiceId).notifier).connect();
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
    final serviceManager = ref.read(serviceManagerProvider);
    if (!serviceManager.hasActiveService) return;

    final activeServiceId = serviceManager.activeServiceId!;
    final success = await ref
        .read(chatSessionProvider(activeServiceId).notifier)
        .sendMessage(content);

    if (success) {
      // 滚动到底部
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  /// 重新发送消息
  Future<void> _resendMessage(String messageId) async {
    final serviceManager = ref.read(serviceManagerProvider);
    if (!serviceManager.hasActiveService) return;

    final activeServiceId = serviceManager.activeServiceId!;
    await ref
        .read(chatSessionProvider(activeServiceId).notifier)
        .resendMessage(messageId);
  }

  /// 删除消息
  Future<void> _deleteMessage(String messageId) async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteMessage),
        content: Text(l10n.deleteMessageConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final serviceManager = ref.read(serviceManagerProvider);
      if (!serviceManager.hasActiveService) return;

      final activeServiceId = serviceManager.activeServiceId!;
      await ref
          .read(chatSessionProvider(activeServiceId).notifier)
          .deleteMessage(messageId);
    }
  }

  /// 清空所有消息
  Future<void> _clearAllMessages() async {
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.clearMessages),
        content: Text(l10n.clearMessagesConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.clear),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final serviceManager = ref.read(serviceManagerProvider);
      if (!serviceManager.hasActiveService) return;

      final activeServiceId = serviceManager.activeServiceId!;
      await ref
          .read(chatSessionProvider(activeServiceId).notifier)
          .clearAllMessages();
    }
  }

  /// 显示服务列表
  void _showServiceList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ServiceListScreen(),
      ),
    );
  }

  /// 显示设置页面
  void _showSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  /// 显示菜单
  void _showMenu() {
    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(l10n.language),
              onTap: () {
                Navigator.of(context).pop();
                _showLanguageDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep),
              title: Text(l10n.clearMessages),
              onTap: () {
                Navigator.of(context).pop();
                _clearAllMessages();
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l10n.about),
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

  /// 显示语言选择对话框
  void _showLanguageDialog() {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l10n.languageEnglish),
              leading: Radio<String>(
                value: 'en',
                groupValue: ref.read(languageProvider).locale.languageCode,
                onChanged: (value) {
                  ref.read(languageProvider.notifier).setEnglish();
                  Navigator.of(context).pop();
                },
              ),
              onTap: () {
                ref.read(languageProvider.notifier).setEnglish();
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              title: Text(l10n.languageChinese),
              leading: Radio<String>(
                value: 'zh',
                groupValue: ref.read(languageProvider).locale.languageCode,
                onChanged: (value) {
                  ref.read(languageProvider.notifier).setChinese();
                  Navigator.of(context).pop();
                },
              ),
              onTap: () {
                ref.read(languageProvider.notifier).setChinese();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示关于对话框
  void _showAboutDialog() {
    final l10n = AppLocalizations.of(context)!;

    showAboutDialog(
      context: context,
      applicationName: l10n.appName,
      applicationVersion: '0.1.0',
      applicationIcon: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/logo.png',
          width: 64,
          height: 64,
        ),
      ),
      children: [
        Text(l10n.aboutDescription),
        const SizedBox(height: 8),
        Text(l10n.aboutDescription2),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 断开当前服务的连接
    final serviceManager = ref.read(serviceManagerProvider);
    if (serviceManager.hasActiveService) {
      final activeServiceId = serviceManager.activeServiceId!;
      ref.read(chatSessionProvider(activeServiceId).notifier).disconnect();
      print('🔌 ChatScreen dispose: 断开服务连接');
    }

    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final serviceManager = ref.watch(serviceManagerProvider);

    // 如果没有激活的服务，显示提示
    if (!serviceManager.hasActiveService) {
      return _buildNoServiceState(context);
    }

    final activeServiceId = serviceManager.activeServiceId!;
    final session = ref.watch(chatSessionProvider(activeServiceId));
    final theme = Theme.of(context);

    // 监听消息变化，自动滚动
    ref.listen<ChatSessionState>(
      chatSessionProvider(activeServiceId),
      (previous, next) {
        if (next.messages.length > (previous?.messages.length ?? 0)) {
          Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
        }
      },
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _showServiceList,
          tooltip: l10n.serviceList,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(session.serviceConfig.name),
            ConnectionIndicator(status: session.connectionState.status),
          ],
        ),
        actions: [
          // 连接/断开按钮
          IconButton(
            icon: Icon(
              session.isConnected ? Icons.cloud_done : Icons.cloud_off,
            ),
            onPressed: () async {
              if (session.isConnected) {
                await ref
                    .read(chatSessionProvider(activeServiceId).notifier)
                    .disconnect();
              } else {
                await ref
                    .read(chatSessionProvider(activeServiceId).notifier)
                    .connect();
              }
            },
            tooltip: session.isConnected ? l10n.disconnect : l10n.connect,
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
          if (session.connectionState.hasError)
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
                      session.connectionState.error ?? 'Unknown error',
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.red.shade900),
                    onPressed: () {
                      final serviceManager = ref.read(serviceManagerProvider);
                      if (serviceManager.hasActiveService) {
                        ref
                            .read(chatSessionProvider(
                                    serviceManager.activeServiceId!)
                                .notifier)
                            .clearError();
                      }
                    },
                  ),
                ],
              ),
            ),

          // 消息列表
          Expanded(
            child: session.messages.isEmpty && !session.isStreaming
                ? _buildEmptyState(theme)
                : _buildMessageList(session),
          ),

          // 输入框
          MessageInput(
            onSend: _sendMessage,
            enabled: session.isConnected,
          ),
        ],
      ),
    );
  }

  /// 构建无服务状态
  Widget _buildNoServiceState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appName),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettings,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.pleaseSelectService,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.viewServiceList,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _showServiceList,
              icon: const Icon(Icons.list),
              label: Text(l10n.serviceList),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建空状态
  Widget _buildEmptyState(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;

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
            l10n.noMessages,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.startConversation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建消息列表
  Widget _buildMessageList(ChatSessionState session) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: session.messages.length + (session.isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        // 流式消息
        if (session.isStreaming && index == session.messages.length) {
          return MessageBubble(
            message: session.streamingMessage!,
            onResend: null,
            onDelete: null,
            isStreaming: true,
          );
        }

        // 普通消息
        final message = session.messages[index];
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
