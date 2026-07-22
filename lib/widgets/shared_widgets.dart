import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'neumorphic_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// INLINE IMAGE WIDGET
// Full-width, edge-to-edge image with rounded corners.
// Used in Entry Read-Only and Editor body for inline images.
// ─────────────────────────────────────────────────────────────────────────────

class InlineImageWidget extends StatelessWidget {
  final String path;
  final BorderRadius? borderRadius;
  final double? height;

  const InlineImageWidget({
    super.key,
    required this.path,
    this.borderRadius,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    final radius = borderRadius ?? BorderRadius.circular(12);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ClipRRect(
        borderRadius: radius,
        child: file.existsSync()
            ? Image.file(
                file,
                width: double.infinity,
                height: height,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _brokenImagePlaceholder(context),
              )
            : _brokenImagePlaceholder(context),
      ),
    );
  }

  Widget _brokenImagePlaceholder(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    return Container(
      height: 120,
      color: AppColors.neuDark(dark).withOpacity(0.1),
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.mutedLight,
          size: 32,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORY CREATE DIALOG
// Modal dialog for creating a new story.
// Title required, description optional.
// ─────────────────────────────────────────────────────────────────────────────

class StoryCreateDialog extends StatefulWidget {
  const StoryCreateDialog({super.key});

  /// Show the dialog and return the created story title + description.
  /// Returns null if user cancels.
  static Future<({String title, String description})?> show(
    BuildContext context,
  ) {
    return showDialog<({String title, String description})>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const StoryCreateDialog(),
    );
  }

  @override
  State<StoryCreateDialog> createState() => _StoryCreateDialogState();
}

class _StoryCreateDialogState extends State<StoryCreateDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() {
      final ok = _titleController.text.trim().isNotEmpty;
      if (ok != _canSubmit) setState(() => _canSubmit = ok);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop((
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New Story', style: AppTypography.panelHeader(textColor)),
            const SizedBox(height: 20),
            NeumorphicInput(
              controller: _titleController,
              hintText: 'Story title...',
              autofocus: true,
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 12),
            NeumorphicInput(
              controller: _descController,
              hintText: 'Description (optional)',
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: AppTypography.buttonLabel(mutedColor)),
                ),
                const SizedBox(width: 8),
                NeumorphicButton(
                  onTap: _canSubmit ? _submit : null,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  child: Text(
                    'Create',
                    style: AppTypography.buttonLabel(
                      _canSubmit ? AppColors.aqua : mutedColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARKDOWN BODY CUSTOM
// MarkdownBody pre-configured with Flow's Crimson Pro stylesheet.
// Used in Entry Read-Only mode for full markdown rendering.
// ─────────────────────────────────────────────────────────────────────────────

class FlowMarkdownBody extends StatelessWidget {
  final String data;
  final bool selectable;

  const FlowMarkdownBody({
    super.key,
    required this.data,
    this.selectable = true,
  });

  /// Converts bare https?:// URLs in plain text to markdown link syntax
  /// so flutter_markdown renders them as tappable links.
  static String _autoLinkify(String raw) {
    return raw.replaceAllMapped(
      // Match URLs not already inside markdown link parens [text](URL)
      RegExp(r'(?<!\()(?<!\[)(https?://[^\s\)\]<>"]+)', caseSensitive: false),
      (m) {
        final url = m.group(0)!;
        return '[$url]($url)';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final codeBg = dark ? AppColors.codeBgDark : AppColors.codeBgLight;

    return MarkdownBody(
      data: _autoLinkify(data),
      selectable: selectable,
      onTapLink: (text, href, title) {
        if (href != null) {
          launchUrl(Uri.parse(href), mode: LaunchMode.externalApplication);
        }
      },
      styleSheet: MarkdownStyleSheet(
        // Paragraph
        p: GoogleFonts.crimsonPro(
          fontSize: 18,
          color: textColor,
          height: 1.8,
        ),
        // Headings
        h1: GoogleFonts.crimsonPro(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.2,
        ),
        h2: GoogleFonts.crimsonPro(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.25,
        ),
        h3: GoogleFonts.crimsonPro(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.3,
        ),
        h4: GoogleFonts.crimsonPro(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        // Bold / Italic
        strong: GoogleFonts.crimsonPro(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
        em: GoogleFonts.crimsonPro(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: textColor,
        ),
        // Blockquote
        blockquote: GoogleFonts.crimsonPro(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: mutedColor,
          height: 1.8,
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppColors.blockquoteBg,
          border: Border(
            left: BorderSide(
              color: AppColors.blockquoteBorder,
              width: 4,
            ),
          ),
        ),
        blockquotePadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        // Code
        code: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: textColor,
          backgroundColor: codeBg,
        ),
        codeblockDecoration: BoxDecoration(
          color: codeBg,
          borderRadius: BorderRadius.circular(8),
        ),
        codeblockPadding: const EdgeInsets.all(16),
        // Links
        a: GoogleFonts.crimsonPro(
          fontSize: 18,
          color: AppColors.linkColor,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.linkColor,
        ),
        // Lists
        listBullet: GoogleFonts.crimsonPro(
          fontSize: 18,
          color: mutedColor,
        ),
        listIndent: 24,
        // Horizontal rule
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
          ),
        ),
        // Table
        tableHead: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        tableBody: GoogleFonts.inter(
          fontSize: 13,
          color: textColor,
        ),
        tableBorder: TableBorder.all(
          color: dark ? AppColors.dividerDark : AppColors.dividerLight,
          width: 0.5,
        ),
      ),
    );
  }
}
