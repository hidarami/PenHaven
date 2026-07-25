import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/editor_block.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import 'rich_editor_controller.dart';
import '../../theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR CANVAS
// Block-based WYSIWYG editor. Each block is a separate widget.
// Images are standalone blocks — no U+FFFC hacks, no position tracking bugs.
// Focused text block drives the WYSIWYG toolbar at the bottom.
// ─────────────────────────────────────────────────────────────────────────────

class EditorCanvas extends StatefulWidget {
  final List<EditorBlock> initialBlocks;
  final bool isDark;
  final void Function(List<EditorBlock>) onBlocksChanged;
  final ScrollController? scrollController;
  final String textAlignment;
  final String fontName;

  const EditorCanvas({
    super.key,
    required this.initialBlocks,
    required this.isDark,
    required this.onBlocksChanged,
    this.scrollController,
    this.textAlignment = 'justify',
    this.fontName = 'crimsonPro',
  });

  @override
  State<EditorCanvas> createState() => EditorCanvasState();
}

class EditorCanvasState extends State<EditorCanvas> {
  late List<EditorBlock> _blocks;

  bool get _isReflectionEntry =>
      _blocks.isNotEmpty && _blocks.first is ReflectionHeaderBlock;

  // Exposed for toolbar use
  List<EditorBlock> get blocks => _blocks;
  String textAlignment = 'justify';
  final Map<String, RichEditorController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  String? _focusedBlockId;
  bool _markdownOfferPending = false;
  final _scrollController = ScrollController();
  // Tracks which checklist block IDs should auto-focus after insertion
  final Set<String> _pendingFocus = {};

  @override
  void initState() {
    super.initState();
    _blocks = List.from(widget.initialBlocks);
    textAlignment = widget.textAlignment;
    if (_blocks.isEmpty) {
      _blocks.add(TextBlock.empty());
    }
    _initControllers();
  }

  void _initControllers() {
    for (final block in _blocks) {
      if (block is TextBlock) {
        _ensureController(block);
      }
    }
  }

  void _ensureController(TextBlock block) {
    if (!_controllers.containsKey(block.id)) {
      final textColor =
          widget.isDark ? AppColors.textDark : AppColors.textLight;
      final ctrl = RichEditorController(
        text: block.text,
        initialFormats: block.formats,
        baseTextColor: textColor,
        baseFontSize: _fontSizeForType(block.type),
      );
      ctrl.addListener(() => _onControllerChanged(block.id, ctrl));
      _controllers[block.id] = ctrl;
    }
    if (!_focusNodes.containsKey(block.id)) {
      final node = FocusNode();
      node.addListener(() {
        if (node.hasFocus) {
          setState(() => _focusedBlockId = block.id);
        }
      });
      _focusNodes[block.id] = node;
    }
  }

  void _onControllerChanged(String blockId, RichEditorController ctrl) {
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    if (idx == -1) return;
    final block = _blocks[idx] as TextBlock;

    final addedLen = ctrl.text.length - block.text.length;
    if (addedLen > 50 &&
        !_markdownOfferPending &&
        _hasMarkdownSyntax(ctrl.text)) {
      _offerMarkdownConversion(blockId, ctrl.text);
    }

    _blocks[idx] = block.copyWith(
      text: ctrl.text,
      formats: List.from(ctrl.formats),
    );
    widget.onBlocksChanged(_blocks);
  }

  bool _hasMarkdownSyntax(String text) {
    return text.contains(RegExp(r'#{1,6} ')) ||
        text.contains('**') ||
        text.contains('> ') ||
        text.contains('```') ||
        text.contains('---\n') ||
        text.contains('//') ||
        text.contains('~~') ||
        text.contains('==') ||
        text.contains('__');
  }

