import 'package:sqflite/sqflite.dart';
import '../models/entry.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY DAO
// All database operations for the entries table.
// Soft-delete pattern consistent with StoryDao.
// ─────────────────────────────────────────────────────────────────────────────

class EntryDao {
  EntryDao._();
  static final EntryDao instance = EntryDao._();

  Future<void> insert(Entry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// All non-deleted entries for a given story, newest first.
  Future<List<Entry>> getByStory(String storyId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entries',
      where: 'storyId = ? AND isDeleted = ?',
      whereArgs: [storyId, 0],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Entry.fromMap).toList();
  }

  Future<Entry?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entries',
      where: 'id = ? AND isDeleted = ?',
      whereArgs: [id, 0],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Entry.fromMap(maps.first);
  }

  Future<void> update(Entry entry) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Updates only the time spent — called on editor close.
  Future<void> addTimeSpent(String id, int additionalSeconds) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      '''UPDATE entries
         SET timeSpentSeconds = timeSpentSeconds + ?,
             updatedAt = ?
         WHERE id = ?''',
      [additionalSeconds, DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> softDelete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'entries',
      {
        'isDeleted': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> restore(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'entries',
      {
        'isDeleted': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Entry>> getDeleted() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entries',
      where: 'isDeleted = ?',
      whereArgs: [1],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Entry.fromMap).toList();
  }

  Future<void> hardDelete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }

  /// Returns entries created on the same day-of-year as [date]
  /// but in a different year. Used for Time Capsule "On this day" feature.
  Future<List<Entry>> getTimeCapsuleEntries(DateTime date) async {
    final db = await DatabaseHelper.instance.database;
    // SQLite: strftime('%m-%d', createdAt) matches month-day
    final monthDay =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final maps = await db.rawQuery(
      '''SELECT * FROM entries
         WHERE isDeleted = 0
           AND strftime('%m-%d', createdAt) = ?
           AND strftime('%Y', createdAt) != ?
         ORDER BY createdAt DESC''',
      [monthDay, date.year.toString()],
    );
    return maps.map(Entry.fromMap).toList();
  }

  /// Count of non-deleted entries in a story.
  Future<int> countByStory(String storyId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM entries WHERE storyId = ? AND isDeleted = 0',
      [storyId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  /// All non-deleted entries across all stories (for global search).
  Future<List<Entry>> getAll() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entries',
      where: 'isDeleted = ?',
      whereArgs: [0],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(Entry.fromMap).toList();
  }
}
