# AI 指挥中心 · Flutter App 技术规格书

## 产品定位

手机端远程控制 Claude Code。用户通过语音或文字向电脑端的 Claude Code CLI 发送指令，电脑端执行编码任务，手机端展示实时 Todo 进度和对话。

## 设计参考

- 视觉原型文件：`index.html`（本目录）
- 参考 App：Trae Solo（字节跳动）、豆包（字节跳动）、DeepSeek
- 设计风格：iOS 液态玻璃（glassmorphism）+ 简洁优雅

## 技术栈

- Flutter 3.x，Dart
- 状态管理：Riverpod 或 Bloc
- 通信：与 Claude Code MCP Server 通过 WebSocket 或 HTTP 通信
- 语音：`speech_to_text` 或 `flutter_speech` 插件（按住录音，松手发送并转文字）
- 持久化：`shared_preferences`（主题）+ `sqflite` 或 `drift`（对话历史）

---

## 页面结构

App 共 3 层：**首页（对话 + 快捷入口）→ 项目内（对话 + Todo）→ 设置/项目列表抽屉**

### 1. 首页（默认页面）

```
┌─────────────────────────────┐
│ 状态栏 (9:41)               │
├─────────────────────────────┤
│ ☰         AI 指挥中心    ⚙ │  ← Top Bar，玻璃效果
│        Claude Code 已连接   │
├─────────────────────────────┤
│  快捷任务 (垂直排列, 3张卡片)  │  ← 最近三个任务，每张独占一行
│  ┌─ 拆分用户认证模块 ─────┐ │
│  │  家庭装修助手 · 14:32   │ │
│  └────────────────────────┘ │
│  ┌─ 编写 Docker Compose ──┐ │
│  │  电商后台重构 · 11:15   │ │
│  └────────────────────────┘ │
│  ┌─ SwiftUI Color Token ──┐ │
│  │  iOS 组件库迁移 · 昨天  │ │
│  └────────────────────────┘ │
├─────────────────────────────┤
│                             │
│  对话气泡区（AI / 用户）     │  ← 首页就有对话，直接可用
│                             │
├─────────────────────────────┤
│ ┌─────────────────────────┐ │
│ │ 输入指令，或按住说话...   │ │  ← 两行 textarea
│ │                     ↗    │ │  ← 发送按钮
│ │ 🎤 长按输入框进入语音模式 │ │
│ └─────────────────────────┘ │
│ 松手自动发送 · 对准麦克风    │
└─────────────────────────────┘
```

**交互规则：**
- 标签栏位于最底部，共 3 个按钮：首页 / 对话 / 设置

### 2. 项目内对话模式

用户从快捷任务或项目列表点击进入后：

```
┌─────────────────────────────┐
│ ←       家庭装修助手     ⚙ │  ← 汉堡变返回箭头
├─────────────────────────────┤
│  AI Todo 列表                  │  ← 实时更新
│  ○ 扫描现有代码结构 (等待中)  │
│  ● 提取认证逻辑 (进行中)     │
│  ✓ 实现 JWT 中间件            │
│  ✓ 编写单元测试               │
│  ○ 部署到测试环境 (等待中)    │
│                    进度 2/5    │
├─────────────────────────────┤
│                             │
│  对话区                      │
│                             │
├─────────────────────────────┤
│  输入框（同首页）             │
└─────────────────────────────┘
```

**Todo 状态：**
- `等待中` = 空心圆圈 + 灰色文字
- `进行中` = 绿色脉冲圆点 + 主题色"进行中"标签
- `已完成` = 勾选圆圈 + 删除线灰色文字

### 3. 左抽屉 — 项目列表

汉堡按钮 ☰ 点击从左侧滑出，占屏幕 75% 宽度：

```
┌──────────────────────┐
│ 项目列表              │
│ 🔍 搜索项目...        │
├──────────────────────┤
│ 家庭装修助手    ● 运行中│
│ AI 辅助室内设计       │
│ 3 个任务              │
├──────────────────────┤
│ 电商后台重构    ● 运行中│
│ Spring Boot → Go      │
│ 7 个任务              │
├──────────────────────┤
│ iOS 组件库迁移  ● 等待中│
│ UIKit → SwiftUI       │
│ 2 个任务              │
├──────────────────────┤
│ CI/CD 流水线优化 ● 已完成│
│ 构建时间 12min → 3min │
│ 5 个任务              │
├──────────────────────┤
│ [+ 新项目]             │
└──────────────────────┘
```

### 4. 右抽屉 — 设置

右上角齿轮 ⚙ 点击从右侧滑出，占屏幕 75% 宽度：

```
┌──────────────────────┐
│ 设置                  │
├──────────────────────┤
│ 颜色主题              │
│ ┌─────┬─────┬─────┐  │
│ │ DS  │Claude│Trae│  │  ← 2×2 网格
│ │ 蓝  │  橙  │ 绿  │  │
│ ├─────┼─────┼─────┤  │
│ │苹果 │     │     │  │
│ │ 白  │     │     │  │
│ └─────┴─────┴─────┘  │
├──────────────────────┤
│ 通用                  │
│ 语音输入        [on]  │
│ 语音语言   中文(普通话)│
│ 松手自动发送    [on]  │
│ 触觉反馈        [on]  │
├──────────────────────┤
│ 连接                  │
│ 桌面端 Claude Code 已连接│
│ 同步历史记录     [on] │
├──────────────────────┤
│ 关于                  │
│ 版本 1.0.0 (Build 42) │
└──────────────────────┘
```

---

## 5 套配色主题

### DeepSeek 蓝（默认）

