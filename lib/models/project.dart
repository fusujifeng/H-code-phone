import 'todo_item.dart';
import 'chat_message.dart';

enum ProjectStatus { running, waiting, done }

class Project {
  final String id;
  final String name;
  final String description;
  final ProjectStatus status;
  final int taskCount;
  final List<TodoItem> todos;
  final List<ChatMessage> messages;
  final DateTime lastActive;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.status = ProjectStatus.waiting,
    this.taskCount = 0,
    this.todos = const [],
    this.messages = const [],
    required this.lastActive,
  });

  Project copyWith({
    String? name,
    String? description,
    ProjectStatus? status,
    int? taskCount,
    List<TodoItem>? todos,
    List<ChatMessage>? messages,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      taskCount: taskCount ?? this.taskCount,
      todos: todos ?? this.todos,
      messages: messages ?? this.messages,
      lastActive: lastActive,
    );
  }
}
