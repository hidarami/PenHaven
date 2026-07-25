import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/published_entry.dart';
import '../../models/reflection.dart';
import '../../providers/app_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../providers/community_state.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REFLECTION EDITOR SCREEN
// Full-screen editor for publishing a Write Back as a public Reflection.
// Shows "Reflection on" context card at top.
// Requires 150+ words to publish. Shorter can be saved as private.
// ─────────────────────────────────────────────────────────────────────────────

class ReflectionEditorScreen extends StatefulWidget {
  final PublishedEntry originEntry;
  final Reflection? inspirationReflection;

  const ReflectionEditorScreen({
    super.key,
    required this.originEntry,
    this.inspirationReflection,
  });

  @override
  State<ReflectionEditorScreen> createState() => _ReflectionEditorScreenState();
}

class _ReflectionEditorScreenState extends State<ReflectionEditorScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isAnon = false;
  bool _saving = false;
  int _wordCount = 0;
  String? _selectedCategory;

  static const int _minWords = 150;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    // Pre-populate anon setting from prefs
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isAnon = prefs.getBool('reflectionDefaultAnon') ?? false);
    }
  }

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

  bool get _canPublish => _wordCount >= _minWords;

  Future<void> _publish() async {
    if (!_canPublish || _saving) return;
    if (!SupabaseService.instance.isAuthenticated) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Sign in to publish.')));
      return;
    }
    setState(() => _saving = true);
    final communityState = context.read<CommunityState>();
    final email = SupabaseService.instance.userEmail;
    final displayName = _isAnon
        ? null
        : (communityState.profileDisplayName ?? email?.split('@').first);

    final reflection = Reflection(
      originEntryId: widget.inspirationReflection?.originEntryId ??
          widget.originEntry.id,
      inspirationId: widget.inspirationReflection?.id,
      userId: SupabaseService.instance.userId ?? '',
      title: _titleCtrl.text.trim(),
      content: _bodyCtrl.text.trim(),
      isPrivate: false,
      isAnonymous: _isAnon,
      displayName: displayName,
      category: _selectedCategory,
      originTitle: widget.originEntry.title,
      originAuthor: widget.originEntry.authorLabel,
      originExcerpt: widget.originEntry.preview(160),
      originHeaderImage: widget.originEntry.headerImage,
      inspirationAuthor: widget.inspirationReflection?.authorLabel,
      inspirationTitle: widget.inspirationReflection?.title,
    );

    final ok = await communityState.submitWriteBack(reflection);
    if (mounted) {
      setState(() => _saving = false);
      if (ok) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reflection published to Sanctuary ✓')),
        );
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Failed to publish.')));
      }
    }
  }

  Future<void> _savePrivate() async {
    if (_saving) return;
    setState(() => _saving = true);
    final communityState = context.read<CommunityState>();
    final email = SupabaseService.instance.userEmail;
    final displayName = _isAnon
        ? null
        : (communityState.profileDisplayName ?? email?.split('@').first);

    final reflection = Reflection(
      originEntryId: widget.inspirationReflection?.originEntryId ??
          widget.originEntry.id,
      inspirationId: widget.inspirationReflection?.id,
      userId: SupabaseService.instance.userId ?? '',
      title: _titleCtrl.text.trim(),
      content: _bodyCtrl.text.trim(),
      isPrivate: true,
      isAnonymous: _isAnon,
      displayName: displayName,
      originTitle: widget.originEntry.title,
      originAuthor: widget.originEntry.authorLabel,
      originExcerpt: widget.originEntry.preview(160),
      originHeaderImage: widget.originEntry.headerImage,
    );
    final ok = await communityState.submitWriteBack(reflection);
    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Saved privately to Write Backs.' : 'Failed to save.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = context.watch<AtmosphereState>().backgroundFor(dark);
    final textColor = AppColors.readableText(bg);
    final mutedColor = AppColors.readableMuted(bg);
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Top bar ──────────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(8, topPad + 4, 8, 4),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 24, color: mutedColor),
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                // Word count
                Text(
                  '$_wordCount / $_minWords words',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _canPublish ? AppColors.teal : mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 12),
                // Save private (always)
                if (_wordCount > 0 && !_canPublish)
                  GestureDetector(
                    onTap: _savePrivate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.teal.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.teal.withOpacity(0.3)),
                      ),
                      child: Text('Save Private',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.teal)),
                    ),
                  ),
                const SizedBox(width: 8),
                // Publish button
                GestureDetector(
                  onTap: _canPublish && !_saving ? _publish : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _canPublish
                          ? AppColors.aqua.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _canPublish
                              ? AppColors.aqua.withOpacity(0.4)
                              : Colors.grey.withOpacity(0.2)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 1.5, color: AppColors.aqua))
                        : Text('Publish',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _canPublish ? AppColors.aqua : mutedColor)),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 8, 24, botPad + 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Reflection on card ────────────────────────────────
                  ReflectionOnCard(
                    originEntry: widget.originEntry,
                    inspirationReflection: widget.inspirationReflection,
                    dark: dark,
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),

                  const SizedBox(height: 24),

                  // ── Word limit notice ─────────────────────────────────
                  if (!_canPublish)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.aqua.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.aqua.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded,
                            size: 14, color: AppColors.aqua.withOpacity(0.7)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Published Reflections need 150+ words. '
                            'Shorter pieces can be saved privately.',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.aqua.withOpacity(0.85),
                                height: 1.4),
                          ),
                        ),
                      ]),
                    ),

                  // ── Title ────────────────────────────────────────────
                  TextField(
                    controller: _titleCtrl,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.2),
                    maxLines: null,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Reflection title...',
                      hintStyle: GoogleFonts.crimsonPro(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: mutedColor.withOpacity(0.45),
                          height: 1.2),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ── Body ─────────────────────────────────────────────
                  TextField(
                    controller: _bodyCtrl,
                    onChanged: _onBodyChanged,
                    style: GoogleFonts.crimsonPro(
                        fontSize: 18, color: textColor, height: 1.7),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Write your reflection...',
                      hintStyle: GoogleFonts.crimsonPro(
                          fontSize: 18,
                          color: mutedColor.withOpacity(0.45),
                          fontStyle: FontStyle.italic,
                          height: 1.7),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Anonymous toggle ─────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _isAnon = !_isAnon),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(5),
                          color: _isAnon ? AppColors.aqua : Colors.transparent,
                          border: Border.all(
                              color: _isAnon
                                  ? AppColors.aqua
                                  : mutedColor.withOpacity(0.5),
                              width: 1.5),
                        ),
                        child: _isAnon
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Publish anonymously',
                          style: GoogleFonts.inter(
                              fontSize: 13, color: mutedColor)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REFLECTION ON CARD
