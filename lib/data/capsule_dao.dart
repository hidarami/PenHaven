import 'package:sqflite/sqflite.dart';
import '../models/time_capsule.dart';
import '../models/period_log.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CAPSULE DAO
// Handles both TimeCapsule (user letters to future self) and
// PeriodLog (optional health tracking) since both are small tables
// with minimal query complexity.
// ─────────────────────────────────────────────────────────────────────────────

class CapsuleDao {
  CapsuleDao._();
  static final CapsuleDao instance = CapsuleDao._();

  // ── Time Capsule ──────────────────────────────────────────────────────────

  Future<void> insertCapsule(TimeCapsule capsule) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'time_capsules',
      capsule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All capsules, sorted by openAt date ascending.
  Future<List<TimeCapsule>> getAllCapsules() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'time_capsules',
      orderBy: 'openAt ASC',
    );
    return maps.map(TimeCapsule.fromMap).toList();
  }

  /// Capsules that are past their openAt date and not yet opened.
  Future<List<TimeCapsule>> getReadyCapsules() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final maps = await db.query(
      'time_capsules',
      where: 'openAt <= ? AND isOpened = ?',
      whereArgs: [now, 0],
      orderBy: 'openAt ASC',
    );
    return maps.map(TimeCapsule.fromMap).toList();
  }

  Future<void> markOpened(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'time_capsules',
      {'isOpened': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCapsule(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('time_capsules', where: 'id = ?', whereArgs: [id]);
  }

  // ── Period Log ────────────────────────────────────────────────────────────
  // Only written to / read from if user enables period tracking in Settings.

  Future<void> insertPeriodLog(PeriodLog log) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'period_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PeriodLog>> getAllPeriodLogs() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'period_logs',
      orderBy: 'startDate DESC',
    );
    return maps.map(PeriodLog.fromMap).toList();
  }

  /// The current active period (no endDate set), if any.
  Future<PeriodLog?> getActivePeriod() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'period_logs',
      where: 'endDate IS NULL',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PeriodLog.fromMap(maps.first);
  }

  Future<void> updatePeriodLog(PeriodLog log) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'period_logs',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<void> deletePeriodLog(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('period_logs', where: 'id = ?', whereArgs: [id]);
  }
}
