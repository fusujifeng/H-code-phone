import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/chat_message.dart';
import '../models/todo_item.dart';
import '../providers/project_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/todo_provider.dart';
import '../providers/ws_provider.dart';
import '../services/ws_client.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_input.dart';
import '../widgets/todo_list.dart';
import '../widgets/recent_task_card.dart';
import '../widgets/drawer_projects.dart';
import '../widgets/drawer_settings.dart';
import '../theme/theme_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  bool _pairDialogShown = false;
  String _aiResponseBuffer = '';
  Timer? _aiResponseTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenToMessages());
  }

  void _showPairDialog() {
    final pairController = TextEditingController();
    bool connecting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: StatefulBuilder(
            builder: (builderCtx, setDialogState) {
              return AlertDialog(
                title: const Text('连接服务器'),
                content: TextField(
                  controller: pairController,
                  decoration: const InputDecoration(
                    hintText: '请输入配对码',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                ),
                actions: [
                  TextButton(
                    onPressed: connecting
                        ? null
                        : () async {
                            final code = pairController.text.trim();
                            if (code.isEmpty) return;
                            setDialogState(() => connecting = true);
                            try {
                              await ref
                                  .read(wsClientProvider)
                                  .connectAndRegister(code);
                            } finally {
                              setDialogState(() => connecting = false);
                            }
                          },
                    child: Text(connecting ? '连接中...' : '连接'),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).then((_) {
      _pairDialogShown = false;
    });
  }

  void _listenToMessages() {
    final ws = ref.read(wsClientProvider);
    ws.messages.listen((msg) {
      final type = msg['type'] as String?;
      switch (type) {
        case 'ai_response':
          final payload = msg['payload'];
          String content = payload is String ? payload : jsonEncode(payload);
          content = _stripAnsi(content).trim();
          if (content.isEmpty) return;
          // 累积并 debounce：桌面端已通过 --print 发送干净输出，短缓冲即可
          _aiResponseBuffer += (_aiResponseBuffer.isEmpty ? '' : '\n') + content;
          _aiResponseTimer?.cancel();
          _aiResponseTimer = Timer(const Duration(milliseconds: 500), () {
            final result = _aiResponseBuffer.trim();
            _aiResponseBuffer = '';
            if (result.isEmpty) return;
            ref.read(chatProvider.notifier).removeThinking();
            ref.read(chatProvider.notifier).addMessage(ChatMessage(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  type: MessageType.ai,
                  content: result,
                  timestamp: DateTime.now(),
                ));
          });
          break;
        case 'todo_update':
          final payload = msg['payload'];
          List todos;
          if (payload is List) {
            todos = payload;
          } else if (payload is String) {
            try {
              todos = jsonDecode(payload) as List;
            } catch (_) {
              todos = [];
            }
          } else {
            todos = [];
          }
          final items = todos.map((t) {
            final map = t as Map<String, dynamic>;
            return TodoItem(
              id: map['id'] as String? ?? '',
              title: map['title'] as String? ?? '',
              status: TodoStatus.values.firstWhere(
                (s) => s.name == map['status'],
                orElse: () => TodoStatus.waiting,
              ),
            );
          }).toList();
          ref.read(todoProvider.notifier).updateTodos(items);
          break;
      }
    });
  }

  @override
  void dispose() {
    _aiResponseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    ref.read(chatProvider.notifier).addMessage(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          type: MessageType.user,
          content: text,
          timestamp: DateTime.now(),
        ));
    ref.read(chatProvider.notifier).upsertThinking('');
    final ws = ref.read(wsClientProvider);
    if (ws.status == WsStatus.connected) {
      ws.sendCommand(text);
    }
    _scrollToBottom();
  }

  String _stripAnsi(String text) {
    // Strip complete CSI sequences
    text = text.replaceAll(RegExp(r'\x1b\[[0-9;?]*[A-Za-z]'), '');
    // Strip OSC sequences
    text = text.replaceAll(RegExp(r'\x1b\][^\x07]*\x07'), '');
    text = text.replaceAll(RegExp(r'\x1b\][^\x1b]*\x1b\\'), '');
    // Strip other ESC-prefixed sequences
    text = text.replaceAll(RegExp(r'\x1b[PX^_][^\x1b]*\x1b\\?'), '');
    text = text.replaceAll(RegExp(r'\x1b.'), '');
    // Strip ANSI remnants where ESC was lost in transport
    text = text.replaceAll(RegExp(r'\[[0-9;]+m'), '');
    text = text.replaceAll(RegExp(r'\[[0-9;]*[KJhlsu]'), '');
    // Strip braille spinners
    text = text.replaceAll(RegExp(r'[⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏]'), '');
    // Filter TUI status lines
    final lines = text.split('\n');
    final meaningful = lines.where((line) {
      final t = line.trim();
      if (t.isEmpty) return false;
      if (RegExp(r'^\[.+\]\s*\|').hasMatch(t)) return false;
      if (RegExp(r'^\([^)]*\*\)\s*$').hasMatch(t)) return false;
      if (RegExp(r'^Context\s+\d+%').hasMatch(t)) return false;
      if (RegExp(r'^\d+CLAUDE\.md').hasMatch(t)) return false;
      if (RegExp(r'^\*\s*\w+\s+for\s+[\d.]+s').hasMatch(t)) return false;
      if (RegExp(r'^\s*[↓↑]\s*\d+\s*token').hasMatch(t)) return false;
      if (RegExp(r'^\d*thought\s+for\s+\d+s?\)?').hasMatch(t)) return false;
      if (RegExp(r'^[*\s]*(thinking|Thought\.{2,})\)?').hasMatch(t)) return false;
      return true;
    });
    return meaningful.join('\n');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final projectState = ref.watch(projectProvider);
    final ws = ref.watch(wsClientProvider);
    final theme = Theme.of(context);
    final themeProvider = ThemeProviderScope.of(context);

    ref.listen(wsClientProvider, (prev, next) {
      if (next.status == WsStatus.connected && _pairDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        _pairDialogShown = false;
      } else if (next.status == WsStatus.disconnected && !_pairDialogShown) {
        _pairDialogShown = true;
        _showPairDialog();
      }
    });

    // Show pair dialog on first load if not connected
    if (!_pairDialogShown && ws.status != WsStatus.connected) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_pairDialogShown) {
          _pairDialogShown = true;
          _showPairDialog();
        }
      });
    }

    final connStatusText = ws.status == WsStatus.connected
        ? 'Claude Code 已连接'
        : ws.status == WsStatus.connecting
            ? 'Claude Code 连接中...'
            : 'Claude Code 未连接';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: theme.colorScheme.primary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            const Text('AI 指挥中心', style: TextStyle(fontSize: 17)),
            Text(
              connStatusText,
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.settings_outlined,
                  color: theme.colorScheme.primary),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: DrawerProjects(
        projects: projectState.recent,
        onSelect: (p) => _openProject(p),
        onNew: () {},
      ),
      endDrawer: themeProvider != null
          ? DrawerSettings(themeProvider: themeProvider)
          : null,
      body: Column(
        children: [
          if (projectState.current == null && projectState.recent.isNotEmpty) ...[
            const SizedBox(height: 4),
            ...projectState.recent.take(3).map(
                  (p) => RecentTaskCard(
                    project: p,
                    onTap: () => _openProject(p),
                  ),
                ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) {
                final msg = chatState.messages[i];
                return ChatBubble(
                  content: msg.content,
                  isUser: msg.type == MessageType.user,
                  isSystem: msg.type == MessageType.system,
                  isVoice: msg.isVoice,
                  voiceDuration: msg.voiceDuration,
                  isThinking: msg.id.startsWith('thinking-'),
                );
              },
            ),
          ),
          VoiceInput(
            onSend: _sendMessage,
            onVoiceResult: (text) => _sendMessage(text),
          ),
        ],
      ),
    );
  }

  void _openProject(Project p) {
    ref.read(projectProvider.notifier).setCurrent(p);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProjectPage(project: p),
      ),
    );
  }
}

class ProjectPage extends ConsumerWidget {
  final Project project;

  const ProjectPage({super.key, required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final chatState = ref.watch(chatProvider);
    final ws = ref.watch(wsClientProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(project.name),
      ),
      body: Column(
        children: [
          if (todoState.todos.isNotEmpty)
            TodoListWidget(todos: todoState.todos),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) {
                final msg = chatState.messages[i];
                return ChatBubble(
                  content: msg.content,
                  isUser: msg.type == MessageType.user,
                  isSystem: msg.type == MessageType.system,
                );
              },
            ),
          ),
          VoiceInput(
            onSend: (text) {
              ref.read(chatProvider.notifier).addMessage(ChatMessage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    type: MessageType.user,
                    content: text,
                    timestamp: DateTime.now(),
                  ));
              if (ws.status == WsStatus.connected) {
                ws.sendCommand(text);
              }
            },
            onVoiceResult: (text) {},
          ),
        ],
      ),
    );
  }
}
