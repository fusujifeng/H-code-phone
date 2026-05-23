import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';

class ProjectState {
  final Project? current;
  final List<Project> recent;
  ProjectState({this.current, List<Project>? recent})
      : recent = recent ?? [];
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(ProjectState());

  void setCurrent(Project p) {
    state = ProjectState(current: p, recent: state.recent);
  }

  void clearCurrent() {
    state = ProjectState(recent: state.recent);
  }

  void setRecent(List<Project> projects) {
    state = ProjectState(current: state.current, recent: projects);
  }
}

final projectProvider =
    StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});
