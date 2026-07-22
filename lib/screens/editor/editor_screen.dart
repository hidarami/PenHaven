import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/editor_block.dart';
import '../../models/entry.dart';
import '../../models/entry_version.dart';
import '../../providers/app_state.dart';
import '../../providers/editor_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../data/version_dao.dart';
import '../../theme/app_colors.dart';
import '../../atmosphere/comfort_engine.dart';
import '../../services/export_service.dart';
import 'editor_app_bar.dart';
import 'editor_header_image.dart';
import 'editor_title_field.dart';
import 'editor_canvas.dart';
import 'wysiwyg_toolbar.dart';
import 'version_history_screen.dart';
import 'export_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR SCREEN — Block-based WYSIWYG
// Images are standalone blocks — no U+FFFC bugs possible.
// All formatting is WYSIWYG via RichEditorController per text block.
// ─────────────────────────────────────────────────────────────────────────────

class EditorScreen extends StatefulWidget {
  final Entry entry;

  const EditorScreen({super.key, required this.entry});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late Entry _entry;
  late TextEditingController _titleController;
  late List<EditorBlock> _blocks;
  final GlobalKey<EditorCanvasState> _canvasKey = GlobalKey();
  // _socialCardRepaintKey removed — export now uses ExportSheet

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _titleController = TextEditingController(text: _entry.title);

    // Initialise blocks from blocksJson or migrate from legacy content
    if (_entry.blocksJson != null && _entry.blocksJson!.isNotEmpty) {
      _blocks = deserializeBlocks(_entry.blocksJson!);
    } else {
      _blocks = blocksFromLegacy(_entry.content, _entry.images);
    }
    if (_blocks.isEmpty) _blocks = [TextBlock.empty()];

    final editorState = context.read<EditorState>();
    final atmoState = context.read<AtmosphereState>();
    editorState.bindAtmosphere(atmoState);
    editorState.onAutoSave = _performSave;
    editorState.startSession();
    // Force rebuild after first frame so _canvasKey.currentState is populated
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _performSave() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    final blocksJson = serializeBlocks(_blocks);
    final plainText = plainTextFromBlocks(_blocks);

    _entry = _entry.copyWith(
      title: _titleController.text.trim(),
      content: plainText,
      blocksJson: blocksJson,
      updatedAt: DateTime.now(),
    );
    await appState.saveEntry(_entry);
  }

  // ── Auto-save with version snapshot ───────────────────────────────────────

  Future<void> _saveWithVersion() async {
    await _performSave();
    // Save a version snapshot
    final version = EntryVersion(
      entryId: _entry.id,
      title: _entry.title,
      blocksJson: serializeBlocks(_blocks),
      timeSpentSeconds: _entry.timeSpentSeconds,
    );
    await VersionDao.instance.saveVersion(version);
  }

  // ── Back ───────────────────────────────────────────────────────────────────

  Future<void> _handleBack() async {
    final editorState = context.read<EditorState>();
    editorState.flushSave();

    // Always try to save, but NEVER block navigation on failure
    try {
      await _saveWithVersion();
    } catch (e) {
      debugPrint('[EditorScreen] Save on back failed: $e');
    }

    final seconds = editorState.stopSession();
    try {
      if (seconds > 0 && mounted) {
        await context.read<AppState>().addEntryTimeSpent(_entry.id, seconds);
        _entry = _entry.copyWith(
            timeSpentSeconds: _entry.timeSpentSeconds + seconds);
      }
    } catch (e) {
      debugPrint('[EditorScreen] Time spent update failed: $e');
    }

    editorState.reset();
    // Always pop regardless of save success — user must never be trapped
    if (mounted) Navigator.of(context).pop(_entry);
  }

  // ── Header image ───────────────────────────────────────────────────────────

  void _onHeaderImageChanged((String?, String?) result) {
    if (!mounted) return;
    final (path, ratio) = result;
    setState(() {
      _entry = path == null
          ? _entry.copyWith(clearHeaderImage: true)
          : _entry.copyWith(headerImage: path, headerImageRatio: ratio);
    });
    _performSave();
  }

  // ── Block changes ──────────────────────────────────────────────────────────

  void _onBlocksChanged(List<EditorBlock> blocks) {
    _blocks = blocks;
    // Update text alignment from canvas
    final canvasState = _canvasKey.currentState;
    if (canvasState != null) {
      _entry = _entry.copyWith(textAlignment: canvasState.textAlignment);
    }
    // Trigger EditorState auto-save debounce
    context.read<EditorState>().onContentChanged(
        plainTextFromBlocks(blocks));
  }

  // ── Version history ────────────────────────────────────────────────────────

  void _openVersionHistory() {
    final dark = context.read<AppState>().isDarkMode;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VersionHistoryScreen(
          entryId: _entry.id,
          isDark: dark,
          onRestore: (version) {
            setState(() {
              _blocks = deserializeBlocks(version.blocksJson);
              _titleController.text = version.title;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Version restored.')),
            );
          },
        ),
      ),
    );
  }

  // ── Export options sheet ───────────────────────────────────────────────────

  Future<void> _exportAsImage() async {
    if (!mounted) return;
    final dark = context.read<AppState>().isDarkMode;
    await ExportSheet.show(context, _entry, dark);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final textColor = dark ? AppColors.textDark : AppColors.textLight;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                // App bar
                _EditorBar(
                  entry: _entry,
                  isDark: dark,
                  onBack: _handleBack,
                  onHistory: _openVersionHistory,
                  onEntryChanged: (e) => setState(() => _entry = e),
                  onImageExport: _exportAsImage,
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header image
                        EditorHeaderImage(
                          currentPath: _entry.headerImage,
                          onImageChanged: _onHeaderImageChanged,
                        ),

                        // Title + date
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: EditorTitleField(
                            controller: _titleController,
                            entry: _entry,
                            onDateChanged: (_) {},
                          ),
                        ),

                        // Block canvas
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: EditorCanvas(
                            key: _canvasKey,
                            initialBlocks: _blocks,
                            isDark: dark,
                            textAlignment: _entry.textAlignment,
                            onBlocksChanged: _onBlocksChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // WYSIWYG toolbar — always shown, canvas state resolves after first frame
                Builder(builder: (context) {
                  final canvasState = _canvasKey.currentState;
                  if (canvasState == null) {
                    return const SizedBox(height: 44);
                  }
                  return WysiwygToolbar(
                    canvas: canvasState,
                    onImageInsert: () async {
                      if (_canvasKey.currentState != null && mounted) {
                        await _canvasKey.currentState!
                            .pickAndInsertImage(context);
                      }
                    },
                    onImageGridInsert: () async {
                      if (_canvasKey.currentState != null && mounted) {
                        await _canvasKey.currentState!
                            .pickAndInsertImageGrid(context);
                      }
                    },
                  );
                }),
              ],
            ),

            // Comfort engine
            const ComfortWhisperOverlay(),
            const ComfortTintOverlay(),

            // Export view is rendered inside ExportSheet on demand
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR BAR
// Simpler top bar — keeps the existing EditorAppBar design but adds
// history button and removes word count (EditorState handles that).
// ─────────────────────────────────────────────────────────────────────────────

