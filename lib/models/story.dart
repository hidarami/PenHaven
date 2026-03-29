import 'package:uuid/uuid.dart';

class Story {
  final String id;
  String title;
  String description;
  final DateTime createdAt;
  DateTime updatedAt;
  bool isLocked;
  bool isDeleted;

  Story({
    String? id,
    required this.title,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
    this.isLocked = false,
    this.isDeleted = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isLocked': isLocked ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
    };
  }

  factory Story.fromMap(Map<String, dynamic> map) {
    return Story(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      isLocked: (map['isLocked'] as int) == 1,
      isDeleted: (map['isDeleted'] as int) == 1,
    );
  }

  Story copyWith({
    String? title,
    String? description,
    DateTime? updatedAt,
    bool? isLocked,
    bool? isDeleted,
  }) {
    return Story(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      isLocked: isLocked ?? this.isLocked,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
