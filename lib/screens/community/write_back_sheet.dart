import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/editor_block.dart';
import '../../models/entry.dart';
import '../../models/published_entry.dart';
import '../../models/reflection.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import '../editor/editor_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WRITE BACK SHEET
// Entry point for creating a Write Back. Both options open EditorScreen
// with a pinned ReflectionHeaderBlock as the first block.
// ─────────────────────────────────────────────────────────────────────────────

class WriteBackSheet extends StatelessWidget {
  final PublishedEntry entry;
  final Reflection? inspirationReflection;

  const WriteBackSheet({
    super.key,
    required this.entry,
    this.inspirationReflection,
  });

  static Future<void> show(
    BuildContext context, {
    required PublishedEntry entry,
    Reflection? inspirationReflection,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WriteBackSheet(
        entry: entry,
        inspirationReflection: inspirationReflection,
      ),
    );
  }

  Future<void> _openInEditor(BuildContext context,
      {required bool isPrivate}) async {
    final appState = context.read<AppState>();

    Navigator.pop(context); // close sheet

    if (appState.activeStory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Create a story first — your reflection will be saved there.')),
      );
      return;
    }

    final headerBlock = ReflectionHeaderBlock(
      id: const Uuid().v4(),
      originEntryId: entry.id,
      originTitle: entry.title,
      originAuthor: entry.authorLabel,
      originAuthorId: entry.userId,
      originExcerpt: entry.preview(160),
      originHeaderImage: entry.headerImage,
      inspirationId: inspirationReflection?.id,
      inspirationAuthor: inspirationReflection?.authorLabel,
      inspirationTitle: inspirationReflection?.title,
    );

    // Create a real entry in the active story so it's saved locally.
    // moodColor tracks reflection state: 'reflection_private' or 'reflection' (published).
    final newEntry = await appState.createEntry();
    final entryWithHeader = newEntry.copyWith(
      blocksJson: serializeBlocks([headerBlock, TextBlock.empty()]),
      moodColor: isPrivate ? 'reflection_private' : 'reflection_draft',
    );
    await appState.saveEntry(entryWithHeader);

    if (!context.mounted) return;
    await Navigator.of(context).push<Entry>(
      MaterialPageRoute(builder: (_) => EditorScreen(entry: entryWithHeader)),
    );
    if (context.mounted) appState.refreshEntries();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final bottomPad =
        MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: mutedColor.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Text('Write Back',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
              const SizedBox(height: 4),
              Text('How would you like to respond?',
                  style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),
              const SizedBox(height: 16),
              _SmallOriginCard(
                  entry: entry, dark: dark, textColor: textColor, mutedColor: mutedColor),
              const SizedBox(height: 20),
              _OptionCard(
                icon: Icons.lock_outline_rounded,
                title: 'Private Journal',
                subtitle:
                    'Saved to your story entries. The author of the original entry can '
                    'still read and appreciate/respond to it, but no one else can — '
                    'and they cannot edit or delete it.',
                accentColor: AppColors.teal,
                dark: dark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () => _openInEditor(context, isPrivate: true),
              ),
              const SizedBox(height: 10),
              _OptionCard(
                icon: Icons.public_rounded,
                title: 'Publish to Sanctuary',
                subtitle:
                    'Share as a public reflection. Write it first, then submit from the editor.',
                accentColor: AppColors.aqua,
                dark: dark,
                textColor: textColor,
                mutedColor: mutedColor,
                onTap: () => _openInEditor(context, isPrivate: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Option card ────────────────────────────────────────────────────────────────

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final bool dark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withOpacity(0.25), width: 1.5),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: GoogleFonts.inter(fontSize: 12, color: mutedColor, height: 1.4)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: accentColor.withOpacity(0.5)),
        ]),
      ),
    );
  }
}

// ── Small origin preview card ──────────────────────────────────────────────────

class _SmallOriginCard extends StatelessWidget {
  final PublishedEntry entry;
  final bool dark;
  final Color textColor;
  final Color mutedColor;

  const _SmallOriginCard({
    required this.entry,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = entry.headerImage != null &&
        entry.headerImage!.isNotEmpty &&
        File(entry.headerImage!).existsSync();
    final bg =
        dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.07),
        ),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: hasImage
                ? Image.file(File(entry.headerImage!), fit: BoxFit.cover)
                : Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF0D1A28), Color(0xFF1A3045)]),
                    ),
                    child: const Icon(Icons.auto_stories_outlined,
                        color: Colors.white30, size: 20),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              entry.title.isEmpty ? 'Untitled' : entry.title,
              style: GoogleFonts.crimsonPro(
                  fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text('by ${entry.authorLabel}',
                style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
            const SizedBox(height: 3),
            Text('"${entry.preview(70)}"',
                style: GoogleFonts.crimsonPro(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: mutedColor,
                    height: 1.4),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}