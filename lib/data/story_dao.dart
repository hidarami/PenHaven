import 'package:sqflite/sqflite.dart';
import '../models/story.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// STORY DAO
// All database operations for the stories table.
// Soft-delete pattern: isDeleted = 1, never hard-remove by default.
// ─────────────────────────────────────────────────────────────────────────────

class StoryDao {
  StoryDao._();
  static final StoryDao instance = StoryDao._();

  Future<void> insert(Story story) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'stories',
      story.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Returns all non-deleted stories, newest first.
  Future<List<Story>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'stories',
      where: 'isDeleted = ?',
      whereArgs: [0],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Story.fromMap).toList();
  }

  Future<Story?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'stories',
      where: 'id = ? AND isDeleted = ?',
      whereArgs: [id, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Story.fromMap(maps.first);
  }

  Future<void> update(Story story) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'stories',
      story.toMap(),
      where: 'id = ?',
      whereArgs: [story.id],
    );
  }

  /// Soft-delete: marks isDeleted = 1. Entries cascade via FK.
  Future<void> softDelete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'stories',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restores a soft-deleted story.
  Future<void> restore(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'stories',
      {
        'isDeleted': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Returns soft-deleted stories for the Bin screen.
  Future<List<Story>> getDeleted() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'stories',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Story.fromMap).toList();
  }

  /// Hard-deletes a story and all its entries (cascade enforced by FK).
  Future<void> hardDelete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('stories', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> count() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM stories WHERE isDeleted = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
