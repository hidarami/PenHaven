import 'package:uuid/uuid.dart';

/// A Write Back — private journal entry or published Reflection in Sanctuary.
/// Always linked to a root original published entry via [originEntryId].
class Reflection {
  final String id;
  final String originEntryId;   // root original published_entries id
  final String? inspirationId;  // if written from another reflection
  final String userId;
  String title;
  String content;
  String? blocksJson;
  bool isPrivate;
  bool isAnonymous;
  String? displayName;
  String? headerImage;
  String? headerImageRatio;
  String? category;
  int clapCount;
  int replyCount;
  final DateTime createdAt;
  bool hasClapped;
  bool isOwner;

  // Denormalized origin data for "Reflection on" card
  String? originTitle;
  String? originAuthor;
  String? originExcerpt;
  String? originHeaderImage;

  // Breadcrumb only — if written from another reflection
  String? inspirationAuthor;
  String? inspirationTitle;
  String? authorImageUrl;

  Reflection({
    String? id,
    required this.originEntryId,
    this.inspirationId,
    required this.userId,
    this.title = '',
    this.content = '',
    this.blocksJson,
    this.isPrivate = true,
    this.isAnonymous = false,
    this.displayName,
    this.headerImage,
    this.headerImageRatio,
    this.category,
    this.clapCount = 0,
    this.replyCount = 0,
    DateTime? createdAt,
    this.hasClapped = false,
    this.isOwner = false,
    this.originTitle,
    this.originAuthor,
    this.originExcerpt,
    this.originHeaderImage,
    this.inspirationAuthor,
    this.inspirationTitle,
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
        .trim();
    return plain.length > length ? '${plain.substring(0, length)}…' : plain;
  }

  int get wordCount => content.trim().isEmpty
      ? 0
      : content.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  Map<String, dynamic> toMap() => {
        'id': id,
        'origin_entry_id': originEntryId,
        'inspiration_id': inspirationId,
        'user_id': userId,
        'origin_author_id': null, // set by caller when available
        'title': title,
        'content': content,
        'blocks_json': blocksJson,
        'is_private': isPrivate,
        'is_anonymous': isAnonymous,
        'display_name': isAnonymous ? null : displayName,
        'header_image': headerImage,
        'header_image_ratio': headerImageRatio,
        'category': category,
        'clap_count': clapCount,
        'reply_count': replyCount,
        'created_at': createdAt.toIso8601String(),
        'origin_title': originTitle,
        'origin_author': originAuthor,
        'origin_excerpt': originExcerpt,
        'origin_header_image': originHeaderImage,
        'inspiration_author': inspirationAuthor,
        'inspiration_title': inspirationTitle,
        'profile_image_url': authorImageUrl,
      };

  factory Reflection.fromMap(Map<String, dynamic> map) => Reflection(
        id: map['id'] as String? ?? '',
        originEntryId: map['origin_entry_id'] as String? ?? '',
        inspirationId: map['inspiration_id'] as String?,
        userId: (map['user_id'] ?? '').toString(),
        title: map['title'] as String? ?? '',
        content: map['content'] as String? ?? '',
        blocksJson: map['blocks_json'] as String?,
        isPrivate: map['is_private'] as bool? ?? true,
        isAnonymous: map['is_anonymous'] as bool? ?? false,
        displayName: map['display_name'] as String?,
        headerImage: map['header_image'] as String?,
        headerImageRatio: map['header_image_ratio'] as String?,
        category: map['category'] as String?,
        clapCount: (map['clap_count'] as int?) ?? 0,
        replyCount: (map['reply_count'] as int?) ?? 0,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
        originTitle: map['origin_title'] as String?,
        originAuthor: map['origin_author'] as String?,
        originExcerpt: map['origin_excerpt'] as String?,
        originHeaderImage: map['origin_header_image'] as String?,
        inspirationAuthor: map['inspiration_author'] as String?,
        inspirationTitle: map['inspiration_title'] as String?,
        authorImageUrl: map['profile_image_url'] as String?,
      );
}