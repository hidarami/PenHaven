import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../models/entry.dart';
import '../../models/editor_block.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/shared_widgets.dart';
import 'editor_canvas.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT SHEET
// Options: Full Content (one tall image) vs Split to Pages (9:16 portrait).
// Customise: header text, footer text, date, watermark, include images.
// Pages mode: captures full content then slices into portrait pages with
// per-page header/footer text and page numbers rendered via Canvas.
// ─────────────────────────────────────────────────────────────────────────────

class ExportSheet extends StatefulWidget {
  final Entry entry;
  final bool isDark;

  const ExportSheet({super.key, required this.entry, required this.isDark});

  static Future<void> show(BuildContext context, Entry entry, bool isDark) {
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
  bool _showHeader = false;
  bool _showFooter = false;
  bool _includeImages = true;
  String _layoutMode = 'full'; // 'full' | 'pages'
  bool _showOptions = true;
  bool _exporting = false;

  // Pages mode state
  List<String> _pageTexts = [];
  int _currentPreviewPage = 0;

  final GlobalKey _exportKey = GlobalKey();
  late final TextEditingController _headerCtrl;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    _exportDark = widget.isDark;
    _headerCtrl = TextEditingController(
      text: widget.entry.title.isNotEmpty ? widget.entry.title : 'Flow',
    );
    _footerCtrl = TextEditingController(text: 'Flow');
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportAsImage() async {
    if (_exporting) return;
    setState(() => _exporting = true);

    try {
      if (_layoutMode == 'pages') {
        await _exportAsPages();
      } else {
        await _exportAsSingle();
      }
    } catch (e) {
      debugPrint('[ExportSheet] failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }

    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _exportAsSingle() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    final boundary =
        _exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (byteData == null || !mounted) return;

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final file = File(p.join(dir.path, 'flow_$ts.png'));
    await file.writeAsBytes(byteData.buffer.asUint8List());

    if (!mounted) return;
    Navigator.pop(context);
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png')],
      subject:
          widget.entry.title.isNotEmpty ? widget.entry.title : 'Flow Entry',
    );
  }

  Future<void> _exportAsPages() async {
    // Text-based pagination — no image slicing, no mid-word cuts
    final texts = _paginateContent();
    if (texts.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final files = <File>[];

    for (int i = 0; i < texts.length; i++) {
      if (!mounted) break;

      // Update preview to show this page's content
      setState(() {
        _pageTexts = texts;
        _currentPreviewPage = i;
      });

      // Wait for widget to render this page
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) break;

      final boundary = _exportKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) continue;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData != null) {
        final file = File(p.join(dir.path, 'flow_p${i + 1}_$ts.png'));
        await file.writeAsBytes(byteData.buffer.asUint8List());
        files.add(file);
      }
    }

    // Reset pagination state
    setState(() {
      _pageTexts = [];
      _currentPreviewPage = 0;
    });

    if (files.isEmpty || !mounted) return;
    Navigator.pop(context);
    await Share.shareXFiles(
      files.map((f) => XFile(f.path, mimeType: 'image/png')).toList(),
      subject:
          widget.entry.title.isNotEmpty ? widget.entry.title : 'Flow Entry',
      text: files.length > 1 ? '${files.length} pages · written in Flow' : null,
    );
  }

  /// Splits entry content into pages at paragraph boundaries.
  List<String> _paginateContent() {
    final content =
        widget.entry.blocksJson != null && widget.entry.blocksJson!.isNotEmpty
            ? plainTextFromBlocks(deserializeBlocks(widget.entry.blocksJson!))
            : widget.entry.content;

    if (content.trim().isEmpty) return [];

    // Split at paragraph breaks
    final paras = content
        .split(RegExp(r'\n\n+'))
        .where((p) => p.trim().isNotEmpty)
        .toList();

    if (paras.isEmpty) return [content];

    // ~480 chars per page for comfortable reading at font size 17
    const targetChars = 480;
    final pages = <String>[];
    var current = '';

    for (final para in paras) {
      final candidate = current.isEmpty ? para : '$current\n\n$para';
      if (candidate.length > targetChars && current.isNotEmpty) {
        pages.add(current.trim());
        current = para;
      } else {
        current = candidate;
      }
    }
    if (current.trim().isNotEmpty) pages.add(current.trim());
    return pages;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor =
        widget.isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      expand: false,
      builder: (context, sc) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            const SizedBox(height: 12),

            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text('Export',
                      style: GoogleFonts.crimsonPro(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: textColor)),
                  const Spacer(),
                  // Dark / light toggle
                  GestureDetector(
                    onTap: () => setState(() => _exportDark = !_exportDark),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _exportDark
                            ? AppColors.warmDark
                            : AppColors.warmWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: divColor),
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

            Divider(
                color: divColor,
                height: 20,
                thickness: 0.5,
                indent: 24,
                endIndent: 24),

            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                children: [
                  // ── Options header ──────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _showOptions = !_showOptions),
                    child: Row(
                      children: [
                        Text('OPTIONS',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                              letterSpacing: 2,
                            )),
                        const Spacer(),
                        Icon(
                          _showOptions
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: mutedColor,
                        ),
                      ],
                    ),
                  ),