```dart
static const deepseek = ThemeConfig(
  accent: Color(0xFF4F6CEB),
  accentRgb: '79, 108, 235',
  bg: Color(0xFFF6F7FB),
  surface: Color(0xC8FFFFFF),
  fg: Color(0xFF181B2E),
  muted: Color(0xFF9094A8),
  border: Color(0x0F000000),
  isDark: false,
);
```

### Claude 橙

```dart
static const claude = ThemeConfig(
  accent: Color(0xFFD9744B),
  bg: Color(0xFFFCF9F6),       // 暖米色底
  fg: Color(0xFF241A14),
  muted: Color(0xFF9B8676),
  isDark: false,
);
```

### Trae 绿（深色模式）

```dart
static const trae = ThemeConfig(
  accent: Color(0xFF12B886),
  bg: Color(0xFF191C1D),       // 深黑底!!! 不是白底
  surface: Color(0xB0242826),
  fg: Color(0xFFE4E6EA),
  muted: Color(0xFF8A8F95),
  isDark: true,
);
```

### 苹果白（Apple TV 风格）

```dart
static const appleLight = ThemeConfig(
  accent: Color(0xFF007AFF),
  bg: Color(0xFFFFFFFF),       // 纯白底
  fg: Color(0xFF1C1C1E),       // 苹果黑
  muted: Color(0xFF8E8E93),
  isDark: false,
);
```

**主题切换全局生效，`ChangeNotifierProvider` 包裹 MaterialApp，所有组件通过 `Theme.of(context)` 获取颜色。**

---

## 核心交互

### 语音输入

```
用户长按输入框 > 400ms
  → 输入框变形:
    - 文字区域 opacity → 0
    - 发送按钮 opacity → 0
    - 麦克风提示 opacity → 0
    - 背景色变为 theme.accent
    - 7 道白色声波条出现 (AnimationController, 持续脉冲)
    - 底部出现 "正在聆听..." 标签

用户松手
  → 恢复输入框原状
  → 语音气泡出现在右侧 (用户侧)
  → 600-1000ms 后 AI 气泡出现在左侧
```

### 声波动画参数

```dart
// 7 条竖线，宽度 3px，初始高度 8px
// 每条延迟 60ms，高度在 8px ↔ 32px 之间来回
// animation.duration = 550ms
for (int i = 0; i < 7; i++) {
  AnimationController(duration: 550.ms)..repeat(reverse: true);
  // delay = i * 60ms
}
```

### 抽屉滑出

```dart
// 左/右抽屉覆盖当前页面，从边缘滑入
// 打开时 overlay 背景 opacity 0→0.4
// 使用 AnimatedPositioned 或 custom route transition
// 持续时间 350ms, 缓动 cubic-bezier(0.22, 0.61, 0.36, 1)
```

---

## 数据模型

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
  String? languageTag; // "Go", "YAML", "Swift" etc.
}

class ChatMessage {
  String id;
  MessageType type; // ai, user, system
  String content;
  bool isVoice;
  int? voiceDuration; // seconds
  DateTime timestamp;
}
```

---

## 通信协议

与 Claude Code MCP Server 的通信方式（由 `od mcp` 提供）：

```json
// 发送指令
{
  "type": "command",
  "projectId": "proj-001",
  "content": "拆分用户认证模块，用 Go 重写",
  "source": "voice" | "text"
}

// 服务端推送 Todo 更新
{
  "type": "todo_update",
  "projectId": "proj-001",
  "todos": [
    { "id": "t1", "title": "扫描现有代码结构", "status": "done" },
    { "id": "t2", "title": "提取认证逻辑", "status": "active" },
    { "id": "t3", "title": "实现 JWT 中间件", "status": "waiting" }
  ]
}

// 服务端推送 AI 回复
{
  "type": "ai_message",
  "projectId": "proj-001",
  "content": "好的，已开始执行..."
}
```

---

## 文件结构建议

```
lib/
├── main.dart                    // MaterialApp + 主题 provider
├── theme/
│   ├── theme_config.dart        // 4 套配色定义
│   └── theme_provider.dart      // ChangeNotifier
├── models/
│   ├── project.dart
│   ├── chat_message.dart
│   └── todo_item.dart
├── providers/
│   ├── chat_provider.dart       // 对话状态管理
│   ├── project_provider.dart    // 项目列表 + 当前项目
│   └── todo_provider.dart       // Todo 状态 + 实时更新
├── services/
│   ├── mcp_client.dart          // WebSocket 通信
│   └── voice_service.dart       // 语音识别
├── screens/
│   ├── home_page.dart           // 首页 = 对话 + 快捷任务
│   └── project_chat_page.dart   // 项目内对话 + Todo
├── widgets/
│   ├── chat_bubble.dart         // 气泡组件
│   ├── voice_input.dart         // 输入框 + 声波变形
│   ├── todo_list.dart           // Todo 列表
│   ├── drawer_project_list.dart // 左抽屉
│   ├── drawer_settings.dart     // 右抽屉
│   ├── recent_task_card.dart    // 快捷任务卡片
│   └── glass_container.dart     // 玻璃效果封装
└── generated/                   // 如果有代码生成
```

---

## UI 细节速查

| 属性 | 值 |
|------|------|
| 字体 | SF Pro Display (标题), SF Pro Text (正文), SF Mono (数字) |
| 圆角 | 卡片 18px, 输入框 22px, 气泡 20px, 按钮 999px |
| 玻璃效果 | `ClipRRect` + `BackdropFilter(brightness: 1.08, blur: 24)` |
| 气泡圆角 | AI: 右下 8px 直角, User: 左下 8px 直角 |
| 输入框高度 | 两行文字 (minHeight 48px) |
| 阴影 | `BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20)` |
| 动画时长 | 页面切换 350ms, 气泡入场 350ms, 主题切换 400ms |
| 抽屉宽度 | 屏幕宽度的 75% |
