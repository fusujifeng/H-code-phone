# H-Code 远程控制 · 设计方案

**日期：** 2026-05-23
**状态：** 已完成

---

## 1. 产品概述

手机端远程控制 Claude Code。用户通过语音或文字向电脑端的 Claude Code CLI 发送指令，电脑端执行编码任务，手机端展示实时 Todo 进度和对话。

### 架构

```
Flutter App (手机) ←→ Go Relay Server (云) ←→ Electron H-Code (桌面)
```

### 组件仓库

| 组件 | 路径 |
|------|------|
| Flutter App | `C:\Users\chenhang\Desktop\AI\H-code-phone` |
| Go 服务器 | `C:\Users\chenhang\Desktop\AI\H-code-Server` |
| Electron 桌面端 | `C:\Users\chenhang\Desktop\AI\H-Code` |

---

## 2. 通信协议

### 传输层

标准 WebSocket（RFC 6455），JSON 消息。

### 消息结构

```json
{
  "type": "register | command | ai_response | todo_update | heartbeat | ack | error",
  "pair_code": "582914",
  "client_type": "phone | desktop",
  "seq": 42,
  "payload": { },
  "timestamp": 1716478200
}
```

### 事件一览

| 事件 | 方向 | 说明 |
|------|------|------|
| `register` | 客户端 → 服务器 | 连接后上报类型和配对码 |
| `command` | 手机 → 桌面 | 发送指令 |
| `ai_response` | 桌面 → 手机 | AI 回复内容 |
| `todo_update` | 桌面 → 手机 | Todo 列表变化 |
| `heartbeat` | 双向 | 30s 心跳 |
| `ack` | 手机 → 服务器 | 重连后上报最后收到的 seq |
| `error` | 服务器 → 客户端 | 错误信息 |

### 配对流程

1. 桌面端连服务器 → register(client_type=desktop) → 服务器返回 6 位配对码
2. 桌面端生成二维码（含配对码）
3. 手机扫码 → 连服务器 → register(client_type=phone, pair_code=xxx)
4. 服务器匹配 → 两端绑定 → 开始通信
5. 配对码有效期 5 分钟，过期需刷新

---

## 3. 技术选型

| 层 | 技术 | 理由 |
|------|------|------|
| Go HTTP | `gin` (79k stars) | Go 生态最主流的 HTTP 框架 |
| Go WebSocket | `gorilla/websocket` (22k stars) | Go 生态标准 WebSocket 库 |
| Go ORM | `gorm` (37k stars) | Go 生态标配 ORM |
| Go SQLite | `modernc.org/sqlite` | 纯 Go 无 cgo，配合 gorm |
| Go 配置 | `viper` (27k stars) | Go 项目标配 |
| Go 日志 | `slog` (Go 1.21 标准库) | 零依赖结构化日志 |
| Flutter 状态管理 | `riverpod` | 编译时安全，无 BuildContext 依赖 |
| Flutter WebSocket | `web_socket_channel` | Dart 官方包 |
| Flutter 语音 | `speech_to_text` | Flutter 生态最成熟 |
| Flutter 本地存储 | `shared_preferences` + `sqflite` | 主题偏好 + 对话缓存 |
| Flutter 扫码 | `mobile_scanner` | 最主流 |
| Electron WebSocket | `ws` (21k stars) | Node.js 最主流的 WebSocket 库 |

---

## 4. Go 服务器设计

### 目录结构

```
h-code-server/
├── main.go
├── config.yaml
├── go.mod
├── config/
│   └── config.go          // viper 加载配置
├── internal/
│   ├── ws/
│   │   ├── hub.go          // 连接管理 + 配对绑定 + Room 广播
│   │   ├── client.go       // 单连接读写 goroutine
│   │   └── protocol.go     // 消息类型 + JSON 结构
│   ├── pair/
│   │   └── pair.go         // 6位配对码：生成/验证/过期
│   ├── session/
│   │   ├── buffer.go       // 环形消息缓冲 + 重连回放
│   │   └── handler.go      // 事件处理逻辑
│   └── model/
│       ├── message.go      // gorm 模型
│       └── pair_record.go  // 配对记录模型
└── router/
    └── router.go           // gin 路由
```

### Hub 核心结构

```go
type Hub struct {
    mu       sync.RWMutex
    rooms    map[string]map[*Client]bool  // pairCode → clients
    clients  map[*Client]string           // client → pairCode
    buffers  map[string]*RingBuffer       // pairCode → 消息缓冲(200条)
    register chan *Client
}
```

### 消息缓冲

- 每对连接一个环形缓冲区，容量 200 条
- 手机心跳超时 30s → 标记离线 → 新消息写入缓冲区
- 手机重连 → 提交 `ack { last_seq }` → 回放 seq > last_seq 的所有消息
- 缓冲区消息 1 小时 TTL
- 所有消息落 SQLite（14 天 TTL）

