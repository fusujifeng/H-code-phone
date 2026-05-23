import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';

class TodoState {
  final List<TodoItem> todos;
  TodoState([List<TodoItem>? todos]) : todos = todos ?? [];

  int get doneCount => todos.where((t) => t.status == TodoStatus.done).length;
  int get total => todos.length;
}

class TodoNotifier extends StateNotifier<TodoState> {
  TodoNotifier() : super(TodoState());

  void updateTodos(List<TodoItem> todos) {
    state = TodoState(todos);
  }
}

final todoProvider = StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  return TodoNotifier();
});
