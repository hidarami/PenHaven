import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import 'work_desk_header.dart';
import 'task_input.dart';
import 'task_list.dart';
import 'time_capsule_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WORK DESK PANEL — Panel 2
// Rightmost panel. Tasks, thoughts, and time capsule.
// Access: swipe left from Story Panel.
//
// Layout:
//   - Header: "Work Desk" title + hourglass icon top-right
//   - Task input field (neumorphic)
//   - Scrollable task list
//
// Mercy Rule: Tasks quietly fade and auto-archive. Nothing turns red.
// ─────────────────────────────────────────────────────────────────────────────

class WorkDeskPanel extends StatefulWidget {
  const WorkDeskPanel({super.key});

  @override
  State<WorkDeskPanel> createState() => _WorkDeskPanelState();
}

class _WorkDeskPanelState extends State<WorkDeskPanel>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Run mercy archive when Work Desk becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().runMercyArchive();
    });
  }

  void _openTimeCapsule() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TimeCapsuleSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final topPadding = MediaQuery.of(context).padding.top;
    final dark = context.watch<AppState>().isDarkMode;
    final dividerColor = dark ? AppColors.dividerDark : AppColors.dividerLight;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPadding > 0 ? 60 : 80),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: WorkDeskHeader(onTimeCapsuleTap: _openTimeCapsule),
          ),

          const SizedBox(height: 24),

          // ── Task input ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TaskInput(
              onAddTask: (title, deadline) async {
                await context
                    .read<AppState>()
                    .addTodo(title: title, deadline: deadline);
              },
            ),
          ),

          const SizedBox(height: 20),

          Divider(color: dividerColor, thickness: 0.5, height: 0),

          // ── Task list ─────────────────────────────────────────────────
          const Expanded(child: TaskList()),
        ],
      ),
    );
  }
}