class _EditorBar extends StatelessWidget {
  final Entry entry;
  final bool isDark;
  final VoidCallback onBack;
  final VoidCallback onHistory;
  final ValueChanged<Entry> onEntryChanged;
  final VoidCallback? onImageExport;

  const _EditorBar({
    required this.entry,
    required this.isDark,
    required this.onBack,
    required this.onHistory,
    required this.onEntryChanged,
    this.onImageExport,
  });

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        isDark ? AppColors.mutedDark : AppColors.mutedLight;
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(8, topPadding + 4, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left_rounded,
                size: 28, color: mutedColor),
            onPressed: onBack,
          ),
          const Spacer(),
          // Version history
          IconButton(
            icon: Icon(Icons.history_rounded, size: 20, color: mutedColor),
            onPressed: onHistory,
            tooltip: 'Version history',
          ),
          // Overflow menu (reuse existing EditorAppBar logic)
          IconButton(
            icon:
                Icon(Icons.more_horiz, size: 22, color: mutedColor),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final appState = context.read<AppState>();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            // ── Export ────────────────────────────────────────────────────
            ListTile(
              leading: const Icon(Icons.ios_share_outlined),
              title: const Text('Share / Export'),
              subtitle: const Text('Image, PDF, or TXT'),
              onTap: () {
                Navigator.pop(ctx);
                onImageExport?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('Export as TXT'),
              onTap: () {
                Navigator.pop(ctx);
                ExportService.instance.exportAsTxt(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(ctx);
                ExportService.instance.exportAsPdf(entry);
              },
            ),
            const Divider(height: 1),
            // ── Manage ────────────────────────────────────────────────────
            if (entry.hasHeaderImage)
              ListTile(
                leading: const Icon(Icons.image_not_supported_outlined),
                title: const Text('Remove header image'),
                onTap: () {
                  Navigator.pop(ctx);
                  onEntryChanged(entry.copyWith(clearHeaderImage: true));
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              title: const Text('Delete entry',
                  style: TextStyle(color: AppColors.danger)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(context, appState);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState appState) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('This entry will be moved to the Bin.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deleteEntry(entry.id);
              if (context.mounted) {
                Navigator.of(context)
                  ..pop()
                  ..pop();
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}