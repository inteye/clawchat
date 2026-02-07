# ClawChat - OpenClaw Gateway 移动客户端

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-lightgrey.svg)

一个优雅的 Flutter 应用，用于连接和管理 OpenClaw Gateway 会话。

[功能特性](#功能特性) • [快速开始](#快速开始) • [架构设计](#架构设计) • [开发路线](#开发路线)

</div>

---

## 📱 功能特性

### ✅ 已实现

- **🔐 配置管理**
  - Gateway URL 配置
  - 密码认证支持
  - Agent ID 自定义
  - 自动重连设置
  - 配置持久化存储

- **💬 实时聊天**
  - WebSocket 实时通信
  - 流式消息接收
  - 消息状态追踪（发送中/已发送/失败）
  - 消息重发功能
  - 消息历史记录

- **🎨 精美界面**
  - Material Design 3
  - 深色/浅色主题切换
  - 流畅的动画效果
  - 响应式布局
  - 打字动画指示器

- **💾 本地存储**
  - Hive 数据库
  - 消息持久化
  - 配置自动保存
  - 离线消息查看

- **🔄 连接管理**
  - 自动重连机制
  - 连接状态实时显示
  - 心跳保活
  - 错误处理与提示

### 🚧 开发中

- **📊 会话管理**
  - 多会话支持
  - 会话切换
  - 会话历史

- **🔔 通知系统**
  - 新消息通知
  - 后台消息接收
  - 通知设置

- **🎯 高级功能**
  - 消息搜索
  - 导出聊天记录
  - 语音输入
  - 图片发送

---

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- iOS 12.0+ / Android 5.0+

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/inteye/ClawChat.git
cd ClawChat
```

2. **安装依赖**
```bash
flutter pub get
```

3. **运行应用**
```bash
# iOS
flutter run -d ios

# Android
flutter run -d android

# 模拟器
flutter run
```

### 配置 Gateway

1. 启动应用后进入设置页面
2. 输入 Gateway URL（格式：`ws://your-gateway:port` 或 `wss://your-gateway:port`）
3. 输入密码（如果需要）
4. 点击"测试连接"验证配置
5. 保存配置并返回聊天页面

---

## 🏗️ 架构设计

### 项目结构

```
lib/
├── models/              # 数据模型
│   ├── config.dart           # 配置模型
│   ├── message.dart          # 消息模型
│   └── connection_state.dart # 连接状态模型
│
├── services/            # 业务服务
│   ├── websocket_service.dart  # WebSocket 通信
│   ├── storage_service.dart    # 本地存储
│   └── protocol_parser.dart    # 协议解析
│
├── providers/           # 状态管理
│   ├── config_provider.dart      # 配置状态
│   ├── connection_provider.dart  # 连接状态
│   ├── messages_provider.dart    # 消息状态
│   └── theme_provider.dart       # 主题状态
│
├── screens/             # 页面
│   ├── splash_screen.dart    # 启动页
│   ├── settings_screen.dart  # 设置页
│   └── chat_screen.dart      # 聊天页
│
├── widgets/             # 组件
│   ├── message_bubble.dart        # 消息气泡
│   ├── message_input.dart         # 输入框
│   └── connection_indicator.dart  # 连接指示器
│
├── utils/               # 工具类
│   ├── constants.dart    # 常量定义
│   └── validators.dart   # 验证工具
│
└── main.dart            # 应用入口
```

### 技术栈

- **状态管理**: Riverpod 2.x
- **本地存储**: Hive 2.x
- **网络通信**: web_socket_channel
- **UI 框架**: Flutter Material 3

### 核心流程

```
用户输入消息
    ↓
MessagesProvider.sendMessage()
    ↓
WebSocketService.send()
    ↓
Gateway 处理
    ↓
WebSocketService.messageStream
    ↓
MessagesProvider._handleIncomingMessage()
    ↓
UI 更新显示
```

---

## 📋 开发路线

### ✅ Milestone 1: 基础架构 (已完成)
- [x] 项目初始化
- [x] 数据模型定义
- [x] 核心服务实现
- [x] 状态管理搭建

### ✅ Milestone 2: UI 界面 (已完成)
- [x] 启动页
- [x] 设置页
- [x] 聊天页
- [x] 通用组件

### ✅ Milestone 3: 核心功能 (已完成)
- [x] WebSocket 连接
- [x] 消息收发
- [x] 配置管理
- [x] 本地存储

### 🚧 Milestone 4: 测试与优化 (进行中)
- [ ] 单元测试
- [ ] 集成测试
- [ ] 性能优化
- [ ] Bug 修复

### 📅 Milestone 5: 高级功能 (计划中)
- [ ] 多会话支持
- [ ] 消息搜索
- [ ] 通知系统
- [ ] 语音输入

### 📅 Milestone 6: 发布准备 (计划中)
- [ ] 应用图标
- [ ] 启动画面
- [ ] 应用签名
- [ ] 商店发布

---

## 🔧 开发指南

### 添加新功能

1. **定义数据模型** (`lib/models/`)
2. **实现业务服务** (`lib/services/`)
3. **创建状态管理** (`lib/providers/`)
4. **构建 UI 界面** (`lib/screens/` 或 `lib/widgets/`)

### 代码规范

- 使用 `dart format` 格式化代码
- 遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 指南
- 为公共 API 添加文档注释
- 保持单一职责原则

### 调试技巧

```bash
# 查看日志
flutter logs

# 热重载
r

# 热重启
R

# 性能分析
flutter run --profile
```

---

## 📝 协议说明

### OpenClaw Gateway 协议

ClawChat 使用 OpenClaw Gateway 的 WebSocket 协议进行通信：

**连接认证**
```json
{
  "type": "auth",
  "password": "your-password"
}
```

**发送消息**
```json
{
  "type": "message",
  "content": "Hello, OpenClaw!",
  "agentId": "optional-agent-id"
}
```

**接收消息**
```json
{
  "type": "message",
  "content": "Response from AI",
  "messageId": "unique-id",
  "isComplete": true
}
```

**流式消息**
```json
{
  "type": "stream",
  "content": "Partial response...",
  "messageId": "unique-id",
  "isComplete": false
}
```

---

## 🤝 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

---

## 📄 许可证

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

---

## 🙏 致谢

- [Flutter](https://flutter.dev/) - 跨平台 UI 框架
- [Riverpod](https://riverpod.dev/) - 状态管理解决方案
- [Hive](https://docs.hivedb.dev/) - 轻量级本地数据库
- [OpenClaw](https://github.com/openclaw) - AI Gateway 平台

---

## 📞 联系方式

- 项目主页: [https://github.com/inteye/ClawChat](https://github.com/inteye/ClawChat)
- 问题反馈: [Issues](https://github.com/inteye/ClawChat/issues)
- 讨论交流: [Discussions](https://github.com/inteye/ClawChat/discussions)

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给个 Star！⭐**

Made with ❤️ by ClawChat Team

</div>
