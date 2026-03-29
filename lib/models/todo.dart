import 'package:uuid/uuid.dart';

class Todo {
  final String id;
  String title;
  bool isCompleted;
  final DateTime createdAt;
  DateTime? deadline;
  bool isArchived;
  DateTime? completedAt;

  Todo({
    String? id,
    required this.title,
    this.isCompleted = false,
    DateTime? createdAt,
    this.deadline,
    this.isArchived = false,
    this.completedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'deadline': deadline?.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'] as String,
      title: map['title'] as String,
      isCompleted: (map['isCompleted'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : null,
      isArchived: (map['isArchived'] as int) == 1,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }

  Todo copyWith({
    String? title,
    bool? isCompleted,
    DateTime? deadline,
    bool? isArchived,
    DateTime? completedAt,
    bool clearDeadline = false,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      deadline: clearDeadline ? null : (deadline ?? this.deadline),
      isArchived: isArchived ?? this.isArchived,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // ── Mercy Rule ─────────────────────────────────────────────────────────
  // Nothing turns red. Things quietly disappear.

  /// True when this todo should be silently archived.
  bool get shouldAutoArchive {
    if (isArchived || isCompleted) return false;
    final now = DateTime.now();
    if (deadline != null) {
      // 24h grace after deadline
      return now.difference(deadline!).inHours >= 24;
    }
    // 48h after creation if no deadline
    return now.difference(createdAt).inHours >= 48;
  }
}
