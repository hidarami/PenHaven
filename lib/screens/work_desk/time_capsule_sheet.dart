import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../models/time_capsule.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/neumorphic_widgets.dart';
import '../entry_read/entry_read_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TIME CAPSULE SHEET
// Bottom sheet accessed via the hourglass icon on Work Desk.
// Three sections:
//   1. "On this day" — entries from same day in previous years
//   2. Ready capsules — user-written letters past their open date
//   3. Create new capsule — write a message, pick a future date
// ─────────────────────────────────────────────────────────────────────────────

class TimeCapsuleSheet extends StatelessWidget {
  const TimeCapsuleSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_empty_rounded,
                      size: 18,
                      color: AppColors.aqua,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Time Capsule',
                      style: AppTypography.panelHeader(textColor)
                          .copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  children: [
                    _OnThisDaySection(mutedColor: mutedColor, textColor: textColor),
                    const SizedBox(height: 24),
                    _ReadyCapsuleSection(mutedColor: mutedColor, textColor: textColor),
                    const SizedBox(height: 24),
                    _CreateCapsuleSection(mutedColor: mutedColor, textColor: textColor),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ON THIS DAY
// ─────────────────────────────────────────────────────────────────────────────

class _OnThisDaySection extends StatelessWidget {
  final Color mutedColor;
  final Color textColor;

  const _OnThisDaySection({
    required this.mutedColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final entries = context.watch<AppState>().timeCapsuleEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ON THIS DAY',
          style: AppTypography.sectionLabel(mutedColor),
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Text(
            'No memories from this day yet.\nKeep writing — they\'ll appear here.',
            style: GoogleFonts.crimsonPro(
              fontSize: 16,
              fontStyle: FontStyle.italic,
              color: mutedColor.withOpacity(0.6),
              height: 1.6,
            ),
          )
        else
          ...entries.map((e) => _OnThisDayCard(entry: e, textColor: textColor, mutedColor: mutedColor)),
      ],
    );
  }
}

class _OnThisDayCard extends StatelessWidget {
  final Entry entry;
  final Color textColor;
  final Color mutedColor;

  const _OnThisDayCard({
    required this.entry,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final yearAgo = DateTime.now().year - entry.createdAt.year;
    final yearLabel = yearAgo == 1 ? 'A year ago today' : '$yearAgo years ago';

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EntryReadScreen(entry: entry),
          ),
        );
      },
      child: NeumorphicCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              yearLabel,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.aqua,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.title.isEmpty ? 'Untitled' : entry.title,
              style: GoogleFonts.crimsonPro(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (entry.content.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                entry.preview(80),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: mutedColor,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READY CAPSULES
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyCapsuleSection extends StatelessWidget {
  final Color mutedColor;
  final Color textColor;

  const _ReadyCapsuleSection({
    required this.mutedColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final capsules = context.watch<AppState>().readyCapsules;
    if (capsules.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('READY TO OPEN', style: AppTypography.sectionLabel(mutedColor)),
        const SizedBox(height: 12),
        ...capsules.map((c) => _CapsuleCard(
              capsule: c,
              textColor: textColor,
              mutedColor: mutedColor,
            )),
      ],
    );
  }
}

class _CapsuleCard extends StatefulWidget {
  final TimeCapsule capsule;
  final Color textColor;
  final Color mutedColor;

  const _CapsuleCard({
    required this.capsule,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  State<_CapsuleCard> createState() => _CapsuleCardState();
}

class _CapsuleCardState extends State<_CapsuleCard> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NeumorphicCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('MMMM d, yyyy').format(widget.capsule.createdAt),
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.aqua,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            if (_opened)
              Text(
                widget.capsule.message,
                style: GoogleFonts.crimsonPro(
                  fontSize: 16,
                  color: widget.textColor,
                  height: 1.6,
                ),
              )
            else
              NeumorphicButton(
                onTap: () {
                  setState(() => _opened = true);
                  context.read<AppState>().openCapsule(widget.capsule.id);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_open_outlined,
                        size: 14, color: AppColors.aqua),
                    const SizedBox(width: 6),
                    Text(
                      'Open capsule',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.aqua,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE NEW CAPSULE
// ─────────────────────────────────────────────────────────────────────────────

class _CreateCapsuleSection extends StatefulWidget {
  final Color mutedColor;
  final Color textColor;

  const _CreateCapsuleSection({
    required this.mutedColor,
    required this.textColor,
  });

  @override
  State<_CreateCapsuleSection> createState() => _CreateCapsuleSectionState();
}

class _CreateCapsuleSectionState extends State<_CreateCapsuleSection> {
  final _controller = TextEditingController();
  DateTime? _openAt;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _openAt = picked);
  }

  Future<void> _save() async {
    final message = _controller.text.trim();
    if (message.isEmpty || _openAt == null || _saving) return;

    setState(() => _saving = true);
    await context.read<AppState>().addTimeCapsule(
          message: message,
          openAt: _openAt!,
        );
    _controller.clear();
    setState(() {
      _openAt = null;
      _saving = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Capsule sealed. See you then.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('WRITE A CAPSULE', style: AppTypography.sectionLabel(widget.mutedColor)),
        const SizedBox(height: 12),
        NeumorphicCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                style: GoogleFonts.crimsonPro(
                  fontSize: 16,
                  color: widget.textColor,
                  height: 1.6,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Write something to your future self...',
                  hintStyle: GoogleFonts.crimsonPro(
                    fontSize: 16,
                    color: widget.mutedColor,
                    fontStyle: FontStyle.italic,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Date picker
                  GestureDetector(
                    onTap: _pickDate,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: _openAt != null
                              ? AppColors.aqua
                              : widget.mutedColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _openAt != null
                              ? 'Opens ${DateFormat('MMM d, yyyy').format(_openAt!)}'
                              : 'Pick open date',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _openAt != null
                                ? AppColors.aqua
                                : widget.mutedColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Seal button
                  NeumorphicButton(
                    onTap: _save,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Text(
                      'Seal',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.aqua,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
