import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:flutter/services.dart';
import '../../data/capsule_dao.dart';
import '../../models/period_log.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PERIOD TRACKER SCREEN
// Gates behind biometric if enabled (health vault).
// Shows: current cycle status, flow level, monthly calendar, stats, history.
// ─────────────────────────────────────────────────────────────────────────────

const Color _pink = Color(0xFFE91E63);

class PeriodTrackerScreen extends StatefulWidget {
  const PeriodTrackerScreen({super.key});

  @override
  State<PeriodTrackerScreen> createState() => _PeriodTrackerScreenState();
}

class _PeriodTrackerScreenState extends State<PeriodTrackerScreen> {
  List<PeriodLog> _logs = [];
  bool _loading = true;
  bool _authenticated = false;
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final appState = context.read<AppState>();
    if (appState.isBiometricEnabled) {
      final ok = await AuthService.instance.authenticateHealthVault();
      if (!ok && mounted) { Navigator.of(context).pop(); return; }
    }
    setState(() => _authenticated = true);
    await _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await CapsuleDao.instance.getAllPeriodLogs();
    if (mounted) setState(() { _logs = logs; _loading = false; });
  }

  PeriodLog? get _activePeriod {
    try { return _logs.firstWhere((p) => p.isActive); } catch (_) { return null; }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> get _stats {
    final completed = _logs
        .where((p) => !p.isActive && p.endDate != null)
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    if (completed.isEmpty) return {};

    final avgDuration = completed
        .where((p) => p.durationDays != null)
        .fold<int>(0, (sum, p) => sum + p.durationDays!) ~/
        completed.where((p) => p.durationDays != null).length.clamp(1, 999);

    int? avgCycle;
    DateTime? nextPredicted;
    if (completed.length >= 2) {
      int total = 0;
      for (int i = 1; i < completed.length; i++) {
        total += completed[i].startDate.difference(completed[i - 1].startDate).inDays;
      }
      avgCycle = total ~/ (completed.length - 1);
      nextPredicted = completed.last.startDate.add(Duration(days: avgCycle));
    }

    return {'avgDuration': avgDuration, 'avgCycle': avgCycle, 'nextPredicted': nextPredicted};
  }

  // ── Period dates for calendar ─────────────────────────────────────────────

  Set<DateTime> get _periodDates {
    final dates = <DateTime>{};
    for (final log in _logs) {
      final end = log.endDate ?? DateTime.now();
      var cur = log.startDate;
      while (!cur.isAfter(end)) {
        dates.add(DateTime(cur.year, cur.month, cur.day));
        cur = cur.add(const Duration(days: 1));
      }
    }
    return dates;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _startPeriod() async {
    HapticFeedback.mediumImpact();
    await context.read<AppState>().startPeriod();
    await _loadLogs();
  }

  Future<void> _endPeriod() async {
    final active = _activePeriod;
    if (active == null) return;
    await context.read<AppState>().endPeriod(active.id);
    await _loadLogs();
  }

  Future<void> _setFlowLevel(int level) async {
    final active = _activePeriod;
    if (active == null) return;
    await CapsuleDao.instance.updatePeriodLog(active.copyWith(flowLevel: level));
    await _loadLogs();
  }

  Future<void> _updateNotes(String notes) async {
    final active = _activePeriod;
    if (active == null) return;
    await CapsuleDao.instance.updatePeriodLog(active.copyWith(notes: notes));
  }

  Future<void> _deleteLog(PeriodLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this entry?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _pink))),
        ],
      ),
    );
    if (confirmed == true) {
      await CapsuleDao.instance.deletePeriodLog(log.id);
      await _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authenticated) {
      return const Scaffold(backgroundColor: AppColors.warmDark, body: Center(child: CircularProgressIndicator()));
    }

    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    return GestureDetector(
      onHorizontalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // Header
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 16, 0),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Icon(Icons.chevron_left_rounded, size: 28, color: mutedColor),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Period Tracker', style: GoogleFonts.crimsonPro(
                                  fontSize: 28, fontWeight: FontWeight.w700, color: textColor,
                                )),
                                Text('private & local', style: GoogleFonts.inter(
                                  fontSize: 11, color: mutedColor, letterSpacing: 0.5,
                                )),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 24)),

                    // Status card
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _StatusCard(
                          activePeriod: _activePeriod,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          isDark: dark,
                          onStart: _startPeriod,
                          onEnd: _endPeriod,
                          onFlowLevel: _setFlowLevel,
                          onNotesChanged: _updateNotes,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),

                    // Calendar
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _MonthCalendar(
                          month: _calendarMonth,
                          periodDates: _periodDates,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          isDark: dark,
                          onPrev: () => setState(() {
                            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
                          }),
                          onNext: () => setState(() {
                            _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);
                          }),
                        ),
                      ),
                    ),

                    // Stats
                    if (_stats.isNotEmpty) ...[
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _StatsCard(stats: _stats, textColor: textColor, mutedColor: mutedColor, isDark: dark),
                        ),
                      ),
                    ],

                    // History
                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _HistorySection(
                          logs: _logs,
                          textColor: textColor,
                          mutedColor: mutedColor,
                          isDark: dark,
                          onDelete: _deleteLog,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StatusCard extends StatefulWidget {
  final PeriodLog? activePeriod;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final VoidCallback onStart;
  final VoidCallback onEnd;
  final ValueChanged<int> onFlowLevel;
  final ValueChanged<String> onNotesChanged;

  const _StatusCard({
    required this.activePeriod,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onStart,
    required this.onEnd,
    required this.onFlowLevel,
    required this.onNotesChanged,
  });

  @override
  State<_StatusCard> createState() => _StatusCardState();
}

class _StatusCardState extends State<_StatusCard> {
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController(text: widget.activePeriod?.notes ?? '');
  }

  @override
  void didUpdateWidget(_StatusCard old) {
    super.didUpdateWidget(old);
    if (old.activePeriod?.id != widget.activePeriod?.id) {
      _notesCtrl.text = widget.activePeriod?.notes ?? '';
    }
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  int get _dayCount {
    final a = widget.activePeriod;
    if (a == null) return 0;
    return DateTime.now().difference(a.startDate).inDays + 1;
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.activePeriod != null;
    final bg = widget.isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: _pink.withOpacity(0.25)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _pink : widget.mutedColor.withOpacity(0.35),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isActive ? 'Period active · Day $_dayCount' : 'No active period',
                style: GoogleFonts.inter(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: isActive ? _pink : widget.mutedColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (isActive) ...[
            // Flow level
            Text('FLOW', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: widget.mutedColor, letterSpacing: 2)),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3].map((lvl) {
                final active = widget.activePeriod!.flowLevel == lvl;
                final labels = ['Light', 'Medium', 'Heavy'];
                return GestureDetector(
                  onTap: () => widget.onFlowLevel(lvl),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _pink.withOpacity(0.15) : (widget.isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)),
                      borderRadius: BorderRadius.circular(20),
                      border: active ? Border.all(color: _pink.withOpacity(0.4)) : null,
                    ),
                    child: Text(labels[lvl - 1], style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w500,
                      color: active ? _pink : widget.mutedColor,
                    )),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              onChanged: widget.onNotesChanged,
              style: GoogleFonts.inter(fontSize: 14, color: widget.textColor, height: 1.5),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Symptoms, notes, how you\'re feeling...',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: widget.mutedColor, fontStyle: FontStyle.italic),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: widget.onEnd,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _pink.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _pink.withOpacity(0.25)),
                  ),
                  child: Text('End Period', textAlign: TextAlign.center, style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _pink,
                  )),
                ),
              ),
            ),
          ] else ...[
            Text(
              'Track your cycle, symptoms, and flow.\nEverything stays on your device.',
              style: GoogleFonts.inter(fontSize: 13, color: widget.mutedColor, height: 1.5),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: widget.onStart,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _pink.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _pink.withOpacity(0.25)),
                  ),
                  child: Text('Start Period', textAlign: TextAlign.center, style: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600, color: _pink,
                  )),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MONTH CALENDAR