  void _offerMarkdownConversion(String blockId, String text) {
    _markdownOfferPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _markdownOfferPending = false;
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content:
                  const Text('Markdown detected — render as formatted blocks?'),
              action: SnackBarAction(
                label: 'Render',
                onPressed: () => _convertMarkdownToBlocks(blockId, text),
              ),
              duration: const Duration(seconds: 5),
            ),
          )
          .closed
          .then((_) => _markdownOfferPending = false);
    });
  }

  void _convertMarkdownToBlocks(String blockId, String text) {
    final newBlocks = _parseMarkdownToBlocks(text);
    setState(() {
      final idx = _blocks.indexWhere((b) => b.id == blockId);
      if (idx != -1) {
        _blocks.removeAt(idx);
        _controllers.remove(blockId)?.dispose();
        _focusNodes.remove(blockId)?.dispose();
        if (_focusedBlockId == blockId) _focusedBlockId = null;
        _blocks.insertAll(idx, newBlocks);
        for (final b in newBlocks) {
          if (b is TextBlock) _ensureController(b);
        }
      }
    });
    _markdownOfferPending = false;
    widget.onBlocksChanged(_blocks);
  }

  /// Strips inline markdown markers from [input] and returns
  /// (cleanText, formatRanges). Handles **bold**, *italic*, //italic//,
  /// __underline__, ~~strikethrough~~, ==highlight==.
  (String, List<FormatRange>) _parseInlineMarkdown(String input) {
    final rawMatches = <(int, int, int, int, FormatAttrs)>[];

    void collect(RegExp re, FormatAttrs attrs) {
      for (final m in re.allMatches(input)) {
        final group1 = m.group(1);
        if (group1 != null) {
          final groupStart = input.indexOf(group1, m.start);
          final groupEnd = groupStart + group1.length;
          rawMatches.add((m.start, m.end, groupStart, groupEnd, attrs));
        }
      }
    }

    // Order matters: ** before * to avoid partial match
    collect(RegExp(r'\*\*(.+?)\*\*'), FormatAttrs(bold: true));
    collect(RegExp(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)'),
        FormatAttrs(italic: true));
    collect(RegExp(r'//(.+?)//'), FormatAttrs(italic: true));
    collect(RegExp(r'__(.+?)__'), FormatAttrs(underline: true));
    collect(RegExp(r'~~(.+?)~~'), FormatAttrs(strikethrough: true));
    collect(
        RegExp(r'==(.+?)=='), FormatAttrs(highlight: const Color(0xFFFFFF00)));

    rawMatches.sort((a, b) => a.$1.compareTo(b.$1));

    final buf = StringBuffer();
    final formats = <FormatRange>[];
    int pos = 0;

    for (final m in rawMatches) {
      if (m.$1 < pos) continue; // skip overlapping
      buf.write(input.substring(pos, m.$1));
      final cleanStart = buf.length;
      buf.write(input.substring(m.$3, m.$4)); // content only
      formats.add(FormatRange(start: cleanStart, end: buf.length, attrs: m.$5));
      pos = m.$2;
    }
    buf.write(input.substring(pos));

    return (buf.toString(), formats);
  }

  List<EditorBlock> _parseMarkdownToBlocks(String text) {
    final blocks = <EditorBlock>[];
    final lines = text.split('\n');
    final currentText = StringBuffer();

    void flushText() {
      final t = currentText.toString().trim();
      if (t.isNotEmpty) {
        final (clean, fmts) = _parseInlineMarkdown(t);
        blocks.add(TextBlock(
            id: const Uuid().v4(),
            type: BlockType.text,
            text: clean,
            formats: fmts));
      }
      currentText.clear();
    }

    TextBlock inlineBlock(String raw, BlockType type) {
      final (clean, fmts) = _parseInlineMarkdown(raw);
      return TextBlock(
          id: const Uuid().v4(), type: type, text: clean, formats: fmts);
    }

    for (final line in lines) {
      if (line.startsWith('# ')) {
        flushText();
        blocks.add(inlineBlock(line.substring(2), BlockType.heading1));
      } else if (line.startsWith('## ')) {
        flushText();
        blocks.add(inlineBlock(line.substring(3), BlockType.heading2));
      } else if (line.startsWith('### ')) {
        flushText();
        blocks.add(inlineBlock(line.substring(4), BlockType.heading3));
      } else if (line.startsWith('> ')) {
        flushText();
        blocks.add(inlineBlock(line.substring(2), BlockType.quote));
      } else if (line.trim() == '---' || line.trim() == '***') {
        flushText();
        blocks.add(DividerBlock(id: const Uuid().v4()));
      } else if (line.startsWith('- [ ] ') ||
          line.startsWith('- [x] ') ||
          line.startsWith('- [X] ')) {
        flushText();
        final isChecked = !line.startsWith('- [ ] ');
        blocks.add(ChecklistBlock(
            id: const Uuid().v4(),
            text: line.substring(6),
            isChecked: isChecked));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        flushText();
        final (clean, fmts) = _parseInlineMarkdown(line.substring(2));
        blocks.add(TextBlock(
            id: const Uuid().v4(),
            type: BlockType.bulletList,
            text: clean,
            formats: fmts));
      } else {
        if (currentText.isNotEmpty) currentText.write('\n');
        currentText.write(line);
      }
    }
    flushText();
    if (blocks.isEmpty) blocks.add(TextBlock.empty());
    return blocks;
  }

  double _fontSizeForType(BlockType type) {
    switch (type) {
      case BlockType.heading1:
        return 32;
      case BlockType.heading2:
        return 26;
      case BlockType.heading3:
        return 22;
      default:
        return 18;
    }
  }

  // ── Block operations ───────────────────────────────────────────────────────

  void insertBlockAfter(String afterId, EditorBlock newBlock) {
    setState(() {
      final idx = _blocks.indexWhere((b) => b.id == afterId);
      final insertAt = idx == -1 ? _blocks.length : idx + 1;
      _blocks.insert(insertAt, newBlock);
      if (newBlock is TextBlock) _ensureController(newBlock);
    });
    widget.onBlocksChanged(_blocks);
    // Focus the new block after next frame
    if (newBlock is TextBlock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[newBlock.id]?.requestFocus();
      });
    }
  }

  void removeBlock(String blockId) {
    setState(() {
      _blocks.removeWhere((b) => b.id == blockId);
      _controllers.remove(blockId)?.dispose();
      _focusNodes.remove(blockId)?.dispose();
      if (_focusedBlockId == blockId) _focusedBlockId = null;
    });
    widget.onBlocksChanged(_blocks);
  }

  void updateBlock(EditorBlock updated) {
    setState(() {
      final idx = _blocks.indexWhere((b) => b.id == updated.id);
      if (idx != -1) _blocks[idx] = updated;
    });
    widget.onBlocksChanged(_blocks);
  }

  void insertImageBlock(String afterId, String imagePath) {
    final block = ImageBlock(
      id: const Uuid().v4(),
      path: imagePath,
    );
    insertBlockAfter(afterId, block);
    // Insert a new empty text block after the image
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final emptyText = TextBlock.empty();
      insertBlockAfter(block.id, emptyText);
    });
  }

  void insertYoutubeBlock(String afterId, String url) {
    final videoId = YoutubeBlock.extractVideoId(url);
    if (videoId == null) return;
    final block = YoutubeBlock(
      id: const Uuid().v4(),
      url: url,
      videoId: videoId,
    );
    insertBlockAfter(afterId, block);
    final emptyText = TextBlock.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      insertBlockAfter(block.id, emptyText);
    });
  }

  void insertTweetBlock(String afterId, String url) {
    final tweetId = TweetBlock.extractTweetId(url);
    final block = TweetBlock(
      id: const Uuid().v4(),
      url: url,
      tweetId: tweetId,
      displayText: url,
    );
    insertBlockAfter(afterId, block);
    final emptyText = TextBlock.empty();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      insertBlockAfter(block.id, emptyText);
    });
  }

  void insertDivider(String afterId) {
    insertBlockAfter(afterId, DividerBlock(id: const Uuid().v4()));
  }

  void insertCodeBlock(String afterId) {
    insertBlockAfter(afterId, CodeBlock(id: const Uuid().v4(), code: ''));
  }

  /// Inserts a new empty ChecklistBlock after [afterId].
  void insertChecklistBlock(String afterId) {
    final block = ChecklistBlock.empty();
    _pendingFocus.add(block.id);
    insertBlockAfter(afterId, block);
  }

  void changeBlockType(String blockId, BlockType newType) {
    final idx = _blocks.indexWhere((b) => b.id == blockId);
    if (idx == -1) return;
    final block = _blocks[idx];
    if (block is TextBlock) {
      final updated = block.copyWith(type: newType);
      setState(() => _blocks[idx] = updated);
      widget.onBlocksChanged(_blocks);
    }
  }

  // ── Toolbar callbacks ──────────────────────────────────────────────────────

  RichEditorController? get focusedController =>
      _focusedBlockId != null ? _controllers[_focusedBlockId] : null;

  String? get focusedBlockId => _focusedBlockId;

  void applyHighlight(Color color) => focusedController?.applyHighlight(color);
  void clearHighlight() => focusedController?.clearHighlight();
  void applyLink(String url) => focusedController?.applyLink(url);
  void clearLink() => focusedController?.clearLink();
  void setTextAlignment(String alignment) {
    setState(() {
      textAlignment = alignment;
    });
    // Notify parent so alignment is persisted to the entry
    widget.onBlocksChanged(_blocks);
  }

  // ── Image insertion ────────────────────────────────────────────────────────

  Future<void> pickAndInsertImage(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.ensurePhotos(context);
    if (!hasPermission || !context.mounted) return;

    final path = await ImageService.instance.pickInlineImage(context);
    if (path == null) return;

    final insertAfterId = _focusedBlockId ?? _blocks.last.id;
    insertImageBlock(insertAfterId, path);
  }

  Future<void> pickAndInsertImageGrid(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.ensurePhotos(context);
    if (!hasPermission || !context.mounted) return;

    // Pick multiple images (pick one at a time for now)
    final paths = <String>[];
    for (int i = 0; i < 4; i++) {
      if (!context.mounted) break;
      final path = await ImageService.instance.pickInlineImage(context);
      if (path == null) break;
      paths.add(path);
      if (i < 3 && context.mounted) {
        final cont = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Add another image?'),
            content: Text('${paths.length} image(s) selected'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Done'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add more'),
              ),
            ],
          ),
        );
        if (cont != true) break;
      }
    }

    if (paths.isEmpty) return;
    if (paths.length == 1) {
      final insertAfterId = _focusedBlockId ?? _blocks.last.id;
      insertImageBlock(insertAfterId, paths.first);
      return;
    }

    final block = ImageGridBlock(id: const Uuid().v4(), paths: paths);
    final insertAfterId = _focusedBlockId ?? _blocks.last.id;
    insertBlockAfter(insertAfterId, block);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      insertBlockAfter(block.id, TextBlock.empty());
    });
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return GestureDetector(
      // Tapping below last block creates new block
      onTap: () {
        if (_focusedBlockId == null && _blocks.isNotEmpty) {
          final lastBlock = _blocks.last;
          if (lastBlock is! TextBlock) {
            insertBlockAfter(lastBlock.id, TextBlock.empty());
          } else {
            _focusNodes[lastBlock.id]?.requestFocus();
          }
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._blocks.asMap().entries.map((entry) {
            final idx = entry.key;
            final block = entry.value;
            return _buildBlock(block, idx, textColor, mutedColor);
          }),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildBlock(
      EditorBlock block, int idx, Color textColor, Color mutedColor) {
    // ── Reflection header (pinned, non-removable) ─────────────────────────
    if (block is ReflectionHeaderBlock) {
      return _ReflectionHeaderWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
      );
    }
    // ── Checklist block ───────────────────────────────────────────────────
    if (block is ChecklistBlock) {
      return _ChecklistBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        autoFocus: _pendingFocus.remove(block.id),
        onToggle: (isChecked) =>
            updateBlock(block.copyWith(isChecked: isChecked)),
        onTextChanged: (text) => updateBlock(block.copyWith(text: text)),
        onRemove: () => removeBlock(block.id),
        onEnterAtEnd: () => insertChecklistBlock(block.id),
        onBackspaceAtEmpty: () {
          if (block.text.isEmpty) removeBlock(block.id);
        },
      );
    } else if (block is TextBlock) {
      return _TextBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        controller: _controllers[block.id]!,
        focusNode: _focusNodes[block.id]!,
        isDark: widget.isDark,
        textColor: textColor,
        mutedColor: mutedColor,
        isFirst: idx == 0,
        textAlignment: textAlignment,
        fontName: widget.fontName,
        onEnterAtEnd: () {
          // Continue bullet list on Enter; otherwise plain text
          if (block.type == BlockType.bulletList) {
            insertBlockAfter(
                block.id, TextBlock.empty(type: BlockType.bulletList));
          } else {
            insertBlockAfter(block.id, TextBlock.empty());
          }
        },
        onBackspaceAtStart: () {
          // Merge with previous block if it's text
          if (idx > 0 && _blocks[idx - 1] is TextBlock) {
            final prev = _blocks[idx - 1] as TextBlock;
            final prevCtrl = _controllers[prev.id]!;
            final mergedText = prevCtrl.text + block.text;
            final prevLen = prevCtrl.text.length;
            // Shift current block formats by prev length
            final shiftedFormats = block.formats
                .map((f) => FormatRange(
                      start: f.start + prevLen,
                      end: f.end + prevLen,
                      attrs: f.attrs,
                    ))
                .toList();

            prevCtrl.setFormatsAndText(mergedText, shiftedFormats);

            // Move cursor to merge point
            prevCtrl.selection = TextSelection.collapsed(offset: prevLen);

            removeBlock(block.id);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusNodes[prev.id]?.requestFocus();
            });
          } else if (_blocks.length > 1 && block.text.isEmpty) {
            removeBlock(block.id);
            // Focus previous block
            if (idx > 0) {
              final prevId = _blocks[idx > 0 ? idx - 1 : 0].id;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _focusNodes[prevId]?.requestFocus();
              });
            }
          }
        },
      );
    } else if (block is ImageBlock) {
      return _ImageBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        onRemove: () => removeBlock(block.id),
        onCaptionChanged: (caption) {
          updateBlock(block.copyWith(caption: caption));
        },
      );
    } else if (block is ImageGridBlock) {
      return _ImageGridBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        onRemove: () => removeBlock(block.id),
      );
    } else if (block is YoutubeBlock) {
      return _YoutubeBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        onRemove: () => removeBlock(block.id),
      );
    } else if (block is TweetBlock) {
      return _TweetBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        onRemove: () => removeBlock(block.id),
      );
    } else if (block is CodeBlock) {
      return _CodeBlockWidget(
        key: ValueKey('block_${block.id}'),
        block: block,
        isDark: widget.isDark,
        isEditing: true,
        onChanged: (code) => updateBlock(block.copyWith(code: code)),
        onRemove: () => removeBlock(block.id),
      );
    } else if (block is DividerBlock) {
      return _DividerBlockWidget(
        key: ValueKey('block_${block.id}'),
        isDark: widget.isDark,
        isEditing: true,
        onRemove: () => removeBlock(block.id),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BLOCK WIDGETS (Read + Edit modes)
// ─────────────────────────────────────────────────────────────────────────────

// ── Text block ────────────────────────────────────────────────────────────────

class _TextBlockWidget extends StatelessWidget {
  final TextBlock block;
  final RichEditorController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color textColor;
  final Color mutedColor;
  final bool isFirst;
  final VoidCallback onEnterAtEnd;
  final VoidCallback onBackspaceAtStart;
  final String textAlignment;
  final String fontName;

  const _TextBlockWidget({
    super.key,
    required this.block,
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.textColor,
    required this.mutedColor,
    required this.isFirst,
    required this.onEnterAtEnd,
    required this.onBackspaceAtStart,
    required this.textAlignment,
    this.fontName = 'crimsonPro',
  });

  @override
  Widget build(BuildContext context) {
    final isHeading = block.type == BlockType.heading1 ||
        block.type == BlockType.heading2 ||
        block.type == BlockType.heading3;
    final isQuote = block.type == BlockType.quote;

    Widget field = TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlign: _alignFromString(textAlignment),
      style: _styleForType(block.type, textColor),
      decoration: InputDecoration(
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        fillColor: Colors.transparent,
        filled: true,
        hintText: _hintForType(block.type),
        hintStyle: _styleForType(block.type, mutedColor.withOpacity(0.5))
            .copyWith(fontStyle: FontStyle.italic),
        isDense: true,
      ),
      onChanged: (val) {
        // Backspace at start check
        if (val.isEmpty && controller.selection.baseOffset == 0) {
          onBackspaceAtStart();
        }
      },
    );

    if (isQuote) {
      field = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blockquoteBg,
          border: Border(
            left: BorderSide(
              color: AppColors.blockquoteBorder,
              width: 4,
            ),
          ),
        ),
        child: field,
      );
    }

    // Bullet list — prefix with bullet point
    if (block.type == BlockType.bulletList) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 10),
              child: Text('•',
                  style: AppTypography.bodyTextFor(fontName, textColor,
                      size: 18, height: 1.8)),
            ),
            Expanded(child: field),
          ],
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(
        bottom: isHeading ? 4 : 2,
        top: isHeading ? 12 : 2,
      ),
      child: field,
    );
  }

  TextStyle _styleForType(BlockType type, Color color) {
    switch (type) {
      case BlockType.heading1:
        return GoogleFonts.crimsonPro(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2);
      case BlockType.heading2:
        return GoogleFonts.crimsonPro(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.25);
      case BlockType.heading3:
        return GoogleFonts.crimsonPro(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.3);
      case BlockType.quote:
        return GoogleFonts.crimsonPro(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: color,
            height: 1.8);
      default:
        return AppTypography.bodyTextFor(fontName, color,
            size: 18, height: 1.8);
    }
  }

  String _hintForType(BlockType type) {
    switch (type) {
      case BlockType.heading1:
        return 'Heading 1';
      case BlockType.heading2:
        return 'Heading 2';
      case BlockType.heading3:
        return 'Heading 3';
      case BlockType.quote:
        return 'Quote...';
      default:
        return 'Write here...';
    }
  }

  TextAlign _alignFromString(String alignment) {
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'justify':
      default:
        return TextAlign.justify;
    }
  }
}

