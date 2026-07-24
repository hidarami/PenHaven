import 'dart:convert';
import 'package:uuid/uuid.dart';

/// A single image embedded inside entry body content.
/// [position] is the character offset in [Entry.content]
/// where the image should appear when rendering.
class EntryImage {
  final String path;
  final int position;

  const EntryImage({required this.path, required this.position});

  Map<String, dynamic> toMap() => {'path': path, 'position': position};

  factory EntryImage.fromMap(Map<String, dynamic> map) {
    return EntryImage(
      path: map['path'] as String,
      position: map['position'] as int,
    );
  }
}

class Entry {
  final String id;
  final String storyId;
  String title;
  String content; // Raw markdown text
  final DateTime createdAt;
  DateTime updatedAt;
  int timeSpentSeconds; // Proof of Work — cumulative seconds in editor
  String moodColor;
  String? headerImage; // Optional full-width banner (path)
  String?
      headerImageRatio; // Aspect ratio: '16:9', '4:3', '3:1', '1:1', or 'full'
  List<EntryImage> images; // Legacy — kept for migration only
  bool isDeleted;
  String? blocksJson; // Block-based content (new format)
  String textAlignment; // 'justify', 'left', or 'center'

  Entry({
    String? id,
    required this.storyId,
    this.title = '',
    this.content = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.timeSpentSeconds = 0,
    this.moodColor = 'default',
    this.headerImage,
    this.headerImageRatio,
    List<EntryImage>? images,
    this.isDeleted = false,
    this.blocksJson,
    this.textAlignment = 'justify',
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        images = images ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'storyId': storyId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'timeSpentSeconds': timeSpentSeconds,
      'moodColor': moodColor,
      'headerImage': headerImage,
      'headerImageRatio': headerImageRatio,
      'images': jsonEncode(images.map((e) => e.toMap()).toList()),
      'isDeleted': isDeleted ? 1 : 0,
      'blocksJson': blocksJson,
      'textAlignment': textAlignment,
    };
  }

  factory Entry.fromMap(Map<String, dynamic> map) {
    List<EntryImage> parsedImages = [];
    final rawImages = map['images'];
    if (rawImages != null && rawImages is String && rawImages.isNotEmpty) {
      final decoded = jsonDecode(rawImages) as List<dynamic>;
      parsedImages = decoded
          .map((e) => EntryImage.fromMap(e as Map<String, dynamic>))
          .toList();
    }

    return Entry(
      id: map['id'] as String,
      storyId: map['storyId'] as String,
      title: map['title'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      timeSpentSeconds: (map['timeSpentSeconds'] as int?) ?? 0,
      moodColor: map['moodColor'] as String? ?? 'default',
      headerImage: map['headerImage'] as String?,
      headerImageRatio: map['headerImageRatio'] as String?,
      images: parsedImages,
      isDeleted: (map['isDeleted'] as int) == 1,
      blocksJson: map['blocksJson'] as String?,
      textAlignment: map['textAlignment'] as String? ?? 'justify',
    );
  }

  Entry copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
    int? timeSpentSeconds,
    String? moodColor,
    String? headerImage,
    String? headerImageRatio,
    List<EntryImage>? images,
    bool? isDeleted,
    bool clearHeaderImage = false,
    String? blocksJson,
    bool clearBlocksJson = false,
    String? textAlignment,
  }) {
    return Entry(
      id: id,
      storyId: storyId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      timeSpentSeconds: timeSpentSeconds ?? this.timeSpentSeconds,
      moodColor: moodColor ?? this.moodColor,
      headerImage: clearHeaderImage ? null : (headerImage ?? this.headerImage),
      headerImageRatio: headerImageRatio ?? this.headerImageRatio,
      images: images ?? this.images,
      isDeleted: isDeleted ?? this.isDeleted,
      blocksJson: clearBlocksJson ? null : (blocksJson ?? this.blocksJson),
      textAlignment: textAlignment ?? this.textAlignment,
    );
  }

  // ── Computed helpers ───────────────────────────────────────────────────

  /// Human-readable time spent: "2h 15m", "45m", "30s"
  String get formattedTimeSpent {
    if (timeSpentSeconds <= 0) return '';
    final h = timeSpentSeconds ~/ 3600;
    final m = (timeSpentSeconds % 3600) ~/ 60;
    final s = timeSpentSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  /// Returns a plain-text preview (no markdown syntax), max [length] chars.
  String preview([int length = 120]) {
    final plain = content
        .replaceAll(RegExp(r'#{1,6}\s'), '')
        .replaceAll(RegExp(r'\*\*|__'), '')
        .replaceAll(RegExp(r'\*|_'), '')
        .replaceAll(RegExp(r'`{1,3}'), '')
        .replaceAll(RegExp(r'>\s'), '')
        .replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'$1')
        .trim();
    return plain.length > length ? '${plain.substring(0, length)}…' : plain;
  }

  bool get hasImages => images.isNotEmpty;
  bool get hasHeaderImage => headerImage != null && headerImage!.isNotEmpty;

  /// Time Capsule check: same day + month, different year.
  bool isSameDayAs(DateTime other) {
    return createdAt.day == other.day && createdAt.month == other.month;
  }
}
