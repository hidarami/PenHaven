import 'package:uuid/uuid.dart';

/// Optional health tracking module.
/// Completely invisible in the app unless user enables it in Settings.
class PeriodLog {
  final String id;
  final DateTime startDate;
  DateTime? endDate;
  int flowLevel; // 1 = light, 2 = medium, 3 = heavy
  String notes; // Symptom keywords, free text

  PeriodLog({
    String? id,
    required this.startDate,
    this.endDate,
    this.flowLevel = 2,
    this.notes = '',
  }) : id = id ?? const Uuid().v4();

  bool get isActive => endDate == null;

  int? get durationDays {
    if (endDate == null) return null;
    return endDate!.difference(startDate).inDays + 1;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'flowLevel': flowLevel,
      'notes': notes,
    };
  }

  factory PeriodLog.fromMap(Map<String, dynamic> map) {
    return PeriodLog(
      id: map['id'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      flowLevel: (map['flowLevel'] as int?) ?? 2,
      notes: map['notes'] as String? ?? '',
    );
  }

  PeriodLog copyWith({
    DateTime? endDate,
    int? flowLevel,
    String? notes,
    bool closeLog = false,
  }) {
    return PeriodLog(
      id: id,
      startDate: startDate,
      endDate: closeLog ? DateTime.now() : (endDate ?? this.endDate),
      flowLevel: flowLevel ?? this.flowLevel,
      notes: notes ?? this.notes,
    );
  }
}
