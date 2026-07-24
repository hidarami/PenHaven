import 'package:sqflite/sqflite.dart';
import '../models/entry_version.dart';
import 'database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VERSION DAO
// Manages entry version snapshots.
// Auto-prunes to keep only the 20 most recent versions per entry.
// ─────────────────────────────────────────────────────────────────────────────

class VersionDao {
  VersionDao._();
  static final VersionDao instance = VersionDao._();

  static const int _maxVersionsPerEntry = 20;

  Future<void> saveVersion(EntryVersion version) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'entry_versions',
      version.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _pruneOldVersions(db, version.entryId);
  }

  Future<List<EntryVersion>> getVersionsForEntry(String entryId) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entry_versions',
      where: 'entryId = ?',
      whereArgs: [entryId],
      orderBy: 'savedAt DESC',
    );
    return maps.map(EntryVersion.fromMap).toList();
  }

  Future<EntryVersion?> getVersion(String id) async {
    final db = await DatabaseHelper.instance.database;
    final maps = await db.query(
      'entry_versions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return EntryVersion.fromMap(maps.first);
  }

  Future<void> updateLabel(String id, String label) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'entry_versions',
      {'label': label},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteVersion(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('entry_versions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllVersionsForEntry(String entryId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete(
      'entry_versions',
      where: 'entryId = ?',
      whereArgs: [entryId],
    );
  }

  Future<int> countForEntry(String entryId) async {
    final db = await DatabaseHelper.instance.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM entry_versions WHERE entryId = ?',
      [entryId],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  Future<void> _pruneOldVersions(Database db, String entryId) async {
    final count = await db.rawQuery(
      'SELECT COUNT(*) as c FROM entry_versions WHERE entryId = ?',
      [entryId],
    );
    final n = (count.first['c'] as int?) ?? 0;
    if (n > _maxVersionsPerEntry) {
      // Delete oldest beyond limit
      await db.rawDelete('''
        DELETE FROM entry_versions
        WHERE entryId = ?
        AND id NOT IN (
          SELECT id FROM entry_versions
          WHERE entryId = ?
          ORDER BY savedAt DESC
          LIMIT ?
        )
      ''', [entryId, entryId, _maxVersionsPerEntry]);
    }
  }
}
