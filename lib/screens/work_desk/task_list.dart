import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import 'task_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TASK LIST
// Scrollable list of active todos. Completed items fade over 3 seconds
// before being archived (handled per-item in TaskItem).
// Shows a quiet "all clear" message when empty.
// ─────────────────────────────────────────────────────────────────────────────

class TaskList extends StatelessWidget {
  const TaskList({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final todos = appState.activeTodos;
    final dark = appState.isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    if (todos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: Text(
            'Nothing here.\nThat\'s okay.',
            textAlign: TextAlign.center,
            style: GoogleFonts.crimsonPro(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: mutedColor.withOpacity(0.6),
              height: 1.6,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 100),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        return TaskItem(
          key: ValueKey(todos[index].id),
          todo: todos[index],
        );
      },
    );
  }
}
