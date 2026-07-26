import 'package:uuid/uuid.dart';

class PublishedEntry {
  final String id;
  final String userId;
  final String title;
  final String content;
  final String? blocksJson;
  final bool isAnonymous;
  final String? displayName;
  final String? headerImage;
  final String? category;
  int clapCount;
  int commentCount;
  final DateTime createdAt;
  bool hasClapped;
  bool isOwner;
  String? authorImageUrl;

  PublishedEntry({
    String? id,
    required this.userId,
    required this.title,
    required this.content,
    this.blocksJson,
    this.isAnonymous = false,
    this.displayName,
    this.headerImage,
    this.category,
    this.clapCount = 0,
    this.commentCount = 0,
    DateTime? createdAt,
    this.hasClapped = false,
    this.isOwner = false,
    this.authorImageUrl,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  String get authorLabel => isAnonymous
      ? 'Anonymous'
      : (displayName?.isNotEmpty == true ? displayName! : 'A Writer');

  String preview([int length = 140]) {
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

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'content': content,
        'blocks_json': blocksJson,
        'is_anonymous': isAnonymous,
        'display_name': isAnonymous ? null : displayName,
        'header_image': headerImage,
        'category': category,
        'clap_count': clapCount,
        'comment_count': commentCount,
        'created_at': createdAt.toIso8601String(),
        'profile_image_url': authorImageUrl,
      };

  factory PublishedEntry.fromMap(Map<String, dynamic> map) => PublishedEntry(
        id: map['id'] as String,
        userId: map['user_id'].toString(),
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        blocksJson: map['blocks_json'] as String?,
        isAnonymous: map['is_anonymous'] as bool? ?? false,
        displayName: map['display_name'] as String?,
        headerImage: map['header_image'] as String?,
        category: map['category'] as String?,
        clapCount: (map['clap_count'] as int?) ?? 0,
        commentCount: (map['comment_count'] as int?) ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        authorImageUrl: map['profile_image_url'] as String?,
      );
}
