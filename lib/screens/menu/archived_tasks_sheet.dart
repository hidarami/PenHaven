import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/todo.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';

/// Bottom sheet listing all auto-archived todos.
/// The spec's Mercy Rule means tasks disappear quietly — this is where
/// they go. Users can restore or permanently delete from here.
class ArchivedTasksSheet extends StatelessWidget {
  const ArchivedTasksSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ArchivedTasksSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final atmosphereState = context.watch<AtmosphereState>();
    final isDark = appState.isDarkMode;
    final bg = atmosphereState.backgroundFor(isDark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final sheetBg = isDark ? AppColors.warmDark : AppColors.warmWhite;

    final archived = appState.archivedTodos;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.15)
                        : Colors.black.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Archived Tasks',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'They faded quietly. No judgment.',
                      style: GoogleFonts.crimsonPro(
                        fontSize: 15,
                        fontStyle: FontStyle.italic,
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  height: 0.5,
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.08),
                ),
              ),
              const SizedBox(height: 8),

              // List
              Expanded(
                child: archived.isEmpty
                    ? _EmptyArchive(mutedColor: mutedColor)
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: archived.length,
                        itemBuilder: (context, index) {
                          return _ArchivedTaskTile(
                            todo: archived[index],
                            isDark: isDark,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onRestore: () =>
                                appState.restoreTodo(archived[index].id),
                            onDelete: () => appState
                                .permanentlyDeleteTodo(archived[index].id),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Archived task tile ──────────────────────────────────────────────────────

class _ArchivedTaskTile extends StatelessWidget {
  final Todo todo;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const _ArchivedTaskTile({
    required this.todo,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(0.04)
        : Colors.black.withOpacity(0.03);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Strikethrough check
          Icon(
            todo.isCompleted
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: mutedColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  todo.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: textColor.withOpacity(0.65),
                    decoration:
                        todo.isCompleted ? TextDecoration.lineThrough : null,
                    decorationColor: mutedColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _archiveSummary(todo),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: mutedColor.withOpacity(0.6),
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          // Restore
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.restore_rounded,
              size: 18,
              color: Colors.grey.withAlpha(76),
            ),
            onPressed: onRestore,
          ),
          // Delete forever
          IconButton(
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: mutedColor,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _archiveSummary(Todo todo) {
    if (todo.isCompleted && todo.completedAt != null) {
      return 'completed ${_relativeDate(todo.completedAt!)}';
    }
    if (todo.deadline != null) {
      return 'deadline was ${DateFormat("MMM d").format(todo.deadline!)}';
    }
    return 'created ${_relativeDate(todo.createdAt)}';
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ── Empty state ─────────────────────────────────────────────────────────────

class _EmptyArchive extends StatelessWidget {
  final Color mutedColor;

  const _EmptyArchive({required this.mutedColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Nothing here.\nYour tasks are still with you.',
          textAlign: TextAlign.center,
          style: GoogleFonts.crimsonPro(
            fontSize: 17,
            fontStyle: FontStyle.italic,
            color: mutedColor,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}
