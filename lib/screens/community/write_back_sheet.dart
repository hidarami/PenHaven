import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/published_entry.dart';
import '../../models/reflection.dart';
import '../../providers/app_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import 'reflection_editor_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WRITE BACK SHEET
// Entry point for creating a Write Back (private journal or public Reflection).
// Shows two options; private compose stays in sheet, publish navigates out.
// ─────────────────────────────────────────────────────────────────────────────

class WriteBackSheet extends StatefulWidget {
  final PublishedEntry entry;               // the entry being written back to
  final Reflection? inspirationReflection; // if writing from a reflection

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

  @override
  State<WriteBackSheet> createState() => _WriteBackSheetState();
}

enum _Mode { options, privateCompose }

class _WriteBackSheetState extends State<WriteBackSheet> {
  _Mode _mode = _Mode.options;
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isAnon = false;
  bool _saving = false;
  int _wordCount = 0;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _onBodyChanged(String v) {
    final wc = v.trim().isEmpty
        ? 0
        : v.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
    setState(() => _wordCount = wc);
  }

  Future<void> _savePrivate() async {
    if (_saving) return;
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to save.')));
      return;
    }
    setState(() => _saving = true);
    final communityState = context.read<CommunityState>();
    final email = SupabaseService.instance.userEmail;
    final displayName = _isAnon
        ? null
        : (communityState.profileDisplayName ?? email?.split('@').first);

    final reflection = Reflection(
      originEntryId: widget.inspirationReflection?.originEntryId ?? widget.entry.id,
      inspirationId: widget.inspirationReflection?.id,
      userId: SupabaseService.instance.userId ?? '',
      title: _titleCtrl.text.trim(),
      content: _bodyCtrl.text.trim(),
      isPrivate: true,
      isAnonymous: _isAnon,
      displayName: displayName,
      originTitle: widget.entry.title,
      originAuthor: widget.entry.authorLabel,
      originExcerpt: widget.entry.preview(120),
      originHeaderImage: widget.entry.headerImage,
      inspirationAuthor: widget.inspirationReflection?.authorLabel,
      inspirationTitle: widget.inspirationReflection?.title,
    );

    final ok = await communityState.submitWriteBack(reflection);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Saved to your Write Backs.' : 'Failed to save.'),
      ));
    }
  }

  void _goPublish() {
    Navigator.pop(context);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReflectionEditorScreen(
        originEntry: widget.entry,
        inspirationReflection: widget.inspirationReflection,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom +
        MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SafeArea(
        top: false,
        child: _mode == _Mode.options
            ? _buildOptions(textColor, mutedColor, divColor)
            : _buildPrivateCompose(textColor, mutedColor, divColor),
      ),
    );
  }

  Widget _buildOptions(Color textColor, Color mutedColor, Color divColor) {
    final dark = context.watch<AppState>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: mutedColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('Write Back',
              style: GoogleFonts.crimsonPro(
                  fontSize: 24, fontWeight: FontWeight.w700, color: textColor)),
          const SizedBox(height: 4),
          Text('How would you like to respond?',
              style: GoogleFonts.inter(fontSize: 13, color: mutedColor)),

          const SizedBox(height: 16),

          // Origin preview
          _SmallOriginCard(entry: widget.entry, dark: dark, textColor: textColor, mutedColor: mutedColor),

          const SizedBox(height: 20),

          // Private option
          _OptionCard(
            icon: Icons.lock_outline_rounded,
            title: 'Private Journal',
            subtitle: 'Only you can read this. A personal reflection saved to your Write Backs.',
            accentColor: AppColors.teal,
            dark: dark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: () => setState(() => _mode = _Mode.privateCompose),
          ),
          const SizedBox(height: 10),

          // Public option
          _OptionCard(
            icon: Icons.public_rounded,
            title: 'Publish to Sanctuary',
            subtitle: 'Share as a public Reflection. Requires 150+ words. The original author and community can read it.',
            accentColor: AppColors.aqua,
            dark: dark,
            textColor: textColor,
            mutedColor: mutedColor,
            onTap: _goPublish,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateCompose(Color textColor, Color mutedColor, Color divColor) {
    final dark = context.watch<AppState>().isDarkMode;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: mutedColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          const SizedBox(height: 14),
          Row(children: [
            GestureDetector(
              onTap: () => setState(() => _mode = _Mode.options),
              child: Icon(Icons.chevron_left_rounded, size: 24, color: mutedColor),
            ),
            const SizedBox(width: 4),
            Text('Private Write Back',
                style: GoogleFonts.crimsonPro(
                    fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
          ]),
          const SizedBox(height: 12),
          // Title
          Container(
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _titleCtrl,
              style: GoogleFonts.crimsonPro(fontSize: 17, color: textColor),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                hintText: 'Title (optional)',
                hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Body
          Container(
            height: 160,
            decoration: BoxDecoration(
              color: dark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _bodyCtrl,
              maxLines: null,
              expands: true,
              onChanged: _onBodyChanged,
              style: GoogleFonts.crimsonPro(fontSize: 16, color: textColor, height: 1.6),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
                hintText: 'Write what this made you feel or think...',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14, color: mutedColor, fontStyle: FontStyle.italic),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Text('$_wordCount words',
                style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
            const Spacer(),
            GestureDetector(
              onTap: () => setState(() => _isAnon = !_isAnon),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _isAnon ? AppColors.aqua : Colors.transparent,
                    border: Border.all(
                        color: _isAnon ? AppColors.aqua : mutedColor.withOpacity(0.5),
                        width: 1.5),
                  ),
                  child: _isAnon
                      ? const Icon(Icons.check, size: 11, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 6),
                Text('Anonymous', style: GoogleFonts.inter(fontSize: 12, color: mutedColor)),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _bodyCtrl.text.trim().isEmpty || _saving ? null : _savePrivate,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.teal.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.teal.withOpacity(0.4)),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: AppColors.teal))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 15, color: AppColors.teal),
                          const SizedBox(width: 6),
                          Text('Save Privately',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.teal)),
                        ]),
                ),
              ),
            ),
          ),
        ],
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
        child: Row(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: mutedColor, height: 1.4)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: accentColor.withOpacity(0.5)),
          ],
        ),
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
    final bg = dark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 52, height: 52,
              child: hasImage
                  ? Image.file(File(entry.headerImage!), fit: BoxFit.cover)
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0D1A28), Color(0xFF1A3045)],
                        ),
                      ),
                      child: const Icon(Icons.auto_stories_outlined,
                          color: Colors.white30, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}