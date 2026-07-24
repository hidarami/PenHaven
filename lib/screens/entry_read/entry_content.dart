import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import '../editor/editor_canvas.dart';
import '../../models/editor_block.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY CONTENT
// Renders the reading body of an entry:
//   - Title (Crimson Pro 36pt bold, justified)
//   - Date (Inter 14pt medium, formatted)
//   - Body: blocks (new) or markdown with interleaved images (legacy)
//
// CRITICAL per Master Specification §4:
//   - NO raw markdown visible — everything must be rendered
//   - Inline images appear at their character position, not all at bottom
//   - Text is selectable (system copy/paste menu)
// ─────────────────────────────────────────────────────────────────────────────

class EntryContent extends StatelessWidget {
  final Entry entry;
  final bool isDark;

  const EntryContent({super.key, required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 28),

          // ── Title ──────────────────────────────────────────────────────
          Text(
            entry.title.isEmpty ? 'Untitled' : entry.title,
            style: AppTypography.entryTitle(textColor),
            textAlign: TextAlign.left,
          ),

          const SizedBox(height: 10),

          // ── Date ───────────────────────────────────────────────────────
          Text(
            DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(entry.createdAt),
            style: AppTypography.entryDate(mutedColor),
          ),

          const SizedBox(height: 28),

          // ── Body: blocks (new) or markdown (legacy) ────────────────────
          if (entry.blocksJson != null && entry.blocksJson!.isNotEmpty)
            BlocksReadView(
              blocks: deserializeBlocks(entry.blocksJson!),
              isDark: isDark,
              textAlignment: entry.textAlignment,
              fontName: context.watch<AppState>().preferredFont,
            )
          else
            _InterleavedBody(entry: entry, isDark: isDark),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERLEAVED BODY
// Splits entry content at each inline image position and renders:
//   [text segment] → [image] → [text segment] → [image] → ...
// Images are sorted by position ascending before splitting.
// ─────────────────────────────────────────────────────────────────────────────

class _InterleavedBody extends StatelessWidget {
  final Entry entry;
  final bool isDark;

  const _InterleavedBody({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final content = entry.content;

    // No images — render whole content as markdown
    if (entry.images.isEmpty) {
      return FlowMarkdownBody(data: content, selectable: true);
    }

    // Sort images by position ascending
    final images = List.of(entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));

    final segments = <Widget>[];
    int cursor = 0;

    for (final image in images) {
      final pos = image.position.clamp(0, content.length);

      // Text before this image
      if (pos > cursor) {
        final segment = content.substring(cursor, pos);
        if (segment.trim().isNotEmpty) {
          segments.add(FlowMarkdownBody(data: segment, selectable: true));
        }
      }

      // The image itself — full-width within content area
      segments.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: InlineImageWidget(
            path: image.path,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      cursor = pos;
    }

    // Remaining text after last image
    if (cursor < content.length) {
      final remaining = content.substring(cursor);
      if (remaining.trim().isNotEmpty) {
        segments.add(FlowMarkdownBody(data: remaining, selectable: true));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: segments,
    );
  }
}