### 配置

```yaml
server:
  port: 8080

websocket:
  heartbeat_interval: 30s
  heartbeat_timeout: 90s

pair:
  code_length: 6
  expire_minutes: 5

buffer:
  max_size: 200
  message_ttl: 1h

db:
  path: ./data/hcode.db
```

---

## 5. Flutter App 设计

### 设计参考

- 视觉原型：`设计文档/index.html`
- 设计风格：iOS 液态玻璃（glassmorphism）
- 4 套主题：DeepSeek 蓝 · Claude 橙 · Trae 绿 · 苹果白

### 目录结构

```
lib/
├── main.dart
├── app.dart                    // MaterialApp + 主题
├── theme/
│   ├── theme_config.dart       // 4 套配色定义
│   └── theme_provider.dart     // ChangeNotifier
├── models/
│   ├── project.dart
│   ├── chat_message.dart
│   └── todo_item.dart
├── services/
│   ├── ws_client.dart          // WebSocket 连接 + 重连 + 心跳
│   └── voice_service.dart      // 语音识别
├── screens/
│   ├── home_page.dart          // 首页
│   └── project_page.dart       // 项目内对话
├── widgets/
│   ├── chat_bubble.dart
│   ├── voice_input.dart
│   ├── todo_list.dart
│   ├── drawer_projects.dart    // 左抽屉
│   ├── drawer_settings.dart    // 右抽屉
│   ├── recent_task_card.dart
│   └── glass_container.dart
└── providers/
    ├── ws_provider.dart
    ├── chat_provider.dart
    ├── project_provider.dart
    └── todo_provider.dart
```

### 页面结构（3 层）

1. **首页** — 快捷任务卡片（最近 3 个）+ 对话区 + 输入框
2. **项目内** — 返回箭头 + Todo 列表 + 对话区 + 输入框
3. **抽屉** — 左：项目列表 / 右：设置

### 语音输入交互

```
用户长按输入框 > 400ms
  → 输入框变形：文字/发送按钮/麦克风提示消失
  → 背景变为主题色
  → 7 道白色声波条出现（脉冲动画）
  → 底部出现"正在聆听..."

用户松手
  → 恢复输入框原状
  → 语音气泡出现在右侧（用户侧）
  → AI 回复出现在左侧
```

### WebSocket 客户端

- 自动重连：指数退避 1s → 2s → 4s → 最大 30s
- 心跳：30s ping
- 三态 UI：connected / connecting / disconnected

### 数据模型

```dart
class Project {
  String id;
  String name;
  String description;
  ProjectStatus status; // running, waiting, done
  int taskCount;
  List<TodoItem> todos;
  List<ChatMessage> messages;
  DateTime lastActive;
}

class TodoItem {
  String id;
  String title;
  TodoStatus status; // waiting, active, done
}

class ChatMessage {
  String id;
  MessageType type; // ai, user, system
  String content;
  bool isVoice;
  int? voiceDuration;
  DateTime timestamp;
}
```

---

## 6. Electron 桌面端改造

### 新增模块

```
src/main/
├── ws-bridge.ts          // 新增：WebSocket 客户端连接云服务器
└── index.ts              // 改动：初始化 ws-bridge + 转发 PTY 输出
```

### ws-bridge.ts 职责

- 启动时连接云服务器
- register(client_type=desktop) → 获取配对码
- 生成二维码（`qrcode` 终端打印或渲染到 UI）
- 收到 `command` 事件 → writePty，Claude Code 执行
- 监听 PTY 输出 → 解析 Todo/AI 回复 → 发回服务器

### IPC 新增

| IPC 通道 | 方向 | 说明 |
|------|------|------|
| `get-pair-code` | 渲染 → 主 | 获取当前配对码 |
| `get-connection-status` | 渲染 → 主 | 获取 WebSocket 连接状态 |
| `connection-status-changed` | 主 → 渲染 | 推送连接状态变化 |
| `todo-update` | 主 → 渲染 | 推送 Todo 列表更新 |

### 改动范围

不改动现有 PTY 核心逻辑，只在输出端加钩子转发消息给服务器。二维码/配对码在主窗口顶部状态栏展示。

---

## 7. 开发顺序

1. **Go 服务器** — 先搭好中继，两端才能联调
2. **Electron 桌面端** — ws-bridge + 二维码 + 消息转发
3. **Flutter App** — UI 层最后做，依赖服务器和桌面端就绪

---

## 8. 自检清单

- [x] 所有组件仓库路径明确
- [x] 通信协议消息类型完整定义
- [x] 技术选型无占位符，每项有依据
- [x] Go 服务器目录结构 + 核心模块定义
- [x] Flutter App 目录结构 + 页面 + 数据模型
- [x] 桌面端改造范围和新增 IPC
- [x] 开发顺序明确
- [x] 无 TBD 或未决项
