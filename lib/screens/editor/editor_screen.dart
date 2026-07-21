import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/entry.dart';
import '../../providers/app_state.dart';
import '../../providers/editor_state.dart';
import '../../providers/atmosphere_state.dart';
import '../../theme/app_colors.dart';
import '../../atmosphere/comfort_engine.dart';
import 'editor_app_bar.dart';
import 'editor_header_image.dart';
import 'editor_title_field.dart';
import 'editor_body_field.dart';
import 'editor_toolbar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR SCREEN
// Full editing environment. Accessed only via double-tap in Read-Only mode.
//
// CRITICAL rules (Master Specification §4):
//   - Back chevron returns to Read-Only — NOT to Story Panel
//   - Auto-save: debounced 1200ms after last keystroke
//   - Session timer starts on mount, stops on pop, adds to entry.timeSpentSeconds
//   - Comfort engine is active — trigger words shift background over 50s
//   - Returns updated Entry to Read-Only via Navigator.pop(updatedEntry)
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
  late TextEditingController _bodyController;
  final FocusNode _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
    _titleController = TextEditingController(text: _entry.title);
    _bodyController = TextEditingController(text: _entry.content);

    final editorState = context.read<EditorState>();
    final atmoState = context.read<AtmosphereState>();

    // Wire comfort mode upstream
    editorState.bindAtmosphere(atmoState);

    // Wire auto-save
    editorState.onAutoSave = _performSave;

    // Start session timer (Proof of Work)
    editorState.startSession();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _performSave() async {
    if (!mounted) return;
    final appState = context.read<AppState>();
    _entry = _entry.copyWith(
      title: _titleController.text.trim(),
      content: _bodyController.text,
      updatedAt: DateTime.now(),
    );
    await appState.saveEntry(_entry);
  }

  // ── Back (to Read-Only, NOT to Story Panel) ────────────────────────────────

  Future<void> _handleBack() async {
    final editorState = context.read<EditorState>();

    // Flush any pending auto-save
    editorState.flushSave();
    await _performSave();

    // Add session time to DB
    final seconds = editorState.stopSession();
    if (seconds > 0) {
      await context.read<AppState>().addEntryTimeSpent(_entry.id, seconds);
      _entry = _entry.copyWith(
        timeSpentSeconds: _entry.timeSpentSeconds + seconds,
      );
    }

    editorState.reset();

    if (mounted) {
      // Return updated entry to Read-Only screen
      Navigator.of(context).pop(_entry);
    }
  }

  // ── Image handling ─────────────────────────────────────────────────────────

  void _onHeaderImageChanged(String? path) {
    if (!mounted) return;
    setState(() {
      _entry = path == null
          ? _entry.copyWith(clearHeaderImage: true)
          : _entry.copyWith(headerImage: path);
    });
    _performSave();
  }

  void _onInlineImageInserted(String path, int cursorPosition) {
    if (!mounted) return;
    // Insert the image marker into the body text at cursor position
    final marker = '\uFFFC';
    final currentText = _bodyController.text;
    final newText = currentText.substring(0, cursorPosition) +
        marker +
        currentText.substring(cursorPosition);
    _bodyController.text = newText;

    // Add the image entry record
    final images = List.of(_entry.images);
    images.add(EntryImage(path: path, position: cursorPosition));
    images.sort((a, b) => a.position.compareTo(b.position));
    setState(() => _entry = _entry.copyWith(images: images));
    _performSave();
  }

  void _onInlineImageRemoved(String path) {
    if (!mounted) return;
    final images = _entry.images.where((img) => img.path != path).toList();

    // Remove the marker from body text
    final marker = '\uFFFC';
    final currentText = _bodyController.text;
    final markerPos = currentText.indexOf(marker);
    if (markerPos != -1) {
      _bodyController.text =
          currentText.substring(0, markerPos) + currentText.substring(markerPos + 1);
    }

    setState(() => _entry = _entry.copyWith(images: images));
    _performSave();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: bg,
        body: Stack(
          children: [
            // ── Main editor column ────────────────────────────────────────
            Column(
              children: [
                // App bar: back chevron, "Read" preview, "..." menu
                EditorAppBar(
                  entry: _entry,
                  onBack: _handleBack,
                  onEntryChanged: (e) => setState(() => _entry = e),
                ),

                // Scrollable content area
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Header image area
                      SliverToBoxAdapter(
                        child: EditorHeaderImage(
                          currentPath: _entry.headerImage,
                          onImageChanged: _onHeaderImageChanged,
                        ),
                      ),

                      // Title field
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                          child: EditorTitleField(
                            controller: _titleController,
                            entry: _entry,
                            onDateChanged: (date) {
                              // Date customisation handled inside EditorTitleField
                            },
                          ),
                        ),
                      ),

                      // Body field with inline images
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
                          child: EditorBodyField(
                            controller: _bodyController,
                            focusNode: _bodyFocus,
                            entry: _entry,
                            onImageRemoved: _onInlineImageRemoved,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Markdown toolbar pinned to bottom
                EditorToolbar(
                  bodyController: _bodyController,
                  bodyFocus: _bodyFocus,
                  onImageInserted: _onInlineImageInserted,
                ),
              ],
            ),

            // ── Comfort engine overlays ───────────────────────────────────
            const ComfortWhisperOverlay(),
            const ComfortTintOverlay(),
          ],
        ),
      ),
    );
  }
}