import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY VERSION
// Snapshot of an entry's content at a point in time.
// Stored in the entry_versions table.
// The 20 most recent versions per entry are kept; older ones are pruned.
// ─────────────────────────────────────────────────────────────────────────────

class EntryVersion {
  final String id;
  final String entryId;
  final String title;
  final String blocksJson; // Serialised block list
  final int timeSpentSeconds;
  final DateTime savedAt;
  final String? label; // Optional user label ("Before major edit", etc.)

  EntryVersion({
    String? id,
    required this.entryId,
    required this.title,
    required this.blocksJson,
    required this.timeSpentSeconds,
    DateTime? savedAt,
    this.label,
  })  : id = id ?? const Uuid().v4(),
        savedAt = savedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'entryId': entryId,
        'title': title,
        'blocksJson': blocksJson,
        'timeSpentSeconds': timeSpentSeconds,
        'savedAt': savedAt.toIso8601String(),
        'label': label,
      };

  factory EntryVersion.fromMap(Map<String, dynamic> m) => EntryVersion(
        id: m['id'] as String,
        entryId: m['entryId'] as String,
        title: m['title'] as String,
        blocksJson: m['blocksJson'] as String,
        timeSpentSeconds: (m['timeSpentSeconds'] as int?) ?? 0,
        savedAt: DateTime.parse(m['savedAt'] as String),
        label: m['label'] as String?,
      );

  /// How long ago this version was saved, formatted nicely.
  String get relativeTime {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}
