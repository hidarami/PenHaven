import 'package:sqflite/sqflite.dart';
import '../models/todo.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// TODO DAO
// Handles active, completed, and archived todos.
// Mercy rule enforcement lives in TodoDao.archiveExpired().
// ─────────────────────────────────────────────────────────────────────────────

class TodoDao {
  TodoDao._();
  static final TodoDao instance = TodoDao._();

  Future<void> insert(Todo todo) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'todos',
      todo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Active (non-archived, non-completed) todos, oldest first.
  Future<List<Todo>> getActive() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'todos',
      where: 'isArchived = ? AND isCompleted = ?',
      whereArgs: [0, 0],
      orderBy: 'createdAt ASC',
    );
    return maps.map(Todo.fromMap).toList();
  }

  /// Archived todos, for the Archive screen.
  Future<List<Todo>> getArchived() async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'todos',
      where: 'isArchived = ?',
      whereArgs: [1],
      orderBy: 'completedAt DESC',
    );
    return maps.map(Todo.fromMap).toList();
  }

  Future<void> update(Todo todo) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'todos',
      todo.toMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  /// Marks a todo complete and sets completedAt timestamp.
  Future<void> complete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'todos',
      {
        'isCompleted': 1,
        'completedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Archives a todo (after fade animation completes or mercy rule fires).
  Future<void> archive(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'todos',
      {'isArchived': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restores an archived todo back to active list.
  Future<void> restore(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'todos',
      {'isArchived': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> hardDelete(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  /// Mercy rule: silently archive todos that have expired.
  /// Called on app resume / Work Desk open.
  /// - With deadline: archive 24h after deadline
  /// - Without deadline: archive 48h after creation
  /// Returns the ids of todos that were archived, so the caller can cancel
  /// any pending deadline notifications for them.
  Future<List<String>> archiveExpired() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    final archivedIds = <String>[];

    // Todos with a deadline — 24h grace
    final withDeadline = await db.rawQuery(
      '''SELECT id, deadline FROM todos
         WHERE isArchived = 0 AND isCompleted = 0 AND deadline IS NOT NULL''',
    );
    for (final row in withDeadline) {
      final deadline = DateTime.parse(row['deadline'] as String);
      if (now.difference(deadline).inHours >= 24) {
        await archive(row['id'] as String);
        archivedIds.add(row['id'] as String);
      }
    }

    // Todos without a deadline — 48h after creation
    final withoutDeadline = await db.rawQuery(
      '''SELECT id, createdAt FROM todos
         WHERE isArchived = 0 AND isCompleted = 0 AND deadline IS NULL''',
    );
    for (final row in withoutDeadline) {
      final created = DateTime.parse(row['createdAt'] as String);
      if (now.difference(created).inHours >= 48) {
        await archive(row['id'] as String);
        archivedIds.add(row['id'] as String);
      }
    }

    return archivedIds;
  }

  Future<int> countActive() async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM todos WHERE isArchived = 0 AND isCompleted = 0',
    );
    return (result.first['c'] as int?) ?? 0;
  }
}