// ─────────────────────────────────────────────────────────────────────────────

class _MonthCalendar extends StatelessWidget {
  final DateTime month;
  final Set<DateTime> periodDates;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthCalendar({
    required this.month,
    required this.periodDates,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    // Sunday-first: Dart weekday 1=Mon…7=Sun, so Sunday needs offset 0
    final startOffset = firstDay.weekday % 7;
    final today = DateTime.now();
    final bg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(onTap: onPrev, child: Icon(Icons.chevron_left_rounded, color: mutedColor, size: 22)),
              Text(DateFormat('MMMM yyyy').format(month), style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              GestureDetector(onTap: onNext, child: Icon(Icons.chevron_right_rounded, color: mutedColor, size: 22)),
            ],
          ),
          const SizedBox(height: 12),

          // Day labels
          Row(
            children: ['S','M','T','W','T','F','S'].map((d) =>
              Expanded(child: Text(d, textAlign: TextAlign.center, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: mutedColor))),
            ).toList(),
          ),
          const SizedBox(height: 8),

          // Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1),
            itemCount: startOffset + lastDay.day,
            itemBuilder: (_, idx) {
              if (idx < startOffset) return const SizedBox();
              final day = idx - startOffset + 1;
              final date = DateTime(month.year, month.month, day);
              final isPeriod = periodDates.contains(date);
              final isToday = date.year == today.year && date.month == today.month && date.day == today.day;

              return Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isPeriod ? _pink.withOpacity(0.18) : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday ? Border.all(color: AppColors.aqua, width: 1.5) : null,
                ),
                child: Center(
                  child: Text('$day', style: GoogleFonts.inter(
                    fontSize: 12,
                    color: isPeriod ? _pink : textColor.withOpacity(0.75),
                    fontWeight: isPeriod ? FontWeight.w600 : FontWeight.w400,
                  )),
                ),
              );
            },
          ),

          // Legend
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: _pink.withOpacity(0.35), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Period days', style: GoogleFonts.inter(fontSize: 10, color: mutedColor)),
              const SizedBox(width: 16),
              Container(width: 8, height: 8, decoration: BoxDecoration(border: Border.all(color: AppColors.aqua, width: 1.5), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('Today', style: GoogleFonts.inter(fontSize: 10, color: mutedColor)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS CARD
// ─────────────────────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final Map<String, dynamic> stats;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;

  const _StatsCard({required this.stats, required this.textColor, required this.mutedColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final avgDuration = stats['avgDuration'] as int?;
    final avgCycle = stats['avgCycle'] as int?;
    final nextPredicted = stats['nextPredicted'] as DateTime?;
    final bg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('STATS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: mutedColor, letterSpacing: 2)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              if (avgDuration != null)
                _Stat(label: 'Avg duration', value: '$avgDuration days', textColor: textColor, mutedColor: mutedColor),
              if (avgCycle != null)
                _Stat(label: 'Avg cycle', value: '$avgCycle days', textColor: textColor, mutedColor: mutedColor),
            ],
          ),
          if (nextPredicted != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _pink.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: _pink),
                  const SizedBox(width: 6),
                  Text('Next predicted: ${DateFormat('MMM d').format(nextPredicted)}', style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500, color: _pink,
                  )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  const _Stat({required this.label, required this.value, required this.textColor, required this.mutedColor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
      Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SECTION
// ─────────────────────────────────────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  final List<PeriodLog> logs;
  final Color textColor;
  final Color mutedColor;
  final bool isDark;
  final ValueChanged<PeriodLog> onDelete;

  const _HistorySection({
    required this.logs,
    required this.textColor,
    required this.mutedColor,
    required this.isDark,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final completed = logs.where((p) => !p.isActive).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (completed.isEmpty) return const SizedBox.shrink();
    final bg = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('HISTORY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: mutedColor, letterSpacing: 2)),
        const SizedBox(height: 12),
        ...completed.map((log) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: _pink, shape: BoxShape.circle)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${DateFormat('MMM d').format(log.startDate)} – ${log.endDate != null ? DateFormat('MMM d').format(log.endDate!) : 'ongoing'}',
                      style: GoogleFonts.inter(fontSize: 13, color: textColor, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '${log.durationDays != null ? '${log.durationDays} days · ' : ''}${['Light', 'Medium', 'Heavy'][log.flowLevel - 1]}${log.notes.isNotEmpty ? ' · ${log.notes.split('\n').first}' : ''}',
                      style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => onDelete(log),
                child: Icon(Icons.close_rounded, size: 16, color: mutedColor.withOpacity(0.4)),
              ),
            ],
          ),
        )),
      ],
    );
  }
}