// ── Image block ───────────────────────────────────────────────────────────────

class _ImageBlockWidget extends StatelessWidget {
  final ImageBlock block;
  final bool isDark;
  final bool isEditing;
  final VoidCallback? onRemove;
  final ValueChanged<String>? onCaptionChanged;

  const _ImageBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    required this.isEditing,
    this.onRemove,
    this.onCaptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(block.path);
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: file.existsSync()
                    ? Image.file(
                        file,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              if (isEditing && onRemove != null)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          if (block.caption != null && block.caption!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              block.caption!,
              style: GoogleFonts.inter(
                  fontSize: 12, color: mutedColor, fontStyle: FontStyle.italic),
            ),
          ],
          if (block.unsplashCredit != null) ...[
            const SizedBox(height: 4),
            Text(
              'Photo: ${block.unsplashCredit}',
              style: GoogleFonts.inter(
                  fontSize: 10, color: mutedColor.withOpacity(0.6)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2218) : const Color(0xFFECE9E3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.broken_image_outlined, size: 48),
      );
}

// ── Image grid block ──────────────────────────────────────────────────────────

class _ImageGridBlockWidget extends StatelessWidget {
  final ImageGridBlock block;
  final bool isDark;
  final bool isEditing;
  final VoidCallback? onRemove;

