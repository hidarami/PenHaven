import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/entry.dart';
import '../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT SERVICE
// Three export modes for entries:
//   1. TXT  — plain text, no markdown syntax
//   2. PDF  — formatted document
//   3. Social Card — 1080×1920 image (Instagram story style)
//
// All exports use share_plus to open the system share sheet.
// ─────────────────────────────────────────────────────────────────────────────

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  // ─────────────────────────────────────────────────────────────────────────
  // TXT EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> exportAsTxt(Entry entry) async {
    final dateStr = DateFormat('EEEE, MMMM d, yyyy').format(entry.createdAt);
    final buffer = StringBuffer();

    buffer.writeln(entry.title);
    buffer.writeln(dateStr);
    buffer.writeln();
    // Strip markdown syntax for plain text
    buffer.writeln(_stripMarkdown(entry.content));

    if (entry.formattedTimeSpent.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Time spent: ${entry.formattedTimeSpent}');
    }

    final file = await _writeTempFile(
      name: '${_sanitizeFilename(entry.title)}.txt',
      content: buffer.toString(),
    );

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: entry.title,
    );
  }

  String _stripMarkdown(String md) {
    return md
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*\*|__'), '')
        .replaceAll(RegExp(r'\*|_'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'>\s'), '')
        .replaceAll(RegExp(r'==(.+?)=='), r'$1')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> exportAsPdf(Entry entry) async {
    final doc = pw.Document();
    final dateStr = DateFormat('EEEE, MMMM d, yyyy • h:mm a')
        .format(entry.createdAt);

    // Load header image if exists
    pw.MemoryImage? headerImg;
    if (entry.hasHeaderImage) {
      try {
        final bytes = await File(entry.headerImage!).readAsBytes();
        headerImg = pw.MemoryImage(bytes);
      } catch (_) {}
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(48),
        build: (context) => [
          // Header image
          if (headerImg != null) ...[
            pw.ClipRRect(
              horizontalRadius: 8,
              verticalRadius: 8,
              child: pw.Image(headerImg, height: 180, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(height: 24),
          ],
          // Title
          pw.Text(
            entry.title.isEmpty ? 'Untitled' : entry.title,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 6),
          // Date
          pw.Text(
            dateStr,
            style: pw.TextStyle(
              fontSize: 12,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 16),
          // Body (stripped of markdown)
          pw.Text(
            _stripMarkdown(entry.content),
            style: const pw.TextStyle(fontSize: 13, lineSpacing: 6),
          ),
          // Footer
          if (entry.formattedTimeSpent.isNotEmpty) ...[
            pw.SizedBox(height: 32),
            pw.Divider(color: PdfColors.grey200),
            pw.SizedBox(height: 8),
            pw.Text(
              'Time spent: ${entry.formattedTimeSpent}  •  Flow',
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ],
      ),
    );

    final bytes = await doc.save();
    final file = await _writeTempFileBytes(
      name: '${_sanitizeFilename(entry.title)}.pdf',
      bytes: bytes,
    );

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/pdf')],
      subject: entry.title,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL CARD EXPORT
  // "Digital Receipt" style — 1080×1920, Instagram story dimensions.
  // Uses RepaintBoundary to capture a widget as an image.
  // ─────────────────────────────────────────────────────────────────────────

  /// Provide the [repaintKey] from a RepaintBoundary wrapping the card widget.
  Future<void> exportAsSocialCard(
    Entry entry,
    GlobalKey repaintKey,
  ) async {
    try {
      final boundary = repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final file = await _writeTempFileBytes(
        name: 'flow_card_${DateTime.now().millisecondsSinceEpoch}.png',
        bytes: bytes,
      );

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: entry.title,
      );
    } catch (_) {
      // Silently fail — share sheet won't open
    }
  }

  /// Builds the social card widget that should be wrapped in RepaintBoundary.
  /// Render this off-screen (e.g. via Offstage) then capture with the key.
  Widget buildSocialCardWidget(Entry entry, {bool isDark = false}) {
    final bg = isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final dateStr = DateFormat('MMMM d, yyyy').format(entry.createdAt);
    final preview = entry.preview(280);

    return Container(
      width: 360, // Will be scaled up by pixelRatio: 3.0 → 1080px
      height: 640,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decorative accent line
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.aqua,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),
          // Entry title
          Text(
            entry.title.isEmpty ? 'Untitled' : entry.title,
            style: GoogleFonts.crimsonPro(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Date
          Text(
            dateStr,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: mutedColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 28),
          // Divider
          Divider(color: AppColors.dividerLight, thickness: 0.5),
          const SizedBox(height: 28),
          // Body preview
          Expanded(
            child: Text(
              preview,
              style: GoogleFonts.crimsonPro(
                fontSize: 18,
                color: textColor,
                height: 1.8,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 24),
          // Watermark
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Flow',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: mutedColor.withOpacity(0.5),
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FILE HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Future<File> _writeTempFile({
    required String name,
    required String content,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsString(content);
    return file;
  }

  Future<File> _writeTempFileBytes({
    required String name,
    required List<int> bytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes);
    return file;
  }

  String _sanitizeFilename(String raw) {
    final name = raw.isEmpty ? 'untitled' : raw;
    return name
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .toLowerCase()
        .substring(0, name.length.clamp(0, 40));
  }
}
