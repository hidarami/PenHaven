import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';

import '../data/database_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKUP SERVICE
// Full JSON export and restore of the entire Flow database.
// Export: reads all tables → serialises to JSON → shares as file.
// Import: parses JSON → clears DB → writes all tables.
// Images are NOT included in the backup (too large); paths are preserved.
// ─────────────────────────────────────────────────────────────────────────────

class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const List<String> _tables = [
    'stories',
    'entries',
    'todos',
    'time_capsules',
    'period_logs',
    'app_log',
    'entry_versions',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  // EXPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> exportBackup(BuildContext context) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final backup = <String, dynamic>{
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'tables': <String, dynamic>{},
      };

      for (final table in _tables) {
        try {
          final rows = await db.query(table);
          backup['tables'][table] = rows;
        } catch (_) {
          // Table might not exist yet
          backup['tables'][table] = <Map<String, dynamic>>[];
        }
      }

      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd_HH-mm').format(DateTime.now());
      final file = File(p.join(dir.path, 'flow_backup_$dateStr.json'));
      await file.writeAsString(json, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Flow Backup — $dateStr',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // IMPORT
  // ─────────────────────────────────────────────────────────────────────────

  Future<RestoreResult> importBackup(String jsonPath) async {
    try {
      final file = File(jsonPath);
      if (!await file.exists()) {
        return RestoreResult.error('Backup file not found.');
      }

      final json = await file.readAsString(encoding: utf8);
      final backup = jsonDecode(json) as Map<String, dynamic>;

      if (backup['tables'] == null) {
        return RestoreResult.error('Invalid backup format.');
      }

      final db = await DatabaseHelper.instance.database;
      final tables = backup['tables'] as Map<String, dynamic>;

      await db.transaction((txn) async {
        // Clear all tables (reverse order for FK constraints)
        for (final table in _tables.reversed) {
          try {
            await txn.delete(table);
          } catch (_) {}
        }

        // Insert all rows
        for (final table in _tables) {
          final rows = tables[table] as List<dynamic>? ?? [];
          for (final row in rows) {
            try {
              await txn.insert(
                table,
                Map<String, dynamic>.from(row as Map),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (_) {}
          }
        }
      });

      int totalRows = 0;
      for (final rows in tables.values) {
        totalRows += (rows as List).length;
      }

      return RestoreResult.success(totalRows);
    } catch (e) {
      return RestoreResult.error('Restore failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PARTIAL EXPORT — Entries only as readable JSON
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> exportEntriesAsJson(BuildContext context) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final stories = await db.query('stories', where: 'isDeleted = 0');
      final entries = await db.query('entries', where: 'isDeleted = 0');

      final export = {
        'exportedAt': DateTime.now().toIso8601String(),
        'stories': stories,
        'entries': entries,
      };

      final json = const JsonEncoder.withIndent('  ').convert(export);
      final dir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final file = File(p.join(dir.path, 'flow_entries_$dateStr.json'));
      await file.writeAsString(json, encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'Flow Entries Export — $dateStr',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }
}

class RestoreResult {
  final bool success;
  final String? error;
  final int rowsRestored;

  const RestoreResult._({
    required this.success,
    this.error,
    this.rowsRestored = 0,
  });

  factory RestoreResult.success(int rows) =>
      RestoreResult._(success: true, rowsRestored: rows);

  factory RestoreResult.error(String msg) =>
      RestoreResult._(success: false, error: msg);
}