  const _ImageGridBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    required this.isEditing,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          GridView.count(
            crossAxisCount: block.columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: block.paths.map((path) {
              final file = File(path);
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: file.existsSync()
                    ? Image.file(file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                              color: isDark
                                  ? const Color(0xFF2A2218)
                                  : const Color(0xFFECE9E3),
                            ))
                    : Container(
                        color: isDark
                            ? const Color(0xFF2A2218)
                            : const Color(0xFFECE9E3),
                      ),
              );
            }).toList(),
          ),
          if (isEditing && onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── YouTube block ─────────────────────────────────────────────────────────────

class _YoutubeBlockWidget extends StatelessWidget {
  final YoutubeBlock block;
  final bool isDark;
  final bool isEditing;
  final VoidCallback? onRemove;

  const _YoutubeBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    required this.isEditing,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(block.url);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    block.thumbnailUrl,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 200,
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.play_circle_outline,
                          size: 64, color: Colors.white54),
                    ),
                  ),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        size: 40, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (isEditing && onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tweet block ───────────────────────────────────────────────────────────────

class _TweetBlockWidget extends StatelessWidget {
  final TweetBlock block;
  final bool isDark;
  final bool isEditing;
  final VoidCallback? onRemove;

  const _TweetBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    required this.isEditing,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF15202B) : const Color(0xFFF7F9F9);
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Stack(
        children: [
          GestureDetector(
            onTap: () async {
              final uri = Uri.parse(block.url);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.link, color: const Color(0xFF1DA1F2), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Post on X (Twitter)',
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: textColor)),
                        const SizedBox(height: 2),
                        Text(block.url,
                            style: GoogleFonts.inter(
                                fontSize: 11, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new, size: 16, color: mutedColor),
                ],
              ),
            ),
          ),
          if (isEditing && onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Code block ────────────────────────────────────────────────────────────────

class _CodeBlockWidget extends StatefulWidget {
  final CodeBlock block;
  final bool isDark;
  final bool isEditing;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onRemove;

  const _CodeBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    required this.isEditing,
    this.onChanged,
    this.onRemove,
  });

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.code);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final codeBg = widget.isDark ? AppColors.codeBgDark : AppColors.codeBgLight;
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: codeBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: widget.isEditing
                ? TextField(
                    controller: _ctrl,
                    maxLines: null,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, color: textColor, height: 1.6),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '// code here...',
                      isDense: true,
                    ),
                    onChanged: widget.onChanged,
                  )
                : Text(
                    widget.block.code,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13, color: textColor, height: 1.6),
                  ),
          ),
          if (widget.isEditing && widget.onRemove != null)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Checklist block widget (editing) ─────────────────────────────────────────

