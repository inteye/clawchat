# OpenClaw 直连客户端 App 技术文档

## 1. 引言

### 1.1 项目概述
本技术文档是为开发一款**开源、直连 OpenClaw 服务**的移动应用（暂命名为"OpenClaw Connect App"）而编写的完整技术规范。该应用无需任何中间后端服务器，直接通过 WebSocket 与用户在云端部署的 OpenClaw 实例进行通信。

OpenClaw 是一个开源的个人 AI 助手框架，支持多渠道消息接入、语音交互、可视化工作空间和自动化工具。其核心是通过一个 Gateway（网关）来管理会话，并对外提供 WebSocket 接口。在云端部署时，通常通过 Tailscale、Cloudflare Tunnel 或 SSH 端口转发等方式安全暴露服务。

本应用的初衷是绕过某些第三方消息平台（如 WhatsApp、Telegram）的 API 使用量限制，让用户能够更自由、便捷地使用自己云端运行的 OpenClaw AI 助手。

应用定位为**开源项目**，提供简洁的聊天界面，实现与 OpenClaw Agent 的实时文本交互。

### 1.2 文档目的
本技术文档力求全面、自洽、精确，便于 AI（例如代码生成模型）完整理解需求，并在后续实现过程中**严格遵守**。文档涵盖架构、功能需求、技术选型、协议集成、详细设计等所有关键环节，杜绝歧义。任何基于本文档进行的实现**不得偏离**其中规定的约束与指导。

### 1.3 前提假设与约束
- 用户已在云服务器（如 VPS）上通过 Docker 成功部署 OpenClaw 实例。
- OpenClaw 的 Gateway 已通过安全方式暴露 WebSocket 接口（推荐 wss://，可使用 Tailscale Funnel、Cloudflare Tunnel 或 Nginx 反向代理 + SSL）。
- 应用平台：首选跨平台移动端（Flutter 实现 Android/iOS），桌面端可选，后续可扩展。
- 功能范围：仅实现核心文本聊天功能（发送/接收消息、会话管理）。语音、Canvas、Nodes 等高级功能暂不在首版范围内。
- 安全要求：所有对外连接必须使用 wss://；认证依赖 OpenClaw 自带的密码模式或 Tailscale 网络认证。
- 无后端：应用直接连接 OpenClaw Gateway WebSocket，不引入任何自定义服务端逻辑。
- 依赖原则：尽量使用最少外部库，优先框架内置或官方推荐库。
- 许可证：严格遵守 OpenClaw 的开源协议（MIT）。

## 2. 需求规格

### 2.1 功能需求
- **连接配置**：允许用户手动输入 OpenClaw Gateway 的完整 WebSocket URL（如 wss://my-openclaw.example.com:18789），支持可选的密码认证。
- **聊天界面**：提供类即时通讯的 UI，支持用户发送文本消息，实时显示 AI 回复。
- **会话管理**：自动创建会话，支持指定路由到特定 Agent，聊天记录本地持久化。
- **实时交互**：支持显示"正在输入…"指示、Agent 在线状态、事件通知。
- **错误与异常处理**：优雅处理断网、认证失败、Gateway 错误等情况，并给出友好提示。
- **配置持久化**：安全存储 Gateway URL、密码等配置信息（使用设备本地加密存储）。
- **离线支持**：本地缓存最近聊天记录，网络恢复后自动重连。

### 2.2 非功能需求
- **性能**：正常网络下消息发送/接收延迟 < 500ms，WebSocket 保持低功耗、低流量。
- **安全性**：本地存储的密码必须加密；强制使用 wss://；对所有输入输出进行严格校验。
- **易用性**：界面直观，支持深色/浅色模式，适配各种屏幕尺寸。
- **可维护性**：代码结构清晰，便于后续扩展。
- **兼容性**：支持 Android 8.0+、iOS 12.0+，跨平台界面一致性高。
- **测试**：包含 WebSocket 逻辑的单元测试和端到端消息收发的集成测试。

### 2.3 技术栈选型
- **开发框架**：Flutter（Dart）——实现一次编写，多端运行。
- **WebSocket 库**：`web_socket_channel`（官方推荐，稳定可靠）。
- **状态管理**：Riverpod 或 Provider（推荐 Riverpod，便于管理连接状态与聊天数据）。
- **本地存储**：Hive（轻量、高性能，支持加密）。
- **UI 组件**：Android 使用 Material Design，iOS 使用 Cupertino，自适应系统主题。
- **其他依赖**：
  - `crypto`：用于密码加密。
  - `intl`：国际化（默认支持中文和英文）。

## 3. 系统架构

### 3.1 总体架构
本应用采用纯客户端架构：
- **展示层**：聊天界面、设置界面。
- **业务逻辑层**：WebSocket 客户端服务，负责连接、消息序列化/反序列化、事件分发。
- **数据层**：本地 Hive 数据库，存储配置与聊天历史。
- **无服务端层**：直接与云端 OpenClaw Gateway 建立 WebSocket 连接。