// Shared widget — used in editor and viewer.
// Shows the origin entry preview above the reflection content.
// ─────────────────────────────────────────────────────────────────────────────

class ReflectionOnCard extends StatelessWidget {
  final PublishedEntry originEntry;
  final Reflection? inspirationReflection;
  final bool dark;
  final Color textColor;
  final Color mutedColor;
  final VoidCallback? onTapOrigin;

  const ReflectionOnCard({
    super.key,
    required this.originEntry,
    this.inspirationReflection,
    required this.dark,
    required this.textColor,
    required this.mutedColor,
    this.onTapOrigin,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = originEntry.headerImage != null &&
        originEntry.headerImage!.isNotEmpty &&
        File(originEntry.headerImage!).existsSync();
    final cardBg = dark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final borderColor = dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.07);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Reflection on" label
        Text(
          'Reflection on',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: mutedColor,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        // Origin card
        GestureDetector(
          onTap: onTapOrigin,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 60, height: 60,
                    child: hasImage
                        ? Image.file(File(originEntry.headerImage!),
                            fit: BoxFit.cover)
                        : Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0D1A28), Color(0xFF1A3045)],
                              ),
                            ),
                            child: const Icon(Icons.auto_stories_outlined,
                                color: Colors.white30, size: 22),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        originEntry.title.isEmpty
                            ? 'Untitled'
                            : originEntry.title,
                        style: GoogleFonts.crimsonPro(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: textColor,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text('by ${originEntry.authorLabel}',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: mutedColor)),
                      const SizedBox(height: 5),
                      Text(
                        '"${originEntry.preview(80)}"',
                        style: GoogleFonts.crimsonPro(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: mutedColor,
                            height: 1.45),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTapOrigin != null)
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: mutedColor.withOpacity(0.5)),
              ],
            ),
          ),
        ),
        // Inspiration breadcrumb
        if (inspirationReflection != null) ...[
          const SizedBox(height: 8),
          Text(
            'Inspired by ${inspirationReflection!.authorLabel}\'s reflection',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.aqua,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
}