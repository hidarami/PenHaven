import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/entry.dart';
import '../../services/export_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EXPORT SHEET
// Simple export options: PDF and TXT only.
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
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final divColor =
        widget.isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.4,
      maxChildSize: 0.6,
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

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Export',
                  style: GoogleFonts.crimsonPro(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: textColor)),
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
                  // ── Export buttons ───────────────────────────────────────
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
// EXPORT BUTTON
// ─────────────────────────────────────────────────────────────────────────────

class _ExportBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  final bool isDark;

  const _ExportBtn({
    required this.icon,
    required this.label,
    required this.sub,
    required this.color,
    required this.loading,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: color.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}