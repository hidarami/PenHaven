import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/editor_block.dart';
import '../../providers/app_state.dart';
import '../../theme/app_colors.dart';
import 'editor_canvas.dart';
import 'rich_editor_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// WYSIWYG TOOLBAR
// Persistent bottom toolbar for the block editor.
// Row 1: Text formatting (B, I, U, S, highlight, link)
// Row 2: Block type toggles + block insertion (image, YouTube, etc.)
// Active state reflects the focused text block's current format.
// ─────────────────────────────────────────────────────────────────────────────

class WysiwygToolbar extends StatefulWidget {
  final EditorCanvasState canvas;
  final VoidCallback? onImageInsert;
  final VoidCallback? onImageGridInsert;

  const WysiwygToolbar({
    super.key,
    required this.canvas,
    this.onImageInsert,
    this.onImageGridInsert,
  });

  @override
  State<WysiwygToolbar> createState() => _WysiwygToolbarState();
}

class _WysiwygToolbarState extends State<WysiwygToolbar> {
  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final divider = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final muted = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // Build-time snapshot for isActive display only.
    // All onTap handlers call widget.canvas.focusedController directly
    // so they read the LIVE controller at tap time, not the stale build-time one.
    final ctrl = widget.canvas.focusedController;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(color: divider, thickness: 0.5, height: 0),
          SizedBox(
            height: 50 + bottomPadding, // larger for easier tapping
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(8, 4, 8, bottomPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Text formatting ──────────────────────────────────────
                  _FormatButton(
                    label: 'B',
                    bold: true,
                    color: muted,
                    isActive: ctrl?.selectionHas(bold: true) ?? false,
                    onTap: () {
                      widget.canvas.focusedController?.toggleBold();
                      setState(() {});
                    },
                  ),
                  _FormatButton(
                    label: 'I',
                    italic: true,
                    color: muted,
                    isActive: ctrl?.selectionHas(italic: true) ?? false,
                    onTap: () {
                      widget.canvas.focusedController?.toggleItalic();
                      setState(() {});
                    },
                  ),
                  _FormatButton(
                    label: 'U',
                    underlineLabel: true,
                    color: muted,
                    isActive: ctrl?.selectionHas(underline: true) ?? false,
                    onTap: () {
                      widget.canvas.focusedController?.toggleUnderline();
                      setState(() {});
                    },
                  ),
                  _FormatButton(
                    label: 'S',
                    strikeLabel: true,
                    color: muted,
                    isActive: ctrl?.selectionHas(strikethrough: true) ?? false,
                    onTap: () {
                      widget.canvas.focusedController?.toggleStrikethrough();
                      setState(() {});
                    },
                  ),
                  _HighlightButton(
                    muted: muted,
                    dark: dark,
                    onColor: (c) {
                      widget.canvas.applyHighlight(c);
                      setState(() {});
                    },
                    onClear: () {
                      widget.canvas.clearHighlight();
                      setState(() {});
                    },
                  ),
                  _LinkButton(
                    muted: muted,
                    onApply: (url) {
                      widget.canvas.applyLink(url);
                      setState(() {});
                    },
                    onClear: () {
                      widget.canvas.clearLink();
                      setState(() {});
                    },
                  ),

                  _ToolbarDivider(color: divider),

                  // ── Block type ───────────────────────────────────────────
                  _BlockTypeButton(
                    label: 'H1',
                    color: muted,
                    isActive: _isFocusedType(BlockType.heading1),
                    onTap: () => _toggleBlockType(BlockType.heading1),
                  ),
                  _BlockTypeButton(
                    label: 'H2',
                    color: muted,
                    isActive: _isFocusedType(BlockType.heading2),
                    onTap: () => _toggleBlockType(BlockType.heading2),
                  ),
                  _BlockTypeButton(
                    label: 'H3',
                    color: muted,
                    isActive: _isFocusedType(BlockType.heading3),
                    onTap: () => _toggleBlockType(BlockType.heading3),
                  ),
                  _BlockTypeButton(
                    icon: Icons.format_quote_rounded,
                    color: muted,
                    isActive: _isFocusedType(BlockType.quote),
                    onTap: () => _toggleBlockType(BlockType.quote),
                  ),
                  // Bullet list block type
                  _BlockTypeButton(
                    icon: Icons.format_list_bulleted_rounded,
                    color: muted,
                    isActive: _isFocusedType(BlockType.bulletList),
                    onTap: () => _toggleBlockType(BlockType.bulletList),
                  ),
                  // Checklist (task) block insertion
                  _BlockTypeButton(
                    icon: Icons.checklist_rounded,
                    color: muted,
                    isActive: false,
                    onTap: () {
                      final id = widget.canvas.focusedBlockId ??
                          (widget.canvas.blocks.isNotEmpty
                              ? widget.canvas.blocks.last.id
                              : null);
                      if (id != null) widget.canvas.insertChecklistBlock(id);
                      setState(() {});
                    },
                  ),

                  _ToolbarDivider(color: divider),

                  // ── Text alignment ───────────────────────────────────────
                  _AlignmentButton(
                    color: muted,
                    alignment: widget.canvas.textAlignment,
                    onTap: () => _cycleAlignment(),
                  ),

                  _ToolbarDivider(color: divider),

                  // ── Block insertion ──────────────────────────────────────
                  _ToolbarIconButton(
                    icon: Icons.image_outlined,
                    color: muted,
                    onTap: widget.onImageInsert,
                  ),
                  _ToolbarIconButton(
                    icon: Icons.grid_on_rounded,
                    color: muted,
                    onTap: widget.onImageGridInsert,
                  ),
                  _ToolbarIconButton(
                    icon: Icons.play_circle_outline_rounded,
                    color: muted,
                    onTap: () => _showUrlDialog(
                        context, 'YouTube URL', 'https://youtube.com/watch?v=',
                        (url) {
                      if (widget.canvas.focusedBlockId != null) {
                        widget.canvas.insertYoutubeBlock(
                            widget.canvas.focusedBlockId!, url);
                      }
                    }),
                  ),
                  _ToolbarIconButton(
                    icon: Icons.link_rounded,
                    color: muted,
                    onTap: () => _showUrlDialog(
                        context, 'X / Twitter URL', 'https://x.com/', (url) {
                      if (widget.canvas.focusedBlockId != null) {
                        widget.canvas.insertTweetBlock(
                            widget.canvas.focusedBlockId!, url);
                      }
                    }),
                  ),
                  _ToolbarIconButton(
                    icon: Icons.code_rounded,
                    color: muted,
                    onTap: () {
                      if (widget.canvas.focusedBlockId != null) {
                        widget.canvas
                            .insertCodeBlock(widget.canvas.focusedBlockId!);
                      }
                    },
                  ),
                  _ToolbarIconButton(
                    icon: Icons.remove_rounded,
                    color: muted,
                    onTap: () {
                      if (widget.canvas.focusedBlockId != null) {
                        widget.canvas
                            .insertDivider(widget.canvas.focusedBlockId!);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isFocusedType(BlockType type) {
    final id = widget.canvas.focusedBlockId;
    if (id == null) return false;
    final blocks = widget.canvas.blocks;
    final block =
        blocks.firstWhere((b) => b.id == id, orElse: () => TextBlock.empty());
    return block is TextBlock && block.type == type;
  }

  void _toggleBlockType(BlockType type) {
    final id = widget.canvas.focusedBlockId;
    if (id == null) return;

    if (type == BlockType.quote) {
      final ctrl = widget.canvas.focusedController;
      if (ctrl != null &&
          !ctrl.selection.isCollapsed &&
          ctrl.selection.isValid) {
        _extractSelectionAsType(id, ctrl, BlockType.quote);
        return;
      }
    }

    final current = _isFocusedType(type) ? BlockType.text : type;
    widget.canvas.changeBlockType(id, current);
    setState(() {});
  }

  void _extractSelectionAsType(
      String blockId, RichEditorController ctrl, BlockType type) {
    final sel = ctrl.selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final text = ctrl.text;
    final selected = text.substring(sel.start, sel.end).trim();
    if (selected.isEmpty) return;

    final before = text.substring(0, sel.start).trimRight();
    final after = text.substring(sel.end).trimLeft();

    final blocks = widget.canvas.blocks;
    final origBlock = blocks.firstWhere(
      (b) => b.id == blockId,
      orElse: () => TextBlock.empty(),
    );
    if (origBlock is! TextBlock) return;

    // Extract format ranges for each part
    final beforeFormats = _extractFormatsInRange(ctrl.formats, 0, sel.start);
    final selectedFormats =
        _extractFormatsInRange(ctrl.formats, sel.start, sel.end);
    final afterFormats =
        _extractFormatsInRange(ctrl.formats, sel.end, text.length);

    // Shift format ranges for selected text to start at 0
    final shiftedSelectedFormats = selectedFormats
        .map((f) => FormatRange(
              start: f.start - sel.start,
              end: f.end - sel.start,
              attrs: f.attrs,
            ))
        .toList();

    // Shift format ranges for after text to start at 0
    final shiftedAfterFormats = afterFormats
        .map((f) => FormatRange(
              start: f.start - sel.end,
              end: f.end - sel.end,
              attrs: f.attrs,
            ))
        .toList();

    final quoteBlock = TextBlock(
      id: const Uuid().v4(),
      type: type,
      text: selected,
      formats: shiftedSelectedFormats,
    );

    if (before.isNotEmpty) {
      widget.canvas.updateBlock(origBlock.copyWith(
        text: before,
        formats: beforeFormats,
      ));
      widget.canvas.insertBlockAfter(blockId, quoteBlock);
    } else {
      widget.canvas.insertBlockAfter(blockId, quoteBlock);
      widget.canvas.removeBlock(blockId);
    }

    if (after.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.canvas.insertBlockAfter(
            quoteBlock.id,
            TextBlock(
              id: const Uuid().v4(),
              type: BlockType.text,
              text: after,
              formats: shiftedAfterFormats,
            ),
          );
          setState(() {});
        }
      });
    }

    setState(() {});
  }

  /// Extract format ranges that overlap with the given text range
  List<FormatRange> _extractFormatsInRange(
      List<FormatRange> formats, int rangeStart, int rangeEnd) {
    final result = <FormatRange>[];
    for (final fmt in formats) {
      // No overlap
      if (fmt.end <= rangeStart || fmt.start >= rangeEnd) continue;

      // Calculate overlap
      final overlapStart = fmt.start > rangeStart ? fmt.start : rangeStart;
      final overlapEnd = fmt.end < rangeEnd ? fmt.end : rangeEnd;

      result.add(FormatRange(
        start: overlapStart,
        end: overlapEnd,
        attrs: fmt.attrs,
      ));
    }
    return result;
  }

  void _cycleAlignment() {
    final current = widget.canvas.textAlignment;
    String next;
    if (current == 'justify') {
      next = 'left';
    } else if (current == 'left') {
      next = 'center';
    } else {
      next = 'justify';
    }
    widget.canvas.setTextAlignment(next);
    setState(() {});
  }

  void _showUrlDialog(
    BuildContext context,
    String title,
    String hint,
    void Function(String) onSubmit,
  ) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: hint),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final url = ctrl.text.trim();
              if (url.isNotEmpty) {
                onSubmit(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Insert'),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar components ────────────────────────────────────────────────────────

class _FormatButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;
  final bool underlineLabel;
  final bool strikeLabel;
  final bool isActive;

  const _FormatButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
    this.italic = false,
    this.underlineLabel = false,
    this.strikeLabel = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.aqua.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: isActive ? AppColors.aqua : color,
            decoration: underlineLabel
                ? TextDecoration.underline
                : strikeLabel
                    ? TextDecoration.lineThrough
                    : null,
            decorationColor: isActive ? AppColors.aqua : color,
          ),
        ),
      ),
    );
  }
}

