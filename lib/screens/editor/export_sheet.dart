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

  // ── Pagination constants ───────────────────────────────────────────────────
  // Page: 360×640px. Content padding: 28px each side → 304px content width.
  // Crimson Pro 17px ≈ 9px avg char width → ~33 chars/line.
  // Line height 17 × 1.85 ≈ 31.5px/line.
  //
  // First page usable lines: ~13  (header: title+date+divider ≈ 130px of 640)
  // Continuation page lines: ~15  (small running header ≈ 46px)
  static const int _kFirstPageLines = 13;
  static const int _kContPageLines = 15;
  static const int _kMinLinesBottom = 3; // orphan rule
  static const int _kMinLinesTop = 3; // widow rule
  static const double _kMinLastPageFill = 0.28;
  static const int _kCharsPerLine = 33;

  /// Estimates how many visual lines a text segment occupies.
  int _estimateLines(String text) {
    if (text.trim().isEmpty) return 0;
    int total = 0;
    for (final line in text.split('\n')) {
      if (line.trim().isEmpty) {
        total += 1;
      } else {
        total += (line.length / _kCharsPerLine).ceil().clamp(1, 999);
      }
    }
    return total;
  }

  /// Splits [text] so the first part has at most [maxLines] lines.
  /// Returns (firstPart, remainder). Splits at word boundaries.
  (String, String) _splitAtLine(String text, int maxLines) {
    if (maxLines <= 0) return ('', text);
    final words = text.split(RegExp(r' +'));
    final lines = <String>[];
    var cur = '';
    for (final word in words) {
      if (word.isEmpty) continue;
      if (cur.isEmpty) {
        cur = word;
      } else if (cur.length + 1 + word.length <= _kCharsPerLine) {
        cur += ' $word';
      } else {
        lines.add(cur);
        cur = word;
      }
    }
    if (cur.isNotEmpty) lines.add(cur);

    if (lines.length <= maxLines) return (text, '');
    final first = lines.take(maxLines).join(' ');
    final rest = lines.skip(maxLines).join(' ');
    return (first.trim(), rest.trim());
  }

  /// Rebalances the last two pages when the last page is nearly empty.
  List<String> _rebalancePages(List<String> pages) {
    if (pages.length < 2) return pages;
    final last = pages.last;
    final lastLines = _estimateLines(last);
    if (lastLines / _kContPageLines >= _kMinLastPageFill) return pages;

    // Combine last two pages and re-split at ~60% / 40%
    final prev = pages[pages.length - 2];
    final combined = '$prev\n\n$last';
    final combinedLines = _estimateLines(prev) + lastLines;
    final targetFirst = (combinedLines * 0.62).round().clamp(
          _kMinLinesTop,
          _kContPageLines,
        );

    final segs = combined
        .split(RegExp(r'\n{2,}'))
        .where((s) => s.trim().isNotEmpty)
        .toList();

    final newFirst = <String>[];
    final newSecond = <String>[];
    int acc = 0;

    for (final seg in segs) {
      final sl = _estimateLines(seg);
      if (acc < targetFirst) {
        newFirst.add(seg);
        acc += sl;
      } else {
        newSecond.add(seg);
      }
    }

    if (newFirst.isEmpty || newSecond.isEmpty) return pages;

    final result = List<String>.from(pages);
    result[result.length - 2] = newFirst.join('\n\n');
    result[result.length - 1] = newSecond.join('\n\n');
    return result;
  }

  /// Semantically paginates content respecting block boundaries,
  /// orphan/widow rules, and page rebalancing.
  List<String> _paginateContent() {
    final raw =
        widget.entry.blocksJson != null && widget.entry.blocksJson!.isNotEmpty
            ? plainTextFromBlocks(deserializeBlocks(widget.entry.blocksJson!))
            : widget.entry.content;

    if (raw.trim().isEmpty) return [];

    // Semantic segments: double-newline separated paragraphs.
    // Single newlines (e.g. poetry) are kept as one segment.
    final segs = raw
        .split(RegExp(r'\n{2,}'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (segs.isEmpty) return [raw];

    final pages = <String>[];
    final curSegs = <String>[];
    int curLines = 0;
    bool isFirst = true;

    int budget() => isFirst ? _kFirstPageLines : _kContPageLines;

    void commitPage() {
      if (curSegs.isNotEmpty) {
        pages.add(curSegs.join('\n\n'));
        curSegs.clear();
      }
      curLines = 0;
      isFirst = false;
    }

    for (final seg in segs) {
      final sl = _estimateLines(seg);
      if (sl == 0) continue;

      final remaining = budget() - curLines;

      if (curLines + sl <= budget()) {
        // Fits on current page
        curSegs.add(seg);
        curLines += sl;
      } else if (remaining >= _kMinLinesBottom &&
          sl > remaining &&
          (sl - remaining) >= _kMinLinesTop) {
        // Try splitting this segment at the line boundary
        final (first, rest) = _splitAtLine(seg, remaining);
        if (first.trim().isNotEmpty) curSegs.add(first.trim());
        commitPage();
        if (rest.trim().isNotEmpty) {
          curSegs.add(rest.trim());
          curLines = _estimateLines(rest);
        }
      } else {
        // Segment doesn't fit and can't be split cleanly — move to next page
        commitPage();
        curSegs.add(seg);
        curLines = sl;
      }
    }

    commitPage();

    return _rebalancePages(pages);
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
                                activeThumbColor: AppColors.aqua,
                                activeTrackColor: AppColors.aqua,
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
                                activeThumbColor: AppColors.aqua,
                                activeTrackColor: AppColors.aqua,
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
                    color: AppColors.aqua,
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
                    loading: _exporting,
                    onTap: _exporting
                        ? null
                        : () async {
                            setState(() => _exporting = true);
                            try {
                              await ExportService.instance
                                  .exportAsPdf(widget.entry);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'PDF export failed. Please try again.')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _exporting = false);
                            }
                          },
                    isDark: widget.isDark,
                  ),
                  const SizedBox(height: 10),
                  _ExportBtn(
                    icon: Icons.text_snippet_outlined,
                    label: 'Export as TXT',
                    sub: 'Plain text, no formatting',
                    color: mutedColor,
                    loading: _exporting,
                    onTap: _exporting
                        ? null
                        : () async {
                            setState(() => _exporting = true);
                            try {
                              await ExportService.instance
                                  .exportAsTxt(widget.entry);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'TXT export failed. Please try again.')),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _exporting = false);
                            }
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
    const aqua = ui.Color.fromARGB(255, 27, 141, 175);

    return Container(
      width: double.infinity,
      height: _isPagesMode ? 640 : null,
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
            // ── Top aqua accent bar ─────────────────────────────────────
            Container(
              height: 3.5,
              decoration: const BoxDecoration(
                color: aqua,
                borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ),

            // ── Header (custom text) ────────────────────────────────────
            if (showHeader && headerText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
                child: Row(
                  children: [
                    Container(width: 20, height: 1.5, color: aqua),
                    const SizedBox(width: 8),
                    Text(
                      headerText.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w600,
                        color: aqua,
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
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
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
                        Container(height: 0.5, color: aqua.withOpacity(0.35)),
                        const SizedBox(height: 18),
                      ] else ...[
                        // Subsequent pages: just a small continuation indicator
                        Row(children: [
                          Container(
                              width: 20,
                              height: 1.5,
                              color: aqua.withOpacity(0.4)),
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

                      // ── Body Content ──────────────────────────────────────────
                      Expanded(child: _buildBody(textColor, mutedColor)),

                      // ── Footer ────────────────────────────────────────────
                      const SizedBox(height: 20),
                      Container(
                          height: 0.5, color: mutedColor.withOpacity(0.18)),
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
                                    color: aqua.withOpacity(0.7)),
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Color textColor, Color mutedColor) {
    // Debug logging
    debugPrint('[ExportSheet] _buildBody called');
    debugPrint(
        '[ExportSheet] entry.blocksJson: ${entry.blocksJson != null ? "has value (${entry.blocksJson!.length} chars)" : "null"}');
    debugPrint('[ExportSheet] entry.content length: ${entry.content.length}');
    debugPrint('[ExportSheet] _isPagesMode: $_isPagesMode');

    // Pages mode: show only this page's text
    if (_isPagesMode && pageOverrideText != null) {
      final text = pageOverrideText!.trim();
      debugPrint('[ExportSheet] Pages mode text length: ${text.length}');
      if (text.isEmpty) {
        return _EmptyContentIndicator(
            textColor: textColor, mutedColor: mutedColor);
      }
      return Text(
        text,
        style: GoogleFonts.crimsonPro(
          fontSize: 17,
          color: textColor,
          height: 1.85,
        ),
      );
    }

    // Single mode: full content
    if (entry.blocksJson != null && entry.blocksJson!.isNotEmpty) {
      debugPrint('[ExportSheet] Using blocks mode');
      final blocks = deserializeBlocks(entry.blocksJson!);
      debugPrint('[ExportSheet] Deserialized ${blocks.length} blocks');
      final filtered = includeImages
          ? blocks
          : blocks
              .where((b) => b is! ImageBlock && b is! ImageGridBlock)
              .toList();
      debugPrint('[ExportSheet] After filtering: ${filtered.length} blocks');

      // Check if filtered blocks have any actual content
      final hasContent = filtered.any((b) {
        if (b is TextBlock) return b.text.trim().isNotEmpty;
        if (b is ImageBlock) return true;
        if (b is ImageGridBlock) return true;
        if (b is CodeBlock) return b.code.trim().isNotEmpty;
        if (b is YoutubeBlock) return true;
        if (b is TweetBlock) return true;
        if (b is DividerBlock) return true;
        return false;
      });

      debugPrint('[ExportSheet] hasContent: $hasContent');

      if (!hasContent) {
        return _EmptyContentIndicator(
            textColor: textColor, mutedColor: mutedColor);
      }

      return BlocksReadView(
        blocks: filtered,
        isDark: isDark,
        textAlignment: 'left',
      );
    }

    // Legacy mode - check if content is empty
    debugPrint('[ExportSheet] Using legacy mode');
    if (entry.content.trim().isEmpty && entry.images.isEmpty) {
      debugPrint('[ExportSheet] Legacy mode: content is empty');
      return _EmptyContentIndicator(
          textColor: textColor, mutedColor: mutedColor);
    }

    debugPrint('[ExportSheet] Legacy mode: rendering content');
    return _LegacyBody(
        entry: entry, isDark: isDark, includeImages: includeImages);
  }
}

// ── Empty content indicator ───────────────────────────────────────────────────────

class _EmptyContentIndicator extends StatelessWidget {
  final Color textColor;
  final Color mutedColor;

  const _EmptyContentIndicator({
    required this.textColor,
    required this.mutedColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.edit_note_outlined,
              size: 48,
              color: mutedColor.withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No content to export',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: mutedColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
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
                ? AppColors.aqua.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? AppColors.aqua : muted.withOpacity(0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive ? AppColors.aqua : textCol,
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
            activeThumbColor: AppColors.aqua,
            activeTrackColor: AppColors.aqua,
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
          borderSide: const BorderSide(color: AppColors.aqua, width: 1.5),
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
                      strokeWidth: 1.5, color: AppColors.aqua),
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
