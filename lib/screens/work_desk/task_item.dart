import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/todo.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TASK ITEM
// Single todo row. Per Master Specification §3:
//
//   - Single tap on checkbox → marks complete, starts 3-second fade, archives
//   - Long press on text → enters inline edit mode (TextField replaces text)
//   - Completed tasks fade via AnimatedOpacity over 3 seconds then disappear
//   - NO red labels, NO "overdue" text — tasks just quietly fade away
// ─────────────────────────────────────────────────────────────────────────────

class TaskItem extends StatefulWidget {
  final Todo todo;

  const TaskItem({super.key, required this.todo});

  @override
  State<TaskItem> createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _fading = false;
  bool _editing = false;
  late TextEditingController _editController;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.todo.title);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _saveEdit();
    });
    // If already completed (e.g. restored from DB), start fade immediately
    if (widget.todo.isCompleted) {
      _fading = true;
      _scheduleArchive();
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ── Completion ─────────────────────────────────────────────────────────────

  Future<void> _onCheckboxTap() async {
    if (_fading) return; // Already fading
    final appState = context.read<AppState>();
    await appState.completeTodo(widget.todo.id);
    setState(() => _fading = true);
    _scheduleArchive();
  }

  void _scheduleArchive() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        context.read<AppState>().archiveTodo(widget.todo.id);
      }
    });
  }

  // ── Inline edit ────────────────────────────────────────────────────────────

  void _startEdit() {
    if (_fading) return;
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
  }

  void _saveEdit() {
    final newTitle = _editController.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.todo.title) {
      context.read<AppState>().updateTodoTitle(widget.todo.id, newTitle);
    } else {
      _editController.text = widget.todo.title;
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return AnimatedOpacity(
      opacity: _fading ? 0.0 : 1.0,
      duration: const Duration(seconds: 3),
      curve: Curves.easeOut,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Circle checkbox ──────────────────────────────────────────
            GestureDetector(
              onTap: _onCheckboxTap,
              child: Padding(
                padding: const EdgeInsets.only(top: 2, right: 14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.todo.isCompleted
                        ? AppColors.teal
                        : Colors.transparent,
                    border: Border.all(
                      color: widget.todo.isCompleted
                          ? AppColors.teal
                          : mutedColor,
                      width: 1.5,
                    ),
                  ),
                  child: widget.todo.isCompleted
                      ? const Icon(
                          Icons.check,
                          size: 12,
                          color: Colors.white,
                        )
                      : null,
                ),
              ),
            ),

            // ── Task text or edit field ───────────────────────────────────
            Expanded(
              child: GestureDetector(
                onLongPress: _startEdit,
                child: _editing
                    ? TextField(
                        controller: _editController,
                        focusNode: _focusNode,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: textColor,
                          height: 1.4,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _saveEdit(),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.todo.title,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              color: widget.todo.isCompleted
                                  ? mutedColor
                                  : textColor,
                              height: 1.4,
                              decoration: widget.todo.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: mutedColor,
                            ),
                          ),
                          // Deadline (if set) — no red, just muted
                          if (widget.todo.deadline != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d').format(widget.todo.deadline!),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: mutedColor.withOpacity(0.7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
