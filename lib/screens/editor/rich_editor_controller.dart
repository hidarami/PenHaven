import 'package:flutter/material.dart';
import '../../models/editor_block.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RICH EDITOR CONTROLLER
// TextEditingController subclass that renders WYSIWYG inline formatting.
// Maintains a list of FormatRange objects and renders them via buildTextSpan.
// Handles format range shifting when text is inserted or deleted.
// ─────────────────────────────────────────────────────────────────────────────

class RichEditorController extends TextEditingController {
  final Color baseTextColor;
  final double baseFontSize;

  final List<FormatRange> _formats = [];
  String _prevText = '';

  RichEditorController({
    String? text,
    List<FormatRange>? initialFormats,
    required this.baseTextColor,
    this.baseFontSize = 18,
  }) : super(text: text) {
    if (initialFormats != null) {
      _formats.addAll(initialFormats);
    }
    _prevText = this.text;
    addListener(_onTextChanged);
  }

  List<FormatRange> get formats => List.unmodifiable(_formats);

  /// Sets the text and formats directly (used during block merge operations).
  void setFormatsAndText(String newText, List<FormatRange> newFormats) {
    _formats.clear();
    _formats.addAll(newFormats);
    _prevText = newText;
    text = newText;
  }

  // ── Format queries ─────────────────────────────────────────────────────────

  /// Returns combined format attrs at a given character position.
  FormatAttrs attrsAt(int pos) {
    bool bold = false,
        italic = false,
        underline = false,
        strike = false;
    Color? highlight;
    String? link;

    for (final fmt in _formats) {
      if (fmt.start <= pos && pos < fmt.end) {
        if (fmt.attrs.bold) bold = true;
        if (fmt.attrs.italic) italic = true;
        if (fmt.attrs.underline) underline = true;
        if (fmt.attrs.strikethrough) strike = true;
        highlight ??= fmt.attrs.highlight;
        link ??= fmt.attrs.link;
      }
    }

    return FormatAttrs(
      bold: bold,
      italic: italic,
      underline: underline,
      strikethrough: strike,
      highlight: highlight,
      link: link,
    );
  }

  /// Whether ALL characters in selection have the given format active.
  bool selectionHas({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) {
      // Check cursor position (what will be typed next)
      final attrs = attrsAt(sel.start > 0 ? sel.start - 1 : 0);
      if (bold != null) return attrs.bold;
      if (italic != null) return attrs.italic;
      if (underline != null) return attrs.underline;
      if (strikethrough != null) return attrs.strikethrough;
      return false;
    }

    for (int i = sel.start; i < sel.end; i++) {
      final attrs = attrsAt(i);
      if (bold != null && !attrs.bold) return false;
      if (italic != null && !attrs.italic) return false;
      if (underline != null && !attrs.underline) return false;
      if (strikethrough != null && !attrs.strikethrough) return false;
    }
    return true;
  }

  // ── Format application ─────────────────────────────────────────────────────

  void toggleBold() => _toggleFormat(bold: true);
  void toggleItalic() => _toggleFormat(italic: true);
  void toggleUnderline() => _toggleFormat(underline: true);
  void toggleStrikethrough() => _toggleFormat(strikethrough: true);