class _BlockTypeButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final Color color;
  final bool isActive;
  final VoidCallback? onTap;

  const _BlockTypeButton({
    this.label,
    this.icon,
    required this.color,
    required this.isActive,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.aqua.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, size: 18, color: isActive ? AppColors.aqua : color)
            : Text(
                label!,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? AppColors.aqua : color,
                ),
              ),
      ),
    );
  }
}

class _HighlightButton extends StatelessWidget {
  final Color muted;
  final bool dark;
  final ValueChanged<Color> onColor;
  final VoidCallback onClear;

  const _HighlightButton({
    required this.muted,
    required this.dark,
    required this.onColor,
    required this.onClear,
  });

  static const _colors = [
    Color(0xFFFFFF00), // Yellow
    Color(0xFFFF9800), // Orange
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFFE91E63), // Pink
    Color(0xFF9C27B0), // Purple
  ];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(Icons.highlight_rounded, size: 18, color: muted),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Highlight Color',
                style: GoogleFonts.inter(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              children: [
                ..._colors.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () {
                          onColor(c);
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    )),
                GestureDetector(
                  onTap: () {
                    onClear();
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: muted),
                    ),
                    child: Icon(Icons.clear, size: 18, color: muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  final Color muted;
  final ValueChanged<String> onApply;
  final VoidCallback onClear;

  const _LinkButton({
    required this.muted,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showLinkDialog(context),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(Icons.add_link_rounded, size: 18, color: muted),
      ),
    );
  }

  void _showLinkDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insert Link'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://...'),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () {
              onClear();
              Navigator.pop(ctx);
            },
            child: const Text('Remove link'),
          ),
          TextButton(
            onPressed: () {
              var url = ctrl.text.trim();
              if (url.isNotEmpty) {
                // Auto-prefix scheme so bare domains (e.g. "example.com")
                // still resolve to a real, launchable link.
                if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:\/\/').hasMatch(url)) {
                  url = 'https://$url';
                }
                onApply(url);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _AlignmentButton extends StatelessWidget {
  final Color color;
  final String alignment;
  final VoidCallback onTap;

  const _AlignmentButton({
    required this.color,
    required this.alignment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (alignment) {
      case 'left':
        icon = Icons.format_align_left_rounded;
        break;
      case 'center':
        icon = Icons.format_align_center_rounded;
        break;
      case 'justify':
      default:
        icon = Icons.format_align_justify_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

class _ToolbarDivider extends StatelessWidget {
  final Color color;
  const _ToolbarDivider({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 20,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: color.withOpacity(0.3),
      );
}
