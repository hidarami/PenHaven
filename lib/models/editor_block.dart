import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR BLOCKS
// Block-based content model. Every piece of content in an entry is a block.
// Text blocks, image blocks, embeds, code, grids — all first-class blocks.
// Eliminates the U+FFFC hack and all image-position bugs permanently.
// ─────────────────────────────────────────────────────────────────────────────

enum BlockType {
  text,
  heading1,
  heading2,
  heading3,
  quote,
  image,
  imageGrid,
  youtubeEmbed,
  tweetEmbed,
  unsplashImage,
  codeBlock,
  divider,
}

// ── Format attributes for inline rich text ────────────────────────────────────

class FormatAttrs {
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strikethrough;
  final Color? highlight;
  final String? link;

  const FormatAttrs({
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strikethrough = false,
    this.highlight,
    this.link,
  });

  FormatAttrs merge(FormatAttrs other) => FormatAttrs(
        bold: bold || other.bold,
        italic: italic || other.italic,
        underline: underline || other.underline,
        strikethrough: strikethrough || other.strikethrough,
        highlight: other.highlight ?? highlight,
        link: other.link ?? link,
      );

  FormatAttrs toggle({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    Color? highlight,
    bool clearHighlight = false,
    String? link,
    bool clearLink = false,
  }) =>
      FormatAttrs(
        bold: bold != null ? !this.bold : this.bold,
        italic: italic != null ? !this.italic : this.italic,
        underline: underline != null ? !this.underline : this.underline,
        strikethrough:
            strikethrough != null ? !this.strikethrough : this.strikethrough,
        highlight: clearHighlight ? null : (highlight ?? this.highlight),
        link: clearLink ? null : (link ?? this.link),
      );

  bool get isEmpty =>
      !bold &&
      !italic &&
      !underline &&
      !strikethrough &&
      highlight == null &&
      link == null;

  Map<String, dynamic> toMap() => {
        'bold': bold,
        'italic': italic,
        'underline': underline,
        'strikethrough': strikethrough,
        'highlight': highlight?.value,
        'link': link,
      };

  factory FormatAttrs.fromMap(Map<String, dynamic> m) => FormatAttrs(
        bold: m['bold'] as bool? ?? false,
        italic: m['italic'] as bool? ?? false,
        underline: m['underline'] as bool? ?? false,
        strikethrough: m['strikethrough'] as bool? ?? false,
        highlight:
            m['highlight'] != null ? Color(m['highlight'] as int) : null,
        link: m['link'] as String?,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FormatAttrs &&
          bold == other.bold &&
          italic == other.italic &&
          underline == other.underline &&
          strikethrough == other.strikethrough &&
          highlight == other.highlight &&
          link == other.link;

  @override
  int get hashCode => Object.hash(
      bold, italic, underline, strikethrough, highlight, link);
}

// ── Format range (span in a text block) ──────────────────────────────────────

class FormatRange {
  int start;
  int end;
  final FormatAttrs attrs;

  FormatRange({
    required this.start,
    required this.end,
    required this.attrs,
  });

  Map<String, dynamic> toMap() => {
        'start': start,
        'end': end,
        'attrs': attrs.toMap(),
      };

  factory FormatRange.fromMap(Map<String, dynamic> m) => FormatRange(
        start: m['start'] as int,
        end: m['end'] as int,
        attrs: FormatAttrs.fromMap(m['attrs'] as Map<String, dynamic>),
      );
}

// ── Base block ────────────────────────────────────────────────────────────────

abstract class EditorBlock {
  final String id;
  final BlockType type;

  const EditorBlock({required this.id, required this.type});

  Map<String, dynamic> toMap();