class _ChecklistBlockWidget extends StatefulWidget {
  final ChecklistBlock block;
  final bool isDark;
  final bool isEditing;
  final bool autoFocus;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String>? onTextChanged;
  final VoidCallback? onRemove;
  final VoidCallback? onEnterAtEnd;
  final VoidCallback? onBackspaceAtEmpty;

  const _ChecklistBlockWidget({
    super.key,
    required this.block,
    required this.isDark,
    this.isEditing = false,
    this.autoFocus = false,
    this.onToggle,
    this.onTextChanged,
    this.onRemove,
    this.onEnterAtEnd,
    this.onBackspaceAtEmpty,
  });

  @override
  State<_ChecklistBlockWidget> createState() => _ChecklistBlockWidgetState();
}

class _ChecklistBlockWidgetState extends State<_ChecklistBlockWidget> {
  late TextEditingController _ctrl;
  late FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.block.text);
    _focus = FocusNode();
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(_ChecklistBlockWidget old) {
    super.didUpdateWidget(old);
    // Sync text if parent changed it (e.g. restore from version)
    if (old.block.text != widget.block.text &&
        _ctrl.text != widget.block.text) {
      _ctrl.text = widget.block.text;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final checked = widget.block.isChecked;
    final fade = widget.block.shouldFade;

    return AnimatedOpacity(
      opacity: fade ? 0.3 : 1.0,
      duration: const Duration(milliseconds: 600),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Checkbox
            GestureDetector(
              onTap: () => widget.onToggle?.call(!checked),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(right: 12, top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: checked ? AppColors.aqua : Colors.transparent,
                  border: Border.all(
                    color:
                        checked ? AppColors.aqua : mutedColor.withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
                child: checked
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ),
            // Text field
            Expanded(
              child: widget.isEditing
                  ? TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      maxLines: null,
                      textInputAction: TextInputAction.done,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color:
                            checked ? mutedColor.withOpacity(0.5) : textColor,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        decorationColor: mutedColor,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                        hintText: 'Task...',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 16,
                          color: mutedColor.withOpacity(0.35),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      onChanged: (val) {
                        widget.onTextChanged?.call(val);
                        if (val.isEmpty) widget.onBackspaceAtEmpty?.call();
                      },
                      onSubmitted: (_) => widget.onEnterAtEnd?.call(),
                    )
                  : Text(
                      widget.block.text,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color:
                            checked ? mutedColor.withOpacity(0.5) : textColor,
                        decoration: checked ? TextDecoration.lineThrough : null,
                        decorationColor: mutedColor,
                        height: 1.5,
                      ),
                    ),
            ),
            if (widget.isEditing && widget.onRemove != null)
              GestureDetector(
                onTap: widget.onRemove,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: mutedColor.withOpacity(0.35),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Checklist read view (interactive local state, no persistence) ─────────────

class _ChecklistReadView extends StatefulWidget {
  final ChecklistBlock block;
  final bool isDark;
  const _ChecklistReadView({required this.block, required this.isDark});

  @override
  State<_ChecklistReadView> createState() => _ChecklistReadViewState();
}

class _ChecklistReadViewState extends State<_ChecklistReadView> {
  late bool _checked;

  @override
  void initState() {
    super.initState();
    _checked = widget.block.isChecked;
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor =
        widget.isDark ? AppColors.mutedDark : AppColors.mutedLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _checked = !_checked),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(right: 12, top: 1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _checked ? AppColors.aqua : Colors.transparent,
                border: Border.all(
                  color:
                      _checked ? AppColors.aqua : mutedColor.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: _checked
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : null,
            ),
          ),
          Expanded(
            child: Text(
              widget.block.text,
              style: GoogleFonts.inter(
                fontSize: 16,
                color: _checked ? mutedColor.withOpacity(0.5) : textColor,
                decoration: _checked ? TextDecoration.lineThrough : null,
                decorationColor: mutedColor,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider block ─────────────────────────────────────────────────────────────

class _DividerBlockWidget extends StatelessWidget {
  final bool isDark;
  final bool isEditing;
  final VoidCallback? onRemove;

  const _DividerBlockWidget({
    super.key,
    required this.isDark,
    required this.isEditing,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            thickness: 1,
          ),
          if (isEditing && onRemove != null)
            Positioned(
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.warmDark : AppColors.warmWhite,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                    ),
                  ),
                  child: Icon(
                    Icons.close,
                    size: 12,
                    color: isDark ? AppColors.mutedDark : AppColors.mutedLight,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READ-ONLY BLOCK RENDERER
// Used by EntryContent to render blocks without editing controls.
// ─────────────────────────────────────────────────────────────────────────────

class BlocksReadView extends StatelessWidget {
  final List<EditorBlock> blocks;
  final bool isDark;
  final String textAlignment;
  final String fontName;

  const BlocksReadView({
    super.key,
    required this.blocks,
    required this.isDark,
    this.textAlignment = 'justify',
    this.fontName = 'crimsonPro',
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('[BlocksReadView] Building with ${blocks.length} blocks');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: blocks.map((b) => _buildBlock(b)).toList(),
    );
  }

  Widget _buildBlock(EditorBlock block) {
    debugPrint('[BlocksReadView] Building block type: ${block.type}');
    if (block is ReflectionHeaderBlock) {
      return _ReflectionHeaderWidget(block: block, isDark: isDark);
    }
    if (block is ChecklistBlock) {
      return _ChecklistReadView(block: block, isDark: isDark);
    } else if (block is TextBlock) {
      debugPrint('[BlocksReadView] TextBlock text: "${block.text}"');
      return _TextBlockReadView(
          block: block,
          isDark: isDark,
          textAlignment: textAlignment,
          fontName: fontName);
    } else if (block is ImageBlock) {
      return _ImageBlockWidget(block: block, isDark: isDark, isEditing: false);
    } else if (block is ImageGridBlock) {
      return _ImageGridBlockWidget(
          block: block, isDark: isDark, isEditing: false);
    } else if (block is YoutubeBlock) {
      return _YoutubeBlockWidget(
          block: block, isDark: isDark, isEditing: false);
    } else if (block is TweetBlock) {
      return _TweetBlockWidget(block: block, isDark: isDark, isEditing: false);
    } else if (block is CodeBlock) {
      return _CodeBlockWidget(block: block, isDark: isDark, isEditing: false);
    } else if (block is DividerBlock) {
      return _DividerBlockWidget(isDark: isDark, isEditing: false);
    }
    debugPrint(
        '[BlocksReadView] Unknown block type, returning SizedBox.shrink');
    return const SizedBox.shrink();
  }
}

class _TextBlockReadView extends StatelessWidget {
  final TextBlock block;
  final bool isDark;
  final String textAlignment;
  final String fontName;

  const _TextBlockReadView({
    required this.block,
    required this.isDark,
    required this.textAlignment,
    this.fontName = 'crimsonPro',
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;

    final span = _buildSpan(textColor);
    // Bullet list — prefix with bullet point
    if (block.type == BlockType.bulletList) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 2, top: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 10),
              child: Text('•', style: _styleForType(BlockType.text, textColor)),
            ),
            Expanded(
              child:
                  Text.rich(span, textAlign: _alignFromString(textAlignment)),
            ),
          ],
        ),
      );
    }

    Widget text = Text.rich(
      span,
      textAlign: _alignFromString(textAlignment),
    );

    if (block.type == BlockType.quote) {
      text = Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.blockquoteBg,
          border: Border(
            left: BorderSide(color: AppColors.blockquoteBorder, width: 4),
          ),
        ),
        child: text,
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: _isHeading ? 4 : 2,
        top: _isHeading ? 12 : 2,
      ),
      child: text,
    );
  }

  bool get _isHeading =>
      block.type == BlockType.heading1 ||
      block.type == BlockType.heading2 ||
      block.type == BlockType.heading3;

  TextSpan _buildSpan(Color textColor) {
    final baseStyle = _styleForType(block.type, textColor);
    final t = block.text;
    if (block.formats.isEmpty) return TextSpan(text: t, style: baseStyle);

    final breakpoints = <int>{0, t.length};
    for (final fmt in block.formats) {
      breakpoints.add(fmt.start.clamp(0, t.length));
      breakpoints.add(fmt.end.clamp(0, t.length));
    }
    final sorted = breakpoints.toList()..sort();
    final spans = <InlineSpan>[];

    for (int i = 0; i < sorted.length - 1; i++) {
      final start = sorted[i];
      final end = sorted[i + 1];
      if (start >= end) continue;

      bool bold = false, italic = false, underline = false, strike = false;
      Color? highlight;
      String? link;

      for (final fmt in block.formats) {
        if (fmt.start <= start && start < fmt.end) {
          if (fmt.attrs.bold) bold = true;
          if (fmt.attrs.italic) italic = true;
          if (fmt.attrs.underline) underline = true;
          if (fmt.attrs.strikethrough) strike = true;
          highlight ??= fmt.attrs.highlight;
          link ??= fmt.attrs.link;
        }
      }

      var style = baseStyle;
      if (bold) style = style.copyWith(fontWeight: FontWeight.w700);
      if (italic) style = style.copyWith(fontStyle: FontStyle.italic);
      final decos = <TextDecoration>[];
      if (underline) decos.add(TextDecoration.underline);
      if (strike) decos.add(TextDecoration.lineThrough);
      if (decos.isNotEmpty) {
        style = style.copyWith(decoration: TextDecoration.combine(decos));
      }
      if (highlight != null) {
        style = style.copyWith(backgroundColor: highlight.withOpacity(0.35));
      }
      if (link != null) {
        style = style.copyWith(
            color: AppColors.aqua,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.aqua);
      }

      spans.add(TextSpan(text: t.substring(start, end), style: style));
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  TextStyle _styleForType(BlockType type, Color color) {
    switch (type) {
      case BlockType.heading1:
        return GoogleFonts.crimsonPro(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: color,
            height: 1.2);
      case BlockType.heading2:
        return GoogleFonts.crimsonPro(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.25);
      case BlockType.heading3:
        return GoogleFonts.crimsonPro(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: color,
            height: 1.3);
      case BlockType.quote:
        return GoogleFonts.crimsonPro(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: color,
            height: 1.8);
      default:
        return AppTypography.bodyTextFor(fontName, color,
            size: 18, height: 1.8);
    }
  }

  TextAlign _alignFromString(String alignment) {
    switch (alignment) {
      case 'left':
        return TextAlign.left;
      case 'center':
        return TextAlign.center;
      case 'justify':
      default:
        return TextAlign.justify;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REFLECTION HEADER WIDGET
// Pinned "Reflection on" card — non-removable in both edit and read modes.
// ─────────────────────────────────────────────────────────────────────────────

class _ReflectionHeaderWidget extends StatelessWidget {
  final ReflectionHeaderBlock block;
  final bool isDark;

  const _ReflectionHeaderWidget({super.key, required this.block, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final cardBg =
        isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03);
    final borderColor =
        isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.07);
    final hasImage = block.originHeaderImage != null &&
        block.originHeaderImage!.isNotEmpty &&
        File(block.originHeaderImage!).existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          'Reflection on',
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: mutedColor,
              letterSpacing: 0.3),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor)),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: hasImage
                    ? Image.file(File(block.originHeaderImage!), fit: BoxFit.cover)
                    : Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFF0D1A28), Color(0xFF1A3045)]),
                        ),
                        child: const Icon(Icons.auto_stories_outlined,
                            color: Colors.white30, size: 22),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  block.originTitle.isEmpty ? 'Untitled' : block.originTitle,
                  style: GoogleFonts.crimsonPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.2),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text('by ${block.originAuthor}',
                    style: GoogleFonts.inter(fontSize: 11, color: mutedColor)),
                if (block.originExcerpt != null &&
                    block.originExcerpt!.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    '"${block.originExcerpt}"',
                    style: GoogleFonts.crimsonPro(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: mutedColor,
                        height: 1.45),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ]),
            ),
          ]),
        ),
        if (block.inspirationTitle != null && block.inspirationTitle!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Inspired by ${block.inspirationAuthor ?? "someone"}\'s reflection',
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.aqua, fontStyle: FontStyle.italic),
          ),
        ],
      ]),
    );
  }
}