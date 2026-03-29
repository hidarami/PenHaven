import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR TITLE FIELD
// Editable title (Crimson Pro 32pt bold) with a tappable date below it.
// Tapping the date opens a DatePicker to customise the entry date.
// ─────────────────────────────────────────────────────────────────────────────

class EditorTitleField extends StatefulWidget {
  final TextEditingController controller;
  final Entry entry;
  final ValueChanged<DateTime> onDateChanged;

  const EditorTitleField({
    super.key,
    required this.controller,
    required this.entry,
    required this.onDateChanged,
  });

  @override
  State<EditorTitleField> createState() => _EditorTitleFieldState();
}

class _EditorTitleFieldState extends State<EditorTitleField> {
  late DateTime _displayDate;

  @override
  void initState() {
    super.initState();
    _displayDate = widget.entry.createdAt;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _displayDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;

    // Preserve original time, change only date
    final updated = DateTime(
      picked.year,
      picked.month,
      picked.day,
      _displayDate.hour,
      _displayDate.minute,
    );
    setState(() => _displayDate = updated);
    widget.onDateChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Title TextField ────────────────────────────────────────────────
        TextField(
          controller: widget.controller,
          style: AppTypography.editorTitle(textColor),
          textInputAction: TextInputAction.next,
          maxLines: null,
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Entry title...',
            hintStyle: AppTypography.editorTitle(mutedColor),
          ),
        ),

        const SizedBox(height: 6),

        // ── Tappable date ──────────────────────────────────────────────────
        GestureDetector(
          onTap: _pickDate,
          child: Text(
            DateFormat('MMMM d, yyyy').format(_displayDate),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: mutedColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
