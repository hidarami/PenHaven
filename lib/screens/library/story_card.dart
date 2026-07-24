import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/entry_dao.dart';
import '../../models/story.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../story_cover.dart';

class StoryCard extends StatelessWidget {
  final Story story;
  final bool isActive;

  const StoryCard({super.key, required this.story, this.isActive = false});

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final cardBg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final accent = context.watch<AtmosphereState>().accentColor;

    return GestureDetector(
      onTap: () => context.read<AppState>().selectStory(story),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: isActive
              ? Border.all(color: accent.withOpacity(0.4), width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: AppColors.neuDark(dark).withOpacity(0.55),
              offset: const Offset(3, 3),
              blurRadius: 8,
            ),
            BoxShadow(
              color: AppColors.neuLight(dark),
              offset: const Offset(-3, -3),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ────────────────────────────────────────────────
            StoryCoverWidget(
              storyTitle: story.title,
              imagePath: story.coverImage,
              width: 110,
              height: 130,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            story.title,
                            style: GoogleFonts.crimsonPro(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showOptions(context),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, top: 2),
                            child: Icon(Icons.more_horiz,
                                size: 18, color: mutedColor.withOpacity(0.5)),
                          ),
                        ),
                      ],
                    ),

                    if (story.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        story.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: mutedColor,
                          height: 1.45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    FutureBuilder<int>(
                      future: EntryDao.instance.countByStory(story.id),
                      builder: (context, snapshot) {
                        final count = snapshot.data ?? 0;
                        return Text(
                          '$count ${count == 1 ? "entry" : "entries"}  ·  Last edited ${_relativeTime(story.updatedAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: mutedColor.withOpacity(0.7),
                          ),
                        );
                      },
                    ),

                    if (story.isLocked) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.lock_outline,
                            size: 11, color: mutedColor.withOpacity(0.5)),
                        const SizedBox(width: 4),
                        Text('Locked',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                color: mutedColor.withOpacity(0.5))),
                      ]),
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

  void _showOptions(BuildContext context) {
    final appState = context.read<AppState>();
    final dark = appState.isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                    color: mutedColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: mutedColor),
              title: Text('Rename',
                  style: GoogleFonts.inter(fontSize: 15, color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                _showRenameDialog(context, appState);
              },
            ),
            ListTile(
              leading: Icon(Icons.image_outlined, color: mutedColor),
              title: Text('Change Cover',
                  style: GoogleFonts.inter(fontSize: 15, color: textColor)),
              subtitle: Text(
                story.coverImage != null
                    ? 'Tap to change or remove'
                    : 'Add a cover image',
                style: GoogleFonts.inter(fontSize: 12, color: mutedColor),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickCover(context, appState);
              },
            ),
            ListTile(
              leading: Icon(
                story.isLocked
                    ? Icons.lock_open_outlined
                    : Icons.lock_outline,
                color: mutedColor,
              ),
              title: Text(story.isLocked ? 'Unlock Story' : 'Lock Story',
                  style: GoogleFonts.inter(fontSize: 15, color: textColor)),
              onTap: () {
                Navigator.pop(ctx);
                appState.updateStory(
                    story.copyWith(isLocked: !story.isLocked));
              },
            ),
            ListTile(
              leading: Icon(
                story.themeLock == 'dark'
                    ? Icons.dark_mode
                    : story.themeLock == 'light'
                        ? Icons.light_mode
                        : Icons.brightness_auto,
                color: mutedColor,
              ),
              title: Text(
                story.themeLock == 'dark'
                    ? 'Theme: Always Dark'
                    : story.themeLock == 'light'
                        ? 'Theme: Always Light'
                        : 'Theme: Follow System',
                style: GoogleFonts.inter(fontSize: 15, color: textColor),
              ),
              subtitle: Text('Tap to cycle',
                  style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
              onTap: () {
                Navigator.pop(ctx);
                final next = story.themeLock == null
                    ? 'dark'
                    : story.themeLock == 'dark'
                        ? 'light'
                        : null;
                appState.updateStory(next == null
                    ? story.copyWith(clearThemeLock: true)
                    : story.copyWith(themeLock: next));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppColors.danger),
              title: Text('Delete Story',
                  style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, appState);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCover(BuildContext context, AppState appState) async {
    final dark = appState.isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);

    if (story.coverImage != null) {
      final choice = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: bg,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.edit_outlined, color: mutedColor),
                title: Text('Change Cover',
                    style: GoogleFonts.inter(color: textColor)),
                onTap: () => Navigator.pop(_, 'change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
                title: Text('Remove Cover',
                    style:
                        GoogleFonts.inter(color: AppColors.danger)),
                onTap: () => Navigator.pop(_, 'remove'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (choice == 'remove') {
        appState.updateStory(story.copyWith(clearCoverImage: true));
        return;
      }
      if (choice != 'change') return;
    }

    if (!context.mounted) return;
    final ok = await PermissionService.instance.ensurePhotos(context);
    if (!ok || !context.mounted) return;
    final path = await ImageService.instance.pickAndSave(
      context: context,
      allowCrop: true,
      cropAspectRatioX: 3,
      cropAspectRatioY: 2,
    );
    if (path != null) appState.updateStory(story.copyWith(coverImage: path));
  }

  void _showRenameDialog(BuildContext context, AppState appState) {
    final titleCtrl = TextEditingController(text: story.title);
    final descCtrl = TextEditingController(text: story.description);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Story',
            style: GoogleFonts.crimsonPro(
                fontSize: 22, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Story title'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              decoration:
                  const InputDecoration(hintText: 'Description (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final t = titleCtrl.text.trim();
              if (t.isNotEmpty) {
                appState.updateStory(story.copyWith(
                  title: t,
                  description: descCtrl.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Story?'),
        content: const Text(
            'This will delete all entries in this story. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteStory(story.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}