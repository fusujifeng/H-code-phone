import 'package:flutter/material.dart';
import '../models/todo_item.dart';
import 'animated_builder.dart';

class TodoListWidget extends StatelessWidget {
  final List<TodoItem> todos;

  const TodoListWidget({super.key, required this.todos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneCount = todos.where((t) => t.status == TodoStatus.done).length;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI 任务列表',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount / ${todos.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...todos.map((todo) => _TodoItemRow(todo: todo, theme: theme)),
        ],
      ),
    );
  }
}

class _TodoItemRow extends StatelessWidget {
  final TodoItem todo;
  final ThemeData theme;

  const _TodoItemRow({required this.todo, required this.theme});

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    Widget mark;
    if (todo.status == TodoStatus.done) {
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    } else if (todo.status == TodoStatus.active) {
      mark = _PulsingDot(accent: theme.colorScheme.primary);
    } else {
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.onSurface.withAlpha(50),
            width: 2,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: todo.status == TodoStatus.done
                    ? theme.colorScheme.onSurface.withAlpha(128)
                    : theme.colorScheme.onSurface,
                decoration: todo.status == TodoStatus.done
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
          ),
          if (todo.status == TodoStatus.active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '进行中',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          if (todo.status == TodoStatus.waiting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x1EFF9F0A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '等待中',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFFD48806),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color accent;
  const _PulsingDot({required this.accent});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..repeat(reverse: true);
    _scaleAnim = Tween(begin: 0.6, end: 1.0).animate(_controller);
    _opacityAnim = Tween(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: widget.accent, width: 2),
      ),
      child: Center(
        child: SimpleAnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
