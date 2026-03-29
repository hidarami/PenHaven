import 'package:uuid/uuid.dart';

/// A user-written letter to their future self.
/// Also used internally to surface "On this day last year" entries.
class TimeCapsule {
  final String id;
  final String message;
  final DateTime createdAt;
  final DateTime openAt;
  bool isOpened;

  TimeCapsule({
    String? id,
    required this.message,
    DateTime? createdAt,
    required this.openAt,
    this.isOpened = false,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isReadyToOpen => DateTime.now().isAfter(openAt);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'openAt': openAt.toIso8601String(),
      'isOpened': isOpened ? 1 : 0,
    };
  }

  factory TimeCapsule.fromMap(Map<String, dynamic> map) {
    return TimeCapsule(
      id: map['id'] as String,
      message: map['message'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      openAt: DateTime.parse(map['openAt'] as String),
      isOpened: (map['isOpened'] as int) == 1,
    );
  }

  TimeCapsule copyWith({bool? isOpened}) {
    return TimeCapsule(
      id: id,
      message: message,
      createdAt: createdAt,
      openAt: openAt,
      isOpened: isOpened ?? this.isOpened,
    );
  }
}
