class CommunityComment {
  final String id;
  final String entryId;
  final String userId;
  final String? displayName;
  final String body;
  final bool isAnonymous;
  final DateTime createdAt;

  CommunityComment({
    required this.id,
    required this.entryId,
    required this.userId,
    this.displayName,
    required this.body,
    this.isAnonymous = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get authorLabel => isAnonymous
      ? 'Anonymous'
      : (displayName?.isNotEmpty == true ? displayName! : 'A Writer');

  factory CommunityComment.fromMap(Map<String, dynamic> map) =>
      CommunityComment(
        id: map['id'] as String,
        entryId: map['entry_id'] as String,
        userId: map['user_id'].toString(),
        displayName: map['display_name'] as String?,
        body: map['body'] as String,
        isAnonymous: map['is_anonymous'] as bool? ?? false,
        createdAt: map['created_at'] != null
            ? DateTime.parse(map['created_at'] as String)
            : DateTime.now(),
      );
}