数据流向：
1. 用户在设置页输入 Gateway URL 与密码。
2. 应用建立 WebSocket 连接，连接成功后可选发送认证信息。
3. 用户在聊天界面输入消息 → 序列化为 JSON → 通过 WebSocket 发送。
4. OpenClaw Gateway 处理后将响应（可能分块流式返回）推送回来。
5. 应用实时解析响应 → 更新聊天界面。

### 3.2 主要组件
- **Main.dart**：应用入口，初始化状态管理与路由。
- **设置页面**：配置 Gateway URL、密码、自动重连等选项，提供"测试连接"按钮。
- **聊天页面**：消息列表（ListView）、输入框、连接状态指示。
- **WebSocketService**：单例服务，负责连接管理、发送消息、监听事件。
- **MessageModel**：消息数据模型（id、内容、是否本人、时间戳等）。
- **事件处理器**：处理 OpenClaw 推送的各类事件（如 typing、response chunk）。

## 4. OpenClaw Gateway 协议集成

### 4.1 协议概述
- **连接地址**：wss://<host>:<port>（默认端口 18789）。
- **认证方式**：若 OpenClaw 配置中启用了 `gateway.auth.mode: "password"`，连接建立后需立即发送认证消息。
- **消息格式**：基于 JSON 的 RPC 风格，所有消息均为字符串形式通过 WebSocket 收发。
- **核心命令示例**（参考 OpenClaw CLI 与源码）：
  - 发送普通消息：`{"type": "message.send", "to": "agent", "content": "用户问题"}`
  - 直接调用 Agent 处理：`{"type": "agent.process", "message": "用户问题", "thinking": "high"}`
  - 响应事件：常见类型包括 `"response.chunk"`（流式文本块）、`"tool.call"`、`"session.update"` 等。
- **流式响应**：AI 回复通常分多次推送，需要在客户端累积显示，实现"打字机"效果。

### 4.2 集成步骤
1. 使用 `web_socket_channel` 建立 wss:// 连接。
2. 连接成功后，若需要认证，立即发送认证 JSON。
3. 发送用户消息时构造对应 JSON 并 stringify 后发送。
4. 持续监听通道流，收到消息后解析 JSON，根据 `type` 分发处理（重点关注 response 相关事件）。
5. 应用退出或手动断开时优雅关闭连接。

## 5. 详细设计

### 5.1 UI 设计
- **页面结构**：
  - Splash 页：启动时检查配置，若未配置跳转设置页。
  - 设置页：表单输入 URL、密码，开关自动重连，提供"测试连接"与"保存"按钮。
  - 聊天页：顶部 AppBar 显示连接状态（绿色已连接、红色断开），中间消息列表（本人消息右对齐、AI 左对齐），底部输入框 + 发送按钮。
- **主题**：跟随系统深色/浅色模式。

### 5.2 数据模型
- **ConfigModel**：
  ```dart
  class Config {
    String gatewayUrl;
    String? password;
    bool autoReconnect;
  }
  ```
- **MessageModel**：
  ```dart
  class Message {
    String id;
    String content;
    bool isUser;
    DateTime timestamp;
    MessageStatus status; // 发送中、成功、失败
  }
  ```

### 5.3 安全设计
- 密码存储使用 Hive 的加密 Box（AES）。
- 强制校验 URL 必须以 wss:// 开头。
- 所有用户输入进行严格过滤，防止注入。

## 6. 实现指南

### 6.1 开发步骤
1. 创建 Flutter 项目：`flutter create openclaw_connect`
2. 添加依赖：
   ```bash
   flutter pub add web_socket_channel hive hive_flutter riverpod flutter_riverpod crypto intl
   ```
3. 实现 WebSocketService 单例类（包含 connect、send、dispose、重连逻辑）。
4. 实现数据模型与 Hive 初始化。
5. 使用 Riverpod 搭建全局状态（连接状态、消息列表、配置）。
6. 开发设置页与聊天页 UI。
7. 加入错误处理、自动重连（指数退避）。
8. 编写单元测试与集成测试。

### 6.2 代码规范
- 严格启用 null-safety。
- 遵循官方 Dart lints。
- 所有类、方法必须添加必要注释。
- 避免硬编码字符串，使用常量管理。

### 6.3 测试与发布
- 单元测试：WebSocket 消息解析、状态切换。
- 集成测试：模拟完整发送-接收流程。
- 发布：自行打包 APK/IPA，用于个人设备安装。

## 7. 风险与应对
- **网络不稳定**：实现指数退避自动重连机制。
- **协议变更**：关注 OpenClaw GitHub 仓库更新，设计时保持协议层可扩展。
- **安全暴露风险**：文档中明确建议用户使用 Tailscale/Cloudflare Tunnel 等安全方式暴露服务，避免直接公网开放。

## 8. 附录

### 8.1 参考资料
- OpenClaw 官方仓库：https://github.com/openclaw/openclaw
- OpenClaw 文档：https://docs.openclaw.ai
- Flutter 官方文档：https://flutter.dev

本技术文档版本 1.0，制定日期：2026年2月7日。后续任何更新必须以此版本为基础。所有基于本文档进行的 AI 实现必须严格遵守各章节要求，不得增删或偏离。
