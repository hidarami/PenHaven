import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/published_entry.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'community_entry_viewer.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC PROFILE MODAL
// Read-only view of another user's public profile. Shows their display name,
// recent publications, and public stats. No edit controls whatsoever.
// Triggered by tapping an author name/avatar anywhere in the community.
// ─────────────────────────────────────────────────────────────────────────────

class PublicProfileModal extends StatefulWidget {
  final String userId;
  final String displayName;

  const PublicProfileModal({
    super.key,
    required this.userId,
    required this.displayName,
  });

  static Future<void> show(
    BuildContext context, {
    required String userId,
    required String displayName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PublicProfileModal(
        userId: userId,
        displayName: displayName,
      ),
    );
  }

  @override
  State<PublicProfileModal> createState() => _PublicProfileModalState();
}

class _PublicProfileModalState extends State<PublicProfileModal> {
  List<PublishedEntry> _entries = [];
  bool _loading = true;
  int _totalClaps = 0;
  int _totalComments = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await SupabaseService.instance
        .getPublicEntriesByUser(widget.userId, limit: 12);
    if (mounted) {
      setState(() {
        _entries = entries;
        _totalClaps = entries.fold(0, (sum, e) => sum + e.clapCount);
        _totalComments = entries.fold(0, (sum, e) => sum + e.commentCount);
        _loading = false;
      });
    }
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7BA591), Color(0xFF5B8DB8), Color(0xFFD4820A),
      Color(0xFF9472D4), Color(0xFFE87FA0), Color(0xFFD44A28),
      Color(0xFF5A8A5C), Color(0xFF1B9B8D),
    ];
    final hash = name.codeUnits.fold(0, (a, b) => a + b);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final accentColor = context.watch<AtmosphereState>().accentColor;
    final avatarColor = _avatarColor(widget.displayName);
    final initial = widget.displayName.isNotEmpty
        ? widget.displayName[0].toUpperCase()
        : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Drag handle ─────────────────────────────────────────────
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
            const SizedBox(height: 20),

            // ── Avatar + name ────────────────────────────────────────────
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: dark ? AppColors.warmDark : Colors.white,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.crimsonPro(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.displayName,
              style: GoogleFonts.crimsonPro(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@${widget.displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '')}',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: accentColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 18),

            // ── Stats ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                      child: _StatCol(
                          count: _entries.length,
                          label: 'Publications',
                          textColor: textColor,
                          mutedColor: mutedColor)),
                  Container(width: 0.5, height: 36, color: divColor),
                  Expanded(
                      child: _StatCol(
                          count: _totalClaps,
                          label: 'Appreciations',
                          textColor: textColor,
                          mutedColor: mutedColor)),
                  Container(width: 0.5, height: 36, color: divColor),
                  Expanded(
                      child: _StatCol(
                          count: _totalComments,
                          label: 'Responses',
                          textColor: textColor,
                          mutedColor: mutedColor)),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Divider(color: divColor, thickness: 0.5, indent: 24, endIndent: 24),

            // ── Publications label ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recent Publications',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
            ),

            // ── Entry list ───────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _entries.isEmpty
                      ? Center(
                          child: Text(
                            'Nothing published yet.',
                            style: GoogleFonts.crimsonPro(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: mutedColor,
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: sc,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) => Divider(
                              color: divColor.withOpacity(0.5), height: 1),
                          itemBuilder: (ctx, i) => _PublicEntryTile(
                            entry: _entries[i],
                            isDark: dark,
                            textColor: textColor,
                            mutedColor: mutedColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      CommunityEntryViewer(entry: _entries[i])),
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

// ── Stat column ───────────────────────────────────────────────────────────────

class _StatCol extends StatelessWidget {
  final int count;
  final String label;
  final Color textColor;
  final Color mutedColor;
  const _StatCol(
      {required this.count,
      required this.label,
      required this.textColor,
      required this.mutedColor});

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text('$count',
              style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(fontSize: 11, color: mutedColor),
              textAlign: TextAlign.center),
        ],
      );
}

// ── Single public entry tile ──────────────────────────────────────────────────

class _PublicEntryTile extends StatelessWidget {
  final PublishedEntry entry;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _PublicEntryTile({
    required this.entry,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  String _relDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dt);
  }

  String _readTime(String content) {
    if (content.isEmpty) return '1 min read';
    final words = content.trim().split(RegExp(r'\s+')).length;
    return '${(words / 200).ceil().clamp(1, 99)} min read';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(File(entry.headerImage!),
                    width: 58, height: 58, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (entry.category != null && entry.category!.isNotEmpty)
                    Text(
                      entry.category!.toUpperCase(),
                      style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.aqua,
                          letterSpacing: 0.8),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    entry.title.isEmpty ? 'Untitled' : entry.title,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${_readTime(entry.content)}  ·  ${_relDate(entry.createdAt)}',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: mutedColor.withOpacity(0.7)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                Icon(Icons.favorite_border_rounded,
                    size: 13, color: mutedColor.withOpacity(0.5)),
                Text('${entry.clapCount}',
                    style:
                        GoogleFonts.inter(fontSize: 10, color: mutedColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}