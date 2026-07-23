import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// ─────────────────────────────────────────────────────────────────────────────
// DATABASE HELPER
// Handles DB initialization, schema creation, and version migrations.
// All CRUD operations live in their respective DAO files, not here.
// ─────────────────────────────────────────────────────────────────────────────

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;
  static const int _version = 5;
  static const String _dbName = 'flow.db';

  Future<Database> get database async {
    _db ??= await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _version,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  // Enable foreign key enforcement
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createStories(db);
    await _createEntries(db);
    await _createTodos(db);
    await _createTimeCapsules(db);
    await _createAppLog(db);
    await _createEntryVersions(db);
  }

  // ── Table creation ────────────────────────────────────────────────────────

  Future<void> _createStories(Database db) async {
    await db.execute('''
      CREATE TABLE stories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isLocked INTEGER NOT NULL DEFAULT 0,
        isDeleted INTEGER NOT NULL DEFAULT 0,
        themeLock TEXT
      )
    ''');
  }

  Future<void> _createEntries(Database db) async {
    await db.execute('''
      CREATE TABLE entries (
        id TEXT PRIMARY KEY,
        storyId TEXT NOT NULL,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        timeSpentSeconds INTEGER NOT NULL DEFAULT 0,
        moodColor TEXT NOT NULL DEFAULT 'default',
        headerImage TEXT,
        headerImageRatio TEXT,
        images TEXT NOT NULL DEFAULT '[]',
        isDeleted INTEGER NOT NULL DEFAULT 0,
        blocks_json TEXT,
        textAlignment TEXT NOT NULL DEFAULT 'justify',
        FOREIGN KEY (storyId) REFERENCES stories (id) ON DELETE CASCADE
      )
    ''');
    // Index for fast story-filtered entry queries
    await db.execute(
      'CREATE INDEX idx_entries_storyId ON entries (storyId)',
    );
  }

  Future<void> _createTodos(Database db) async {
    await db.execute('''
      CREATE TABLE todos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        deadline TEXT,
        isArchived INTEGER NOT NULL DEFAULT 0,
        completedAt TEXT
      )
    ''');
  }

  Future<void> _createTimeCapsules(Database db) async {
    await db.execute('''
      CREATE TABLE time_capsules (
        id TEXT PRIMARY KEY,
        message TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        openAt TEXT NOT NULL,
        isOpened INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createAppLog(Database db) async {
    await db.execute('''
      CREATE TABLE app_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        category TEXT NOT NULL,
        detail TEXT NOT NULL
      )
    ''');
  }

  // ── Migrations ────────────────────────────────────────────────────────────
  // Add ALTER TABLE statements here as version increments.

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE entries ADD COLUMN blocks_json TEXT');
      await _createEntryVersions(db);
    }
    if (oldVersion < 3) {
      // Add text alignment column — was missing from v2 schema
      await db.execute(
          "ALTER TABLE entries ADD COLUMN textAlignment TEXT NOT NULL DEFAULT 'justify'");
    }
    if (oldVersion < 4) {
      // Add header image ratio column for aspect ratio support
      await db.execute('ALTER TABLE entries ADD COLUMN headerImageRatio TEXT');
    }
    if (oldVersion < 5) {
      await db.execute('ALTER TABLE stories ADD COLUMN themeLock TEXT');
    }
  }

  // ── Utility ───────────────────────────────────────────────────────────────

  /// Logs an internal app event (writing session, atmosphere change, etc.)
  Future<void> log(String category, String detail) async {
    final db = await database;
    await db.insert('app_log', {
      'timestamp': DateTime.now().toIso8601String(),
      'category': category,
      'detail': detail,
    });
  }

  /// Hard-deletes all data. Used in Settings → "Erase Everything".
  Future<void> nukeAll() async {
    final db = await database;
    await db.delete('entry_versions');
    await db.delete('entries');
    await db.delete('stories');
    await db.delete('todos');
    await db.delete('time_capsules');
    await db.delete('app_log');
  }

  Future<void> _createEntryVersions(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_versions (
        id TEXT PRIMARY KEY,
        entryId TEXT NOT NULL,
        title TEXT NOT NULL,
        blocksJson TEXT NOT NULL,
        timeSpentSeconds INTEGER NOT NULL DEFAULT 0,
        savedAt TEXT NOT NULL,
        label TEXT,
        FOREIGN KEY (entryId) REFERENCES entries (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_versions_entryId ON entry_versions (entryId)',
    );
  }

  /// Returns the total size of the DB file in bytes (for Settings info).
  Future<int> dbSizeBytes() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()");
    return (result.first['size'] as int?) ?? 0;
  }
}
