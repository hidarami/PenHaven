import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/neumorphic_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TASK INPUT
// Neumorphic container with:
//   - "+" icon on the left
//   - Text field: "Add a thought..."
//   - Calendar icon (toggles deadline picker)
//   - Submit arrow on the right
//
// Deadline is optional. When set, a small chip shows the date below the input.
// ─────────────────────────────────────────────────────────────────────────────

class TaskInput extends StatefulWidget {
  final Future<void> Function(String title, DateTime? deadline) onAddTask;

  const TaskInput({super.key, required this.onAddTask});

  @override
  State<TaskInput> createState() => _TaskInputState();
}

class _TaskInputState extends State<TaskInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  DateTime? _deadline;
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _deadline = picked);
    }
  }

  void _clearDeadline() => setState(() => _deadline = null);

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    await widget.onAddTask(title, _deadline);

    _controller.clear();
    setState(() {
      _deadline = null;
      _submitting = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Main input row ─────────────────────────────────────────────
        NeumorphicInput(
          controller: _controller,
          focusNode: _focusNode,
          hintText: 'Add a thought...',
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          prefixWidget: Icon(Icons.add, size: 18, color: mutedColor),
          suffixWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Calendar icon
              GestureDetector(
                onTap: _pickDeadline,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: _deadline != null ? AppColors.aqua : mutedColor,
                  ),
                ),
              ),
              // Submit arrow
              GestureDetector(
                onTap: _submit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.aqua,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Deadline chip (shown when deadline is set) ─────────────────
        if (_deadline != null) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _clearDeadline,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: AppColors.aqua,
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('MMM d').format(_deadline!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.aqua,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.close, size: 12, color: AppColors.aqua),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
