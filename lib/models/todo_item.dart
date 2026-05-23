enum TodoStatus { waiting, active, done }

class TodoItem {
  final String id;
  final String title;
  final TodoStatus status;

  const TodoItem({
    required this.id,
    required this.title,
    this.status = TodoStatus.waiting,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      status: TodoStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TodoStatus.waiting,
      ),
    );
  }
}