  void applyHighlight(Color color) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    _removeAttrInRange(sel.start, sel.end, clearHighlight: true);
    _addFormat(FormatRange(
      start: sel.start,
      end: sel.end,
      attrs: FormatAttrs(highlight: color),
    ));
  }

  void clearHighlight() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    _removeAttrInRange(sel.start, sel.end, clearHighlight: true);
  }

  void applyLink(String url) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    _removeAttrInRange(sel.start, sel.end, clearLink: true);
    _addFormat(FormatRange(
      start: sel.start,
      end: sel.end,
      attrs: FormatAttrs(link: url),
    ));
  }

  void clearLink() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    _removeAttrInRange(sel.start, sel.end, clearLink: true);
  }

  void _toggleFormat({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
  }) {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;

    final hasFormat =
        selectionHas(bold: bold, italic: italic, underline: underline, strikethrough: strikethrough);

    if (hasFormat) {
      // Remove format in range
      _removeAttrInRange(sel.start, sel.end,
          removeBold: bold != null,
          removeItalic: italic != null,
          removeUnderline: underline != null,
          removeStrikethrough: strikethrough != null);
    } else {
      // Add format range
      _addFormat(FormatRange(
        start: sel.start,
        end: sel.end,
        attrs: FormatAttrs(
          bold: bold ?? false,
          italic: italic ?? false,
          underline: underline ?? false,
          strikethrough: strikethrough ?? false,
        ),
      ));
    }
    notifyListeners();
  }

  void _addFormat(FormatRange newFmt) {
    _formats.add(newFmt);
    _cleanupFormats();
    notifyListeners();
  }

  void _removeAttrInRange(
    int start,
    int end, {
    bool removeBold = false,
    bool removeItalic = false,
    bool removeUnderline = false,
    bool removeStrikethrough = false,
    bool clearHighlight = false,
    bool clearLink = false,
  }) {
    final toRemove = <FormatRange>[];
    final toAdd = <FormatRange>[];

    for (final fmt in _formats) {
      // No overlap
      if (fmt.end <= start || fmt.start >= end) continue;

      toRemove.add(fmt);

      // Part before range
      if (fmt.start < start) {
        toAdd.add(FormatRange(
          start: fmt.start,
          end: start,
          attrs: fmt.attrs,
        ));
      }

      // The overlapping part with attribute removed
      final overlapStart = start > fmt.start ? start : fmt.start;
      final overlapEnd = end < fmt.end ? end : fmt.end;

      final newAttrs = FormatAttrs(
        bold: removeBold ? false : fmt.attrs.bold,
        italic: removeItalic ? false : fmt.attrs.italic,
        underline: removeUnderline ? false : fmt.attrs.underline,
        strikethrough: removeStrikethrough ? false : fmt.attrs.strikethrough,
        highlight: clearHighlight ? null : fmt.attrs.highlight,
        link: clearLink ? null : fmt.attrs.link,
      );
      if (!newAttrs.isEmpty) {
        toAdd.add(FormatRange(
          start: overlapStart,
          end: overlapEnd,
          attrs: newAttrs,
        ));
      }

      // Part after range
      if (fmt.end > end) {
        toAdd.add(FormatRange(
          start: end,
          end: fmt.end,
          attrs: fmt.attrs,
        ));
      }
    }

    _formats.removeWhere((f) => toRemove.contains(f));
    _formats.addAll(toAdd);
    _cleanupFormats();
  }

  void _cleanupFormats() {
    // Remove empty ranges
    _formats.removeWhere((f) => f.start >= f.end || f.attrs.isEmpty);
    // Clamp to text length
    final len = text.length;
    for (final f in _formats) {
      if (f.start > len) f.start = len;
      if (f.end > len) f.end = len;
    }
    _formats.removeWhere((f) => f.start >= f.end);
  }

  // ── Text change handling ───────────────────────────────────────────────────

  void _onTextChanged() {
    final newText = text;
    if (newText == _prevText) {
      _prevText = newText;
      return;
    }

    final oldLen = _prevText.length;
    final newLen = newText.length;

    // Find start of change
    int changeStart = 0;
    while (changeStart < oldLen &&
        changeStart < newLen &&
        _prevText[changeStart] == newText[changeStart]) {
      changeStart++;
    }

    // Find end of change from the back
    int oldEnd = oldLen;
    int newEnd = newLen;
    while (oldEnd > changeStart &&
        newEnd > changeStart &&
        _prevText[oldEnd - 1] == newText[newEnd - 1]) {
      oldEnd--;
      newEnd--;
    }

    final deletedLen = oldEnd - changeStart;
    final insertedLen = newEnd - changeStart;

    if (deletedLen > 0) {
      _deleteFormatsInRange(changeStart, changeStart + deletedLen);
      _shiftFormats(changeStart, -deletedLen);
    }
    if (insertedLen > 0) {
      _shiftFormats(changeStart, insertedLen);
    }

    _cleanupFormats();
    _prevText = newText;
  }

  void _deleteFormatsInRange(int start, int end) {
    final toRemove = <FormatRange>[];
    final toAdd = <FormatRange>[];

    for (final fmt in _formats) {
      if (fmt.end <= start || fmt.start >= end) continue;
      toRemove.add(fmt);

      if (fmt.start < start) {
        toAdd.add(FormatRange(
          start: fmt.start,
          end: start,
          attrs: fmt.attrs,
        ));
      }
      if (fmt.end > end) {
        toAdd.add(FormatRange(
          start: end,
          end: fmt.end,
          attrs: fmt.attrs,
        ));
      }
    }

    _formats.removeWhere((f) => toRemove.contains(f));
    _formats.addAll(toAdd);
  }

  void _shiftFormats(int from, int delta) {
    for (final fmt in _formats) {
      if (fmt.start >= from) fmt.start += delta;
      if (fmt.end > from) fmt.end += delta;
      if (fmt.end < fmt.start) fmt.end = fmt.start;
    }
  }

  // ── Text span rendering ────────────────────────────────────────────────────

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final t = text;
    if (t.isEmpty) return TextSpan(text: '', style: style);
    if (_formats.isEmpty) return TextSpan(text: t, style: style);

    // Build segment list by finding all breakpoints
    final breakpoints = <int>{0, t.length};
    for (final fmt in _formats) {
      if (fmt.start >= 0 && fmt.start <= t.length) breakpoints.add(fmt.start);
      if (fmt.end >= 0 && fmt.end <= t.length) breakpoints.add(fmt.end);
    }

    // Handle composing region
    if (withComposing && value.isComposingRangeValid) {
      breakpoints.add(value.composing.start);
      breakpoints.add(value.composing.end);
    }

    final sorted = breakpoints.toList()..sort();
    final spans = <InlineSpan>[];

    for (int i = 0; i < sorted.length - 1; i++) {
      final segStart = sorted[i];
      final segEnd = sorted[i + 1];
      if (segStart >= segEnd) continue;

      final segText = t.substring(segStart, segEnd);
      final attrs = attrsAt(segStart);
      final isComposing = withComposing &&
          value.isComposingRangeValid &&
          segStart >= value.composing.start &&
          segEnd <= value.composing.end;

      spans.add(TextSpan(
        text: segText,
        style: _buildStyle(style, attrs, isComposing),
      ));
    }

    return TextSpan(children: spans, style: style);
  }

  TextStyle? _buildStyle(TextStyle? base, FormatAttrs attrs, bool composing) {
    var s = base ?? const TextStyle();
    if (attrs.bold) s = s.copyWith(fontWeight: FontWeight.w700);
    if (attrs.italic) s = s.copyWith(fontStyle: FontStyle.italic);

    final decorations = <TextDecoration>[];
    if (attrs.underline) decorations.add(TextDecoration.underline);
    if (attrs.strikethrough) decorations.add(TextDecoration.lineThrough);
    if (composing) decorations.add(TextDecoration.underline);
    if (decorations.isNotEmpty) {
      s = s.copyWith(
        decoration: TextDecoration.combine(decorations),
        decorationColor: attrs.strikethrough ? base?.color : null,
      );
    }

    if (attrs.highlight != null) {
      s = s.copyWith(backgroundColor: attrs.highlight!.withOpacity(0.35));
    }

    if (attrs.link != null) {
      s = s.copyWith(
        color: const Color(0xFF7BA591),
        decoration: TextDecoration.underline,
        decorationColor: const Color(0xFF7BA591),
      );
    }

    return s;
  }

  @override
  void dispose() {
    removeListener(_onTextChanged);
    super.dispose();
  }
}