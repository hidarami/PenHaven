import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/app_state.dart';
import '../../services/image_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR TOOLBAR
// Horizontal scrollable row pinned to the bottom of the editor.
// Buttons: B · I · H1 · H2 · H3 · " · 🎨 · 📷
//
// Each button either:
//   a) Wraps selected text with markdown syntax, OR
//   b) Inserts syntax at cursor position if no selection
//
// Image button:
//   1. Checks permission
//   2. Opens picker + crop
//   3. Calls onImageInserted(path, cursorPosition)
// ─────────────────────────────────────────────────────────────────────────────

class EditorToolbar extends StatelessWidget {
  final TextEditingController bodyController;
  final FocusNode bodyFocus;
  final void Function(String path, int cursorPosition) onImageInserted;

  const EditorToolbar({
    super.key,
    required this.bodyController,
    required this.bodyFocus,
    required this.onImageInserted,
  });

  // ── Markdown insertion helpers ─────────────────────────────────────────────

  void _wrapSelection(String prefix, [String? suffix]) {
    final ctrl = bodyController;
    final sel = ctrl.selection;
    if (!sel.isValid) return;

    final suf = suffix ?? prefix;
    final text = ctrl.text;
    final selected = sel.textInside(text);
    final replacement = '$prefix$selected$suf';

    ctrl.value = ctrl.value.replaced(sel, replacement);

    // Place cursor after inserted text
    final newOffset = sel.start + replacement.length;
    ctrl.selection = TextSelection.collapsed(offset: newOffset);
    bodyFocus.requestFocus();
  }

  void _insertAtCursor(String syntax) {
    final ctrl = bodyController;
    final sel = ctrl.selection;
    final pos = sel.isValid ? sel.start : ctrl.text.length;

    final newText =
        ctrl.text.substring(0, pos) + syntax + ctrl.text.substring(pos);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: pos + syntax.length),
    );
    bodyFocus.requestFocus();
  }

  // ── Image handling ─────────────────────────────────────────────────────────

  Future<void> _insertImage(BuildContext context) async {
    final hasPermission =
        await PermissionService.instance.ensurePhotos(context);
    if (!hasPermission || !context.mounted) return;

    final path = await ImageService.instance.pickInlineImage(context);
    if (path == null) return;

    // Cursor position = where image will appear in content
    final cursorPos = bodyController.selection.isValid
        ? bodyController.selection.start
        : bodyController.text.length;

    onImageInserted(path, cursorPos);
    bodyFocus.requestFocus();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<AppState>().isDarkMode;
    final bg = dark ? AppColors.warmDark : AppColors.warmWhite;
    final mutedColor = dark ? AppColors.mutedDark : AppColors.mutedLight;
    final dividerColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(color: dividerColor, thickness: 0.5, height: 0),
          SizedBox(
            height: 44 + bottomPadding,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.fromLTRB(12, 4, 12, bottomPadding),
              child: Row(
                children: [
                  _ToolbarButton(
                    label: 'B',
                    bold: true,
                    color: mutedColor,
                    onTap: () => _wrapSelection('**'),
                  ),
                  _ToolbarButton(
                    label: 'I',
                    italic: true,
                    color: mutedColor,
                    onTap: () => _wrapSelection('*'),
                  ),
                  _ToolbarDivider(color: dividerColor),
                  _ToolbarButton(
                    label: 'H1',
                    color: mutedColor,
                    onTap: () => _insertAtCursor('\n# '),
                  ),
                  _ToolbarButton(
                    label: 'H2',
                    color: mutedColor,
                    onTap: () => _insertAtCursor('\n## '),
                  ),
                  _ToolbarButton(
                    label: 'H3',
                    color: mutedColor,
                    onTap: () => _insertAtCursor('\n### '),
                  ),
                  _ToolbarDivider(color: dividerColor),
                  _ToolbarButton(
                    label: '"',
                    color: mutedColor,
                    onTap: () => _insertAtCursor('\n> '),
                  ),
                  _ToolbarButton(
                    label: '==',
                    color: mutedColor,
                    onTap: () => _wrapSelection('=='),
                  ),
                  _ToolbarDivider(color: dividerColor),
                  _ToolbarIconButton(
                    icon: Icons.image_outlined,
                    color: mutedColor,
                    onTap: () => _insertImage(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Toolbar button components ─────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool bold;
  final bool italic;

  const _ToolbarButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.bold = false,
    this.italic = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 36,
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
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
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color.withOpacity(0.3),
    );
  }
}
