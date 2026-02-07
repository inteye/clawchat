# ClawChat - 项目开发计划

## 📋 项目信息

**项目名称**: ClawChat  
**GitHub仓库**: https://github.com/inteye/ClawChat.git  
**项目描述**: 开源的 OpenClaw 直连客户端 App，支持通过 WebSocket 直接连接云端 OpenClaw 实例  
**技术栈**: Flutter, Dart, WebSocket, Riverpod, Hive  
**平台**: Android / iOS  
**开发路径**: `/root/.openclaw/workspace/projects/openclaw-connect-app`

## 🎯 开发路线图

### Phase 1: 基础架构 (v0.1.0) - 当前阶段
- [ ] 项目结构设计
- [ ] WebSocket 服务核心逻辑
- [ ] 数据模型定义
- [ ] 协议解析器
- [ ] 单元测试框架

### Phase 2: 核心功能 (v0.2.0)
- [ ] 完整的聊天界面
- [ ] 消息发送/接收
- [ ] 流式响应显示
- [ ] 连接状态管理
- [ ] 错误处理

### Phase 3: 优化完善 (v1.0.0)
- [ ] 自动重连机制
- [ ] 离线消息缓存
- [ ] 深色/浅色主题
- [ ] 国际化支持
- [ ] 完整测试覆盖

## 📁 项目结构

```
ClawChat/
├── lib/
│   ├── main.dart                 # 应用入口
│   ├── models/                   # 数据模型
│   │   ├── message.dart
│   │   ├── config.dart
│   │   └── connection_state.dart
│   ├── services/                 # 业务服务
│   │   ├── websocket_service.dart
│   │   ├── storage_service.dart
│   │   └── protocol_parser.dart
│   ├── providers/                # Riverpod 状态管理
│   │   ├── connection_provider.dart
│   │   ├── messages_provider.dart
│   │   └── config_provider.dart
│   ├── screens/                  # 页面
│   │   ├── splash_screen.dart
│   │   ├── settings_screen.dart
│   │   └── chat_screen.dart
│   ├── widgets/                  # 可复用组件
│   │   ├── message_bubble.dart
│   │   ├── connection_indicator.dart
│   │   └── chat_input.dart
│   └── utils/                    # 工具类
│       ├── constants.dart
│       └── validators.dart
├── test/                         # 测试
│   ├── unit/
│   └── integration/
├── docs/                         # 文档
│   ├── TECHNICAL_SPEC.md
│   └── API.md
├── pubspec.yaml                  # 依赖配置
└── README.md                     # 项目说明
```

## 🚀 立即开始

### 第一步：创建项目结构
```bash
# 创建目录结构
mkdir -p lib/{models,services,providers,screens,widgets,utils}
mkdir -p test/{unit,integration}
mkdir -p docs
```

### 第二步：定义数据模型
核心模型：
- Message: 消息实体
- Config: 配置信息
- ConnectionState: 连接状态

### 第三步：实现 WebSocket 服务
核心功能：
- 连接管理
- 消息发送/接收
- 自动重连
- 事件分发

### 第四步：协议解析
实现 OpenClaw Gateway 协议：
- JSON 序列化/反序列化
- 流式响应处理
- 错误处理

## 📝 开发规范

### 代码风格
- 遵循 Dart 官方 lints
- 启用 null-safety
- 所有公共 API 必须有文档注释

### Git 工作流
- main: 稳定版本
- develop: 开发分支
- feature/*: 功能分支
- fix/*: 修复分支

### 提交规范
```
feat: 新功能
fix: 修复
docs: 文档
style: 格式
refactor: 重构
test: 测试
chore: 构建/工具
```

## 🎯 当前任务

1. ✅ 克隆仓库
2. ✅ 添加技术文档
3. ⏳ 创建项目结构
4. ⏳ 实现数据模型
5. ⏳ 实现 WebSocket 服务

---
**最后更新**: 2025-02-08
