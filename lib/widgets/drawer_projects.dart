import 'package:flutter/material.dart';
import '../models/project.dart';

class DrawerProjects extends StatelessWidget {
  final List<Project> projects;
  final Function(Project) onSelect;
  final VoidCallback onNew;

  const DrawerProjects({
    super.key,
    required this.projects,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: theme.colorScheme.surface.withAlpha(240),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('项目',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.onSurface.withAlpha(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        size: 15,
                        color:
                            theme.colorScheme.onSurface.withAlpha(100)),
                    const SizedBox(width: 8),
                    Text('搜索项目...',
                        style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface
                                .withAlpha(100))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: projects.length,
                itemBuilder: (_, i) {
                  final p = projects[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(p);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(180),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color:
                              theme.colorScheme.onSurface.withAlpha(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 12, top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.status == ProjectStatus.running
                                  ? const Color(0xFF34C759)
                                  : const Color(0xFFFF9F0A),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name,
                                    style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color:
                                            theme.colorScheme.onSurface)),
                                Text(p.description,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface
                                            .withAlpha(128))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新项目',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
