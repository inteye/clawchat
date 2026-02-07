/// 设置页
/// 
/// Gateway 连接配置页面
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/config_provider.dart';
import '../providers/connection_provider.dart';
import '../models/config.dart';
import 'chat_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final bool isFirstTime;

  const SettingsScreen({
    super.key,
    this.isFirstTime = false,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _gatewayUrlController = TextEditingController();
  final _passwordController = TextEditingController();
  final _agentIdController = TextEditingController();
  
  bool _autoReconnect = true;
  int _reconnectInterval = 5;
  int _maxReconnectAttempts = 3;
  bool _obscurePassword = true;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载配置
  void _loadConfig() {
    final configState = ref.read(configProvider);
    if (configState.config != null) {
      final config = configState.config!;
      _gatewayUrlController.text = config.gatewayUrl;
      _passwordController.text = config.password ?? '';
      _agentIdController.text = config.agentId ?? '';
      _autoReconnect = config.autoReconnect;
      _reconnectInterval = config.reconnectInterval;
      _maxReconnectAttempts = config.maxReconnectAttempts;
    } else {
      // 设置默认值
      final defaultConfig = Config.defaultConfig();
      _gatewayUrlController.text = defaultConfig.gatewayUrl;
      _autoReconnect = defaultConfig.autoReconnect;
      _reconnectInterval = defaultConfig.reconnectInterval;
      _maxReconnectAttempts = defaultConfig.maxReconnectAttempts;
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final config = Config(
      gatewayUrl: _gatewayUrlController.text.trim(),
      password: _passwordController.text.isEmpty ? null : _passwordController.text,
      agentId: _agentIdController.text.isEmpty ? null : _agentIdController.text,
      autoReconnect: _autoReconnect,
      reconnectInterval: _reconnectInterval,
      maxReconnectAttempts: _maxReconnectAttempts,
    );

    final success = await ref.read(configProvider.notifier).saveConfig();

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置保存成功'),
          backgroundColor: Colors.green,
        ),
      );

      // 如果是首次配置，跳转到聊天页
      if (widget.isFirstTime) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const ChatScreen(),
          ),
        );
      }
    } else {
      final error = ref.read(configProvider).error ?? '保存失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 测试连接
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isTesting = true);

    // 先保存配置
    final config = Config(
      gatewayUrl: _gatewayUrlController.text.trim(),
      password: _passwordController.text.isEmpty ? null : _passwordController.text,
      agentId: _agentIdController.text.isEmpty ? null : _agentIdController.text,
      autoReconnect: _autoReconnect,
      reconnectInterval: _reconnectInterval,
      maxReconnectAttempts: _maxReconnectAttempts,
    );

    ref.read(configProvider.notifier).updateConfig(config);

    // 测试连接
    final success = await ref.read(connectionProvider.notifier).connect();

    if (!mounted) return;

    setState(() => _isTesting = false);

    if (success) {
      // 断开测试连接
      await ref.read(connectionProvider.notifier).disconnect();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('连接测试成功！'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final error = ref.read(connectionProvider).error ?? '连接失败';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接测试失败: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _gatewayUrlController.dispose();
    _passwordController.dispose();
    _agentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configState = ref.watch(configProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('连接设置'),
        leading: widget.isFirstTime
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题
            if (widget.isFirstTime) ...[
              Icon(
                Icons.settings_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                '欢迎使用 ClawChat',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '请配置 Gateway 连接信息',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],

            // Gateway URL
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '基本设置',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _gatewayUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Gateway URL',
                        hintText: 'wss://gateway.example.com',
                        prefixIcon: Icon(Icons.link),
                        helperText: '以 ws:// 或 wss:// 开头',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入 Gateway URL';
                        }
                        if (!value.startsWith('ws://') && !value.startsWith('wss://')) {
                          return 'URL 必须以 ws:// 或 wss:// 开头';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: '密码（可选）',
                        hintText: '如果 Gateway 需要密码',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (value) {
                        if (value != null && value.isNotEmpty && value.length < 6) {
                          return '密码长度至少 6 个字符';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _agentIdController,
                      decoration: const InputDecoration(
                        labelText: 'Agent ID（可选）',
                        hintText: '指定特定的 Agent',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 高级设置
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '高级设置',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('自动重连'),
                      subtitle: const Text('连接断开时自动尝试重连'),
                      value: _autoReconnect,
                      onChanged: (value) {
                        setState(() => _autoReconnect = value);
                      },
                    ),
                    if (_autoReconnect) ...[
                      ListTile(
                        title: const Text('重连间隔'),
                        subtitle: Text('$_reconnectInterval 秒'),
                        trailing: SizedBox(
                          width: 200,
                          child: Slider(
                            value: _reconnectInterval.toDouble(),
                            min: 1,
                            max: 30,
                            divisions: 29,
                            label: '$_reconnectInterval 秒',
                            onChanged: (value) {
                              setState(() => _reconnectInterval = value.toInt());
                            },
                          ),
                        ),
                      ),
                      ListTile(
                        title: const Text('最大重连次数'),
                        subtitle: Text(_maxReconnectAttempts == 0 ? '无限制' : '$_maxReconnectAttempts 次'),
                        trailing: SizedBox(
                          width: 200,
                          child: Slider(
                            value: _maxReconnectAttempts.toDouble(),
                            min: 0,
                            max: 10,
                            divisions: 10,
                            label: _maxReconnectAttempts == 0 ? '无限制' : '$_maxReconnectAttempts 次',
                            onChanged: (value) {
                              setState(() => _maxReconnectAttempts = value.toInt());
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isTesting || configState.isLoading ? null : _testConnection,
                    icon: _isTesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_find),
                    label: Text(_isTesting ? '测试中...' : '测试连接'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: configState.isLoading ? null : _saveConfig,
                    icon: configState.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(configState.isLoading ? '保存中...' : '保存配置'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