  static EditorBlock fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    final type = BlockType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => BlockType.text,
    );
    switch (type) {
      case BlockType.text:
      case BlockType.heading1:
      case BlockType.heading2:
      case BlockType.heading3:
      case BlockType.quote:
        return TextBlock.fromMap(map);
      case BlockType.image:
      case BlockType.unsplashImage:
        return ImageBlock.fromMap(map);
      case BlockType.imageGrid:
        return ImageGridBlock.fromMap(map);
      case BlockType.youtubeEmbed:
        return YoutubeBlock.fromMap(map);
      case BlockType.tweetEmbed:
        return TweetBlock.fromMap(map);
      case BlockType.codeBlock:
        return CodeBlock.fromMap(map);
      case BlockType.divider:
        return DividerBlock.fromMap(map);
    }
  }
}

// ── Text block ────────────────────────────────────────────────────────────────

class TextBlock extends EditorBlock {
  final String text;
  final List<FormatRange> formats;

  const TextBlock({
    required String id,
    BlockType type = BlockType.text,
    required this.text,
    this.formats = const [],
  }) : super(id: id, type: type);

  TextBlock copyWith({
    String? text,
    List<FormatRange>? formats,
    BlockType? type,
  }) =>
      TextBlock(
        id: id,
        type: type ?? this.type,
        text: text ?? this.text,
        formats: formats ?? this.formats,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'text': text,
        'formats': formats.map((f) => f.toMap()).toList(),
      };

  factory TextBlock.fromMap(Map<String, dynamic> m) {
    final type = BlockType.values.firstWhere(
      (t) => t.name == (m['type'] as String? ?? 'text'),
      orElse: () => BlockType.text,
    );
    return TextBlock(
      id: m['id'] as String,
      type: type,
      text: m['text'] as String? ?? '',
      formats: (m['formats'] as List<dynamic>? ?? [])
          .map((f) => FormatRange.fromMap(f as Map<String, dynamic>))
          .toList(),
    );
  }

  factory TextBlock.empty({BlockType type = BlockType.text}) =>
      TextBlock(id: const Uuid().v4(), type: type, text: '');
}

// ── Image block ───────────────────────────────────────────────────────────────

class ImageBlock extends EditorBlock {
  final String path;
  final String? caption;
  final bool isUnsplash;
  final String? unsplashCredit;

  const ImageBlock({
    required String id,
    required this.path,
    this.caption,
    this.isUnsplash = false,
    this.unsplashCredit,
  }) : super(id: id, type: BlockType.image);

  ImageBlock copyWith({String? caption}) => ImageBlock(
        id: id,
        path: path,
        caption: caption ?? this.caption,
        isUnsplash: isUnsplash,
        unsplashCredit: unsplashCredit,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'path': path,
        'caption': caption,
        'isUnsplash': isUnsplash,
        'unsplashCredit': unsplashCredit,
      };

  factory ImageBlock.fromMap(Map<String, dynamic> m) => ImageBlock(
        id: m['id'] as String,
        path: m['path'] as String,
        caption: m['caption'] as String?,
        isUnsplash: m['isUnsplash'] as bool? ?? false,
        unsplashCredit: m['unsplashCredit'] as String?,
      );
}

// ── Image grid block ──────────────────────────────────────────────────────────

class ImageGridBlock extends EditorBlock {
  final List<String> paths;
  final int columns;

  const ImageGridBlock({
    required String id,
    required this.paths,
    this.columns = 2,
  }) : super(id: id, type: BlockType.imageGrid);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'paths': paths,
        'columns': columns,
      };

  factory ImageGridBlock.fromMap(Map<String, dynamic> m) => ImageGridBlock(
        id: m['id'] as String,
        paths: List<String>.from(m['paths'] as List<dynamic>? ?? []),
        columns: m['columns'] as int? ?? 2,
      );
}

// ── YouTube embed block ───────────────────────────────────────────────────────

class YoutubeBlock extends EditorBlock {
  final String url;
  final String videoId;
  final String? title;