                  if (_showOptions) ...[
                    const SizedBox(height: 12),

                    // Layout mode
                    _Card(
                      isDark: widget.isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Layout',
                              style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: textColor)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _ModeChip(
                                label: 'Full Content',
                                sub: 'One tall image',
                                isActive: _layoutMode == 'full',
                                isDark: widget.isDark,
                                onTap: () =>
                                    setState(() => _layoutMode = 'full'),
                              ),
                              const SizedBox(width: 8),
                              _ModeChip(
                                label: 'Split to Pages',
                                sub: '9:16 portrait',
                                isActive: _layoutMode == 'pages',
                                isDark: widget.isDark,
                                onTap: () =>
                                    setState(() => _layoutMode = 'pages'),
                              ),
                            ],
                          ),
                          if (_layoutMode == 'pages') ...[
                            const SizedBox(height: 8),
                            Text(
                              'Long entries are split into multiple portrait images. Share them as a collection.',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: mutedColor, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Toggles
                    _Card(
                      isDark: widget.isDark,
                      child: Column(
                        children: [
                          _ToggleRow(
                            label: 'Show Date',
                            value: _showDate,
                            onChanged: (v) => setState(() => _showDate = v),
                            textColor: textColor,
                          ),
                          _CardDivider(isDark: widget.isDark),
                          _ToggleRow(
                            label: 'Include Images',
                            value: _includeImages,
                            onChanged: (v) =>
                                setState(() => _includeImages = v),
                            textColor: textColor,
                          ),
                          _CardDivider(isDark: widget.isDark),
                          _ToggleRow(
                            label: 'Watermark',
                            value: _showWatermark,
                            onChanged: (v) =>
                                setState(() => _showWatermark = v),
                            textColor: textColor,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Header
                    _Card(
                      isDark: widget.isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Header',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor)),
                              const Spacer(),
                              Switch.adaptive(
                                value: _showHeader,
                                onChanged: (v) =>
                                    setState(() => _showHeader = v),
                                activeThumbColor: AppColors.teal,
                                activeTrackColor: AppColors.teal,
                              ),
                            ],
                          ),
                          if (_showHeader) ...[
                            const SizedBox(height: 8),
                            _TextField(
                              controller: _headerCtrl,
                              hint: 'Header text...',
                              isDark: widget.isDark,
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_layoutMode == 'pages') ...[
                              const SizedBox(height: 6),
                              Text(
                                'Appears at the top of every page.',
                                style: GoogleFonts.inter(
                                    fontSize: 11, color: mutedColor),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Footer
                    _Card(
                      isDark: widget.isDark,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Footer',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor)),
                              const Spacer(),
                              Switch.adaptive(
                                value: _showFooter,
                                onChanged: (v) =>
                                    setState(() => _showFooter = v),
                                activeThumbColor: AppColors.teal,
                                activeTrackColor: AppColors.teal,
                              ),
                            ],
                          ),
                          if (_showFooter) ...[
                            const SizedBox(height: 8),
                            _TextField(
                              controller: _footerCtrl,
                              hint: 'Footer text...',
                              isDark: widget.isDark,
                              onChanged: (_) => setState(() {}),
                            ),
                          ],
                          if (_layoutMode == 'pages') ...[
                            const SizedBox(height: 6),
                            Text(
                              'Page numbers are always shown in pages mode.',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: mutedColor),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],

                  // ── Preview ─────────────────────────────────────────────
                  Text('PREVIEW',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: mutedColor,
                        letterSpacing: 2,
                      )),
                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: RepaintBoundary(
                      key: _exportKey,
                      child: _EntryExportView(
                        entry: widget.entry,
                        isDark: _exportDark,
                        showDate: _showDate,
                        showWatermark: _showWatermark,
                        includeImages: _includeImages,
                        showHeader: _showHeader,
                        headerText: _headerCtrl.text,
                        showFooter: _showFooter,
                        footerText: _footerCtrl.text,
                        // Pages mode: override text content + show page numbers
                        pageOverrideText: _pageTexts.isNotEmpty
                            ? _pageTexts[_currentPreviewPage]
                            : null,
                        pageNum: _pageTexts.isNotEmpty
                            ? _currentPreviewPage + 1
                            : null,
                        totalPages:
                            _pageTexts.isNotEmpty ? _pageTexts.length : null,
                      ),
                    ),
                  ),

                  if (_layoutMode == 'pages') ...[
                    const SizedBox(height: 8),
                    Text(
                      'Preview shows the full content. In pages mode it will be split into 9:16 portrait images with header/footer on each page.',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: mutedColor, height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Export buttons ───────────────────────────────────────
                  _ExportBtn(
                    icon: Icons.image_outlined,
                    label: _layoutMode == 'pages'
                        ? 'Export as Images (Pages)'
                        : 'Share as Image',
                    sub: _layoutMode == 'pages'
                        ? 'PNG · Split into 9:16 portrait pages'
                        : 'PNG · Full entry height',
                    color: AppColors.teal,
                    onTap: _exporting ? null : _exportAsImage,
                    loading: _exporting,
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 10),
                  _ExportBtn(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Export as PDF',
                    sub: 'Paginated document',
                    color: mutedColor,
                    onTap: () {
                      Navigator.pop(context);
                      ExportService.instance.exportAsPdf(widget.entry);
                    },
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 10),
                  _ExportBtn(
                    icon: Icons.text_snippet_outlined,
                    label: 'Export as TXT',
                    sub: 'Plain text, no formatting',
                    color: mutedColor,
                    onTap: () {
                      Navigator.pop(context);
                      ExportService.instance.exportAsTxt(widget.entry);
                    },
                    isDark: widget.isDark,
                  ),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
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
// ENTRY EXPORT VIEW
// Premium styled card — looks like a designed product, not a screenshot.
// ─────────────────────────────────────────────────────────────────────────────

class _EntryExportView extends StatelessWidget {
  final Entry entry;
  final bool isDark;
  final bool showDate;
  final bool showWatermark;
  final bool includeImages;
  final bool showHeader;
  final String headerText;
  final bool showFooter;
  final String footerText;
  // Pages mode: when set, render only this text instead of full content
  final String? pageOverrideText;
  final int? pageNum;
  final int? totalPages;

  const _EntryExportView({
    required this.entry,
    required this.isDark,
    required this.showDate,
    required this.showWatermark,
    required this.includeImages,
    this.showHeader = false,
    this.headerText = '',
    this.showFooter = false,
    this.footerText = '',
    this.pageOverrideText,
    this.pageNum,
    this.totalPages,
  });

  bool get _isPagesMode => pageOverrideText != null;

  @override
  Widget build(BuildContext context) {
    // Distinctive export colors — different enough from app to not look like screenshot
    final bg = isDark ? const Color(0xFF16110C) : const Color(0xFFFBF7F1);
    final cardBg = isDark ? const Color(0xFF1D1710) : const Color(0xFFFEFAF5);
    final textColor =
        isDark ? const Color(0xFFEEE8DF) : const Color(0xFF1C1208);
    final mutedColor =
        isDark ? const Color(0xFF7A6E62) : const Color(0xFF9A8D7E);
    const teal = Color(0xFF7BA591);

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.35 : 0.09),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Top teal accent bar ─────────────────────────────────────
            Container(
              height: 3.5,
              decoration: const BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),

            // ── Header (custom text) ────────────────────────────────────
            if (showHeader && headerText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                child: Row(
                  children: [
                    Container(width: 20, height: 1.5, color: teal),
                    const SizedBox(width: 8),
                    Text(
                      headerText.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                        color: teal,
                      ),
                    ),
                  ],
                ),
              ),

            // ── Header image ────────────────────────────────────────────
            if (entry.hasHeaderImage &&
                includeImages &&
                File(entry.headerImage!).existsSync() &&
                !_isPagesMode)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: Image.file(
                    File(entry.headerImage!),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),

            // ── Main content area ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title — only on first page or single mode
                  if (!_isPagesMode || pageNum == 1) ...[
                    Text(
                      entry.title.isEmpty ? 'Untitled' : entry.title,
                      style: GoogleFonts.crimsonPro(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        height: 1.1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (showDate) ...[
                      const SizedBox(height: 7),
                      Text(
                        DateFormat('MMMM d, yyyy')
                            .format(entry.createdAt)
                            .toUpperCase(),
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          letterSpacing: 2.0,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(height: 0.5, color: teal.withOpacity(0.35)),
                    const SizedBox(height: 18),
                  ] else ...[
                    // Subsequent pages: just a small continuation indicator
                    Row(children: [
                      Container(
                          width: 20, height: 1.5, color: teal.withOpacity(0.4)),
                      const SizedBox(width: 8),
                      Text(
                        entry.title.isEmpty ? 'Untitled' : entry.title,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w500,
                          color: mutedColor,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                  ],

                  // ── Body Content ──────────────────────────────────────
                  _buildBody(textColor, mutedColor),

                  // ── Footer ────────────────────────────────────────────
                  const SizedBox(height: 20),
                  Container(height: 0.5, color: mutedColor.withOpacity(0.18)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left: footer text or page number
                      if (_isPagesMode && totalPages != null)
                        Text(
                          '${pageNum ?? 1} / $totalPages',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            color: mutedColor.withOpacity(0.7),
                            letterSpacing: 0.5,
                          ),
                        )
                      else if (showFooter && footerText.isNotEmpty)
                        Text(
                          footerText,
                          style: GoogleFonts.inter(
                              fontSize: 9.5, color: mutedColor),
                        )
                      else
                        const SizedBox.shrink(),

                      // Right: Flow watermark
                      if (showWatermark)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 12,
                                height: 1.5,
                                color: teal.withOpacity(0.7)),
                            const SizedBox(width: 5),
                            Text(
                              'Flow',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: mutedColor,
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color textColor, Color mutedColor) {
    // Pages mode: show only this page's text
    if (_isPagesMode && pageOverrideText != null) {
      return Text(
        pageOverrideText!,
        style: GoogleFonts.crimsonPro(
          fontSize: 17,
          color: textColor,
          height: 1.85,
        ),
      );
    }

    // Single mode: full content
    if (entry.blocksJson != null && entry.blocksJson!.isNotEmpty) {
      final blocks = deserializeBlocks(entry.blocksJson!);
      final filtered = includeImages
          ? blocks
          : blocks
              .where((b) => b is! ImageBlock && b is! ImageGridBlock)
              .toList();
      return BlocksReadView(
        blocks: filtered,
        isDark: isDark,
        textAlignment: 'left',
      );
    }

    return _LegacyBody(
        entry: entry, isDark: isDark, includeImages: includeImages);
  }
}

// ── Legacy body renderer ──────────────────────────────────────────────────────

class _LegacyBody extends StatelessWidget {
  final Entry entry;
  final bool isDark;
  final bool includeImages;

  const _LegacyBody(
      {required this.entry, required this.isDark, required this.includeImages});

  @override
  Widget build(BuildContext context) {
    if (!includeImages || entry.images.isEmpty) {
      return FlowMarkdownBody(data: entry.content, selectable: false);
    }

    final content = entry.content;
    final images = List.of(entry.images)
      ..sort((a, b) => a.position.compareTo(b.position));
    final segments = <Widget>[];
    int cursor = 0;

    for (final img in images) {
      final pos = img.position.clamp(0, content.length);
      if (pos > cursor) {
        final seg = content.substring(cursor, pos);
        if (seg.trim().isNotEmpty) {
          segments.add(FlowMarkdownBody(data: seg, selectable: false));
        }
      }
      segments.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: File(img.path).existsSync()
              ? Image.file(File(img.path),
                  width: double.infinity, fit: BoxFit.cover)
              : const SizedBox.shrink(),
        ),
      ));
      cursor = pos;
    }

    if (cursor < content.length) {
      final rem = content.substring(cursor);
      if (rem.trim().isNotEmpty) {
        segments.add(FlowMarkdownBody(data: rem, selectable: false));
      }
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: segments);
  }
}

// ── Small UI components ───────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _Card({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class _CardDivider extends StatelessWidget {
  final bool isDark;
  const _CardDivider({required this.isDark});

  @override
  Widget build(BuildContext context) => Divider(
        height: 1,
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.07),
      );
}

class _ModeChip extends StatelessWidget {
  final String label;
  final String sub;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.sub,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final textCol = isDark ? AppColors.textDark : AppColors.textLight;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.teal.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.teal : muted.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.teal : textCol,
                  )),
              const SizedBox(height: 2),
              Text(sub, style: GoogleFonts.inter(fontSize: 10, color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color textColor;

  const _ToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: textColor)),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.teal,
            activeTrackColor: AppColors.teal,
          ),
        ],
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isDark;
  final ValueChanged<String>? onChanged;

  const _TextField({
    required this.controller,
    required this.hint,
    required this.isDark,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 14, color: textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: mutedColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: divColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: divColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
      ),
    );
  }
}

class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;
  final bool isDark;

  const _ExportBtn({
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
                        style:
                            GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                  ],
                ),
              ),
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.teal),
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
