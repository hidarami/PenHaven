import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../models/entry.dart';
import '../../models/editor_block.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/shared_widgets.dart';
import 'editor_canvas.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT SHEET
// Bottom sheet with all export options:
//   - Share as image (full entry, scrollable tall image)
//   - Export as PDF
//   - Export as TXT
// Options: Dark/Light, show/hide date, show/hide watermark
// ─────────────────────────────────────────────────────────────────────────────

class ExportSheet extends StatefulWidget {
  final Entry entry;
  final bool isDark;

  const ExportSheet({super.key, required this.entry, required this.isDark});

  static Future<void> show(
      BuildContext context, Entry entry, bool isDark) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportSheet(entry: entry, isDark: isDark),
    );
  }

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  late bool _exportDark;
  bool _showDate = true;
  bool _showWatermark = true;
  bool _exporting = false;

  // RepaintBoundary key for the preview/export widget
  final GlobalKey _exportKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _exportDark = widget.isDark;
  }

  Future<void> _exportAsImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      // Give the widget one frame to paint before capture
      await Future.delayed(const Duration(milliseconds: 250));
      if (!mounted) return;

      final boundary = _exportKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        setState(() => _exporting = false);
        return;
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null || !mounted) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File(p.join(dir.path, 'flow_entry_$ts.png'));
      await file.writeAsBytes(bytes);

      if (!mounted) return;
      Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: widget.entry.title.isNotEmpty
            ? widget.entry.title
            : 'Flow Entry',
      );
    } catch (e) {
      debugPrint('[ExportSheet] Image export failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = widget.isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor =
        widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divider =
        widget.isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
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
                  Text(
                    'Export',
                    style: GoogleFonts.crimsonPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const Spacer(),
                  // Dark/light toggle for export
                  GestureDetector(
                    onTap: () =>
                        setState(() => _exportDark = !_exportDark),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _exportDark
                            ? AppColors.warmDark
                            : AppColors.warmWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: divider,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _exportDark
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            size: 14,
                            color: _exportDark
                                ? AppColors.textDark
                                : AppColors.textLight,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _exportDark ? 'Dark' : 'Light',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _exportDark
                                  ? AppColors.textDark
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Options row
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  _ToggleChip(
                    label: 'Date',
                    active: _showDate,
                    onTap: () =>
                        setState(() => _showDate = !_showDate),
                    isDark: widget.isDark,
                  ),
                  const SizedBox(width: 8),
                  _ToggleChip(
                    label: 'Watermark',
                    active: _showWatermark,
                    onTap: () => setState(
                        () => _showWatermark = !_showWatermark),
                    isDark: widget.isDark,
                  ),
                ],
              ),
            ),

            Divider(
                color: divider,
                thickness: 0.5,
                height: 24,
                indent: 24,
                endIndent: 24),

            // Scrollable preview
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  children: [
                    // Live preview with RepaintBoundary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: RepaintBoundary(
                          key: _exportKey,
                          child: _EntryExportView(
                            entry: widget.entry,
                            isDark: _exportDark,
                            showDate: _showDate,
                            showWatermark: _showWatermark,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Note about long entries
                    if ((widget.entry.content.length > 600 ||
                        widget.entry.images.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Long entries export as a tall scrollable image. '
                          'Use PDF export for a paginated document.',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: mutedColor,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // Share as image
                          _ExportButton(
                            icon: Icons.image_outlined,
                            label: 'Share as Image',
                            sub: 'PNG · Full entry, all images',
                            color: AppColors.teal,
                            onTap: _exporting ? null : _exportAsImage,
                            loading: _exporting,
                            isDark: widget.isDark,
                          ),
                          const SizedBox(height: 10),
                          _ExportButton(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'Export as PDF',
                            sub: 'Formatted document, all pages',
                            color: mutedColor,
                            onTap: () {
                              Navigator.pop(context);
                              ExportService.instance
                                  .exportAsPdf(widget.entry);
                            },
                            isDark: widget.isDark,
                          ),
                          const SizedBox(height: 10),
                          _ExportButton(
                            icon: Icons.text_snippet_outlined,
                            label: 'Export as TXT',
                            sub: 'Plain text, no formatting',
                            color: mutedColor,
                            onTap: () {
                              Navigator.pop(context);
                              ExportService.instance
                                  .exportAsTxt(widget.entry);
                            },
                            isDark: widget.isDark,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom + 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY EXPORT VIEW
// The actual rendered widget that gets captured as an image.
// Full entry: header image, title, date, full body content, all inline images.
// ─────────────────────────────────────────────────────────────────────────────

class _EntryExportView extends StatelessWidget {
  final Entry entry;
  final bool isDark;
  final bool showDate;
  final bool showWatermark;

  const _EntryExportView({
    required this.entry,
    required this.isDark,
    required this.showDate,
    required this.showWatermark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Container(
      width: double.infinity,
      color: bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Teal accent line at top
          Container(
            height: 3,
            color: AppColors.teal,
            margin: const EdgeInsets.only(bottom: 0),
          ),

          // Header image (full width, no padding, preserves original ratio)
          if (entry.hasHeaderImage && File(entry.headerImage!).existsSync())
            Image.file(
              File(entry.headerImage!),
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),

          // Content area with padding
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  entry.title.isEmpty ? 'Untitled' : entry.title,
                  style: GoogleFonts.crimsonPro(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.2,
                  ),
                ),

                if (showDate) ...[
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('MMMM d, yyyy').format(entry.createdAt),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: mutedColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],

                const SizedBox(height: 16),
                Divider(color: divider, thickness: 0.5),
                const SizedBox(height: 16),

                // Body: blocks or legacy markdown + inline images
                if (entry.blocksJson != null &&
                    entry.blocksJson!.isNotEmpty)
                  _ExportBlocksView(
                    blocks: deserializeBlocks(entry.blocksJson!),
                    isDark: isDark,
                  )
                else
                  _ExportLegacyBody(entry: entry, isDark: isDark),

                // Watermark
                if (showWatermark) ...[
                  const SizedBox(height: 24),
                  Divider(color: divider, thickness: 0.5),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 2,
                          color: AppColors.teal,
                          margin: const EdgeInsets.only(right: 6),
                        ),
                        Text(
                          'Flow',
                          style: GoogleFonts.crimsonPro(
                            fontSize: 13,
                            color: mutedColor.withOpacity(0.6),
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT BODY RENDERERS (no gesture detectors, pure display)
// ─────────────────────────────────────────────────────────────────────────────

class _ExportBlocksView extends StatelessWidget {
  final List<EditorBlock> blocks;
  final bool isDark;

  const _ExportBlocksView(
      {required this.blocks, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return BlocksReadView(
      blocks: blocks,
      isDark: isDark,
      textAlignment: 'left', // Left-align for image export readability
    );
  }
}

class _ExportLegacyBody extends StatelessWidget {
  final Entry entry;
  final bool isDark;

  const _ExportLegacyBody(
      {required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (entry.images.isEmpty) {
      return FlowMarkdownBody(data: entry.content, selectable: false);
    }

    final content = entry.content;
    final images = List.of(entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));
    final segments = <Widget>[];
    int cursor = 0;

    for (final image in images) {
      final pos = image.position.clamp(0, content.length);
      if (pos > cursor) {
        final segment = content.substring(cursor, pos);
        if (segment.trim().isNotEmpty) {
          segments.add(FlowMarkdownBody(data: segment, selectable: false));
        }
      }
      segments.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: File(image.path).existsSync()
              ? Image.file(File(image.path),
                  width: double.infinity, fit: BoxFit.cover)
              : const SizedBox.shrink(),
        ),
      ));
      cursor = pos;
    }

    if (cursor < content.length) {
      final remaining = content.substring(cursor);
      if (remaining.trim().isNotEmpty) {
        segments.add(FlowMarkdownBody(data: remaining, selectable: false));
      }
    }

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: segments);
  }
}

// ── UI components ─────────────────────────────────────────────────────────────

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final bool isDark;

  const _ToggleChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? AppColors.teal.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.teal : (isDark ? AppColors.mutedDark : AppColors.mutedLight).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.teal : (isDark ? AppColors.mutedDark : AppColors.mutedLight),
          ),
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  final bool isDark;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    this.onTap,
    this.loading = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark
        ? Colors.white.withOpacity(0.05)
        : Colors.black.withOpacity(0.03);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        )),
                    Text(sub,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: mutedColor,
                        )),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.teal,
                  ),
                )
              else
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: mutedColor.withOpacity(0.4)),
            ],
          ),
        ),
      ),
    );
  }
}