  const YoutubeBlock({
    required String id,
    required this.url,
    required this.videoId,
    this.title,
  }) : super(id: id, type: BlockType.youtubeEmbed);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'url': url,
        'videoId': videoId,
        'title': title,
      };

  factory YoutubeBlock.fromMap(Map<String, dynamic> m) => YoutubeBlock(
        id: m['id'] as String,
        url: m['url'] as String,
        videoId: m['videoId'] as String,
        title: m['title'] as String?,
      );

  static String? extractVideoId(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/)([a-zA-Z0-9_-]{11})',
    );
    return regExp.firstMatch(url)?.group(1);
  }

  String get thumbnailUrl =>
      'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

// ── Twitter/X embed block ─────────────────────────────────────────────────────

class TweetBlock extends EditorBlock {
  final String url;
  final String? tweetId;
  final String? displayText;

  const TweetBlock({
    required String id,
    required this.url,
    this.tweetId,
    this.displayText,
  }) : super(id: id, type: BlockType.tweetEmbed);

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'url': url,
        'tweetId': tweetId,
        'displayText': displayText,
      };

  factory TweetBlock.fromMap(Map<String, dynamic> m) => TweetBlock(
        id: m['id'] as String,
        url: m['url'] as String,
        tweetId: m['tweetId'] as String?,
        displayText: m['displayText'] as String?,
      );

  static String? extractTweetId(String url) {
    final regExp = RegExp(r'(?:twitter\.com|x\.com)/\w+/status/(\d+)');
    return regExp.firstMatch(url)?.group(1);
  }
}

// ── Code block ────────────────────────────────────────────────────────────────

class CodeBlock extends EditorBlock {
  final String code;
  final String language;

  const CodeBlock({
    required String id,
    required this.code,
    this.language = 'plaintext',
  }) : super(id: id, type: BlockType.codeBlock);

  CodeBlock copyWith({String? code, String? language}) => CodeBlock(
        id: id,
        code: code ?? this.code,
        language: language ?? this.language,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'code': code,
        'language': language,
      };

  factory CodeBlock.fromMap(Map<String, dynamic> m) => CodeBlock(
        id: m['id'] as String,
        code: m['code'] as String? ?? '',
        language: m['language'] as String? ?? 'plaintext',
      );
}

// ── Divider block ─────────────────────────────────────────────────────────────

class DividerBlock extends EditorBlock {
  const DividerBlock({required String id})
      : super(id: id, type: BlockType.divider);

  @override
  Map<String, dynamic> toMap() => {'id': id, 'type': type.name};

  factory DividerBlock.fromMap(Map<String, dynamic> m) =>
      DividerBlock(id: m['id'] as String);
}

// ── Serialization helpers ─────────────────────────────────────────────────────

String serializeBlocks(List<EditorBlock> blocks) =>
    jsonEncode(blocks.map((b) => b.toMap()).toList());

List<EditorBlock> deserializeBlocks(String json) {
  try {
    final list = jsonDecode(json) as List<dynamic>;
    return list
        .map((e) => EditorBlock.fromMap(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
}

/// Convert old markdown content + images to blocks for migration.
List<EditorBlock> blocksFromLegacy(String content, List<dynamic> images) {
  if (content.trim().isEmpty && images.isEmpty) {
    return [TextBlock.empty()];
  }
  // For legacy entries just wrap content in a single text block
  // (markdown formatting preserved as-is for display via MarkdownBody)
  return [
    TextBlock(
      id: const Uuid().v4(),
      type: BlockType.text,
      text: content,
      formats: [],
    ),
  ];
}

/// Extract plain text from blocks for search/preview.
String plainTextFromBlocks(List<EditorBlock> blocks) {
  final buf = StringBuffer();
  for (final block in blocks) {
    if (block is TextBlock) {
      buf.writeln(block.text);
    } else if (block is ImageBlock) {
      if (block.caption != null) buf.writeln(block.caption);
    } else if (block is CodeBlock) {
      buf.writeln(block.code);
    }
  }
  return buf.toString().trim();
}