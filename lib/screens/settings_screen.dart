/// 设置页
///
/// 服务配置页面 - 添加/编辑服务
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/service_config.dart';
import '../providers/service_manager_provider.dart';
import '../utils/connection_diagnostics.dart';
import '../utils/validators.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  final ServiceConfig? editingService;

  const SettingsScreen({
    super.key,
    this.editingService,
  });

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _wsUrlController = TextEditingController();
  final _tokenController = TextEditingController();

  bool _obscureToken = true;
  bool _isSaving = false;
  bool _isTesting = false;
  Map<String, dynamic>? _urlInfo;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  /// 加载配置
  void _loadConfig() {
    if (widget.editingService != null) {
      final service = widget.editingService!;
      _nameController.text = service.name;
      _wsUrlController.text = service.wsUrl;
      _tokenController.text = service.token;
      _updateUrlInfo();
    }
  }

  /// 更新 URL 信息
  void _updateUrlInfo() {
    final url = _wsUrlController.text.trim();
    if (url.isNotEmpty) {
      setState(() {
        _urlInfo = Validators.getUrlInfo(url);
      });
    } else {
      setState(() {
        _urlInfo = null;
      });
    }
  }

  /// 测试连接
  Future<void> _testConnection() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _wsUrlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.pleaseEnterWebSocketUrl),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 验证 URL 格式
    final urlError = ConnectionDiagnostics.validateUrl(url);
    if (urlError != null) {
      setState(() {
        _testResult = l10n.validationFailedWithError(urlError);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(urlError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      // 显示 URL 解析信息
      final parsed = ConnectionDiagnostics.parseUrl(url);
      final buffer = StringBuffer();
      buffer.writeln(l10n.urlFormatCorrect);
      buffer.writeln('${l10n.protocol}: ${parsed['scheme']}');
      buffer.writeln('${l10n.host}: ${parsed['host']}');
      buffer.writeln('${l10n.port}: ${parsed['port']}');
      buffer.writeln('${l10n.path}: ${parsed['path']}');
      if (parsed['hasToken'] == true) {
        buffer.writeln('${l10n.containsToken}: ${l10n.yes}');
      }

      setState(() {
        _testResult = buffer.toString();
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.urlValidSuccess),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      setState(() {
        _testResult = l10n.validationFailedWithError(e.toString());
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.validationFailed}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isTesting = false;
        });
      }
    }
  }

  /// 保存配置
  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSaving = true);

    try {
      final serviceManager = ref.read(serviceManagerProvider.notifier);

      if (widget.editingService != null) {
        // 更新现有服务
        final updatedService = widget.editingService!.copyWith(
          name: _nameController.text.trim(),
          wsUrl: _wsUrlController.text.trim(),
          token: _tokenController.text.trim(),
        );

        final success = await serviceManager.updateService(updatedService);

        if (!mounted) return;

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.serviceUpdatedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          final error =
              ref.read(serviceManagerProvider).error ?? l10n.updateFailed;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // 添加新服务
        final newService = ServiceConfig.create(
          name: _nameController.text.trim(),
          wsUrl: _wsUrlController.text.trim(),
          token: _tokenController.text.trim(),
        );

        final success = await serviceManager.addService(newService);

        if (!mounted) return;

        if (success) {
          // 如果是第一个服务，自动设置为激活
          final services = ref.read(serviceManagerProvider).services;
          if (services.length == 1) {
            await serviceManager.setActiveService(newService.id);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.serviceAddedSuccess),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop();
        } else {
          final error =
              ref.read(serviceManagerProvider).error ?? l10n.addFailed;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wsUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isEditing = widget.editingService != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? l10n.editService : l10n.addService),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 标题说明
            if (!isEditing) ...[
              Icon(
                Icons.cloud_outlined,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.addOpenClawService,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.fillServiceInfo,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
            ],

            // 服务配置表单
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.serviceInfo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 服务名称
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.serviceName,
                        hintText: l10n.serviceNameHint,
                        prefixIcon: const Icon(Icons.label_outline),
                        helperText: l10n.serviceNameHelper,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterServiceName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // WebSocket URL
                    TextFormField(
                      controller: _wsUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.websocketUrl,
                        hintText: l10n.websocketUrlHint,
                        prefixIcon: const Icon(Icons.link),
                        helperText: l10n.websocketUrlHelper,
                        helperMaxLines: 3,
                      ),
                      keyboardType: TextInputType.url,
                      onChanged: (value) => _updateUrlInfo(),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterWebSocketUrl;
                        }
                        final trimmed = value.trim();
                        if (!trimmed.startsWith('ws://') &&
                            !trimmed.startsWith('wss://') &&
                            !trimmed.startsWith('http://') &&
                            !trimmed.startsWith('https://')) {
                          return l10n.urlMustStartWith;
                        }
                        return null;
                      },
                    ),

                    // URL 解析信息
                    if (_urlInfo != null && _urlInfo!['valid'] == true) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.surfaceVariant.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 16,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  l10n.urlParseInfo,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoRow(
                              l10n.protocol,
                              _urlInfo!['scheme'],
                              theme,
                            ),
                            _buildInfoRow(l10n.host, _urlInfo!['host'], theme),
                            _buildInfoRow(
                              l10n.port,
                              _urlInfo!['port'].toString(),
                              theme,
                            ),
                            _buildInfoRow(l10n.path, _urlInfo!['path'], theme),
                            _buildInfoRow(
                              l10n.secureConnection,
                              _urlInfo!['isSecure']
                                  ? '${l10n.yes} (wss)'
                                  : '${l10n.no} (ws)',
                              theme,
                            ),
                            _buildInfoRow(
                              l10n.containsToken,
                              _urlInfo!['hasToken'] ? l10n.yes : l10n.no,
                              theme,
                            ),
                          ],
                        ),
                      ),
                    ],

                    // 测试连接按钮
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isTesting ? null : _testConnection,
                        icon: _isTesting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.wifi_find),
                        label: Text(
                          _isTesting ? l10n.validating : l10n.validateUrlFormat,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),

                    // 测试结果
                    if (_testResult != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _testResult!.startsWith('✅')
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _testResult!.startsWith('✅')
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        child: Text(
                          _testResult!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Token
                    TextFormField(
                      controller: _tokenController,
                      decoration: InputDecoration(
                        labelText: l10n.tokenPassword,
                        hintText: l10n.authCredentials,
                        prefixIcon: const Icon(Icons.vpn_key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureToken
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureToken = !_obscureToken);
                          },
                        ),
                        helperText: l10n.tokenHelperText,
                        helperMaxLines: 3,
                      ),
                      obscureText: _obscureToken,
                      validator: (value) {
                        // Token 是必需的（用于 challenge-response 认证）
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterToken;
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // 提示信息
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.serviceConfigNote,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 保存按钮
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveConfig,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? l10n.saving
                    : (isEditing ? l10n.saveChanges : l10n.addService),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
