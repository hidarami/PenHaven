import 'package:sqflite/sqflite.dart';
import '../models/time_capsule.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CAPSULE DAO
// Handles TimeCapsule (user letters to future self).
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
}
