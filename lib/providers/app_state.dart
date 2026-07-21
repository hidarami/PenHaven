import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/story.dart';
import '../models/entry.dart';
import '../models/todo.dart';
import '../models/time_capsule.dart';
import '../models/period_log.dart';
import '../data/story_dao.dart';
import '../data/entry_dao.dart';
import '../data/todo_dao.dart';
import '../data/capsule_dao.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP STATE
// Central provider for all persistent app data and user settings.
// Atmosphere logic lives in AtmosphereState.
// Editor session logic lives in EditorState.
// ─────────────────────────────────────────────────────────────────────────────

class AppState extends ChangeNotifier {
  // ── Settings ──────────────────────────────────────────────────────────────
  bool _isDarkMode = false;
  bool _isBiometricEnabled = false;
  bool _isPeriodTrackerEnabled = false;
  bool _hasSeenOnboarding = false;
  bool _isConfettiEnabled = true;
  String _openWeatherApiKey = '';

  bool get isDarkMode => _isDarkMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get isPeriodTrackerEnabled => _isPeriodTrackerEnabled;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isConfettiEnabled => _isConfettiEnabled;
  String get openWeatherApiKey => _openWeatherApiKey;

  // ── Stories ───────────────────────────────────────────────────────────────
  List<Story> _stories = [];
  Story? _activeStory;

  List<Story> get stories => _stories;
  Story? get activeStory => _activeStory;
  bool get hasStories => _stories.isNotEmpty;

  // ── Entries ───────────────────────────────────────────────────────────────
  List<Entry> _currentEntries = [];
  List<Entry> _deletedEntries = []; // Soft-deleted entries for the bin

  List<Entry> get currentEntries => _currentEntries;
  int get entryCount => _currentEntries.length;
  List<Entry> get deletedEntries => _deletedEntries;

  // ── Todos ─────────────────────────────────────────────────────────────────
  List<Todo> _activeTodos = [];
  List<Todo> _archivedTodos = [];

  List<Todo> get activeTodos => _activeTodos;
  List<Todo> get archivedTodos => _archivedTodos;

  // ── Time Capsules ─────────────────────────────────────────────────────────
  List<TimeCapsule> _timeCapsules = [];
  List<Entry> _timeCapsuleEntries = []; // "On this day" entries

  List<TimeCapsule> get timeCapsules => _timeCapsules;
  List<Entry> get timeCapsuleEntries => _timeCapsuleEntries;

  // ── Period Logs ───────────────────────────────────────────────────────────
  List<PeriodLog> _periodLogs = [];

  List<PeriodLog> get periodLogs => _periodLogs;

  // ── Loading state ─────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _loadSettings();
    await _loadStories();
    await _loadDeletedEntries();
    await _loadTodos();
    await _loadTimeCapsules();
    await _loadTimeCapsuleEntries();
    if (_isPeriodTrackerEnabled) await _loadPeriodLogs();

    _isLoading = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTINGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _isBiometricEnabled = prefs.getBool('isBiometricEnabled') ?? false;
    _isPeriodTrackerEnabled = prefs.getBool('isPeriodTrackerEnabled') ?? false;
    _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    _isConfettiEnabled = prefs.getBool('isConfettiEnabled') ?? true;
    _openWeatherApiKey = prefs.getString('openWeatherApiKey') ?? '';
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  Future<void> setBiometric(bool value) async {
    _isBiometricEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBiometricEnabled', value);
  }

  Future<void> setPeriodTracker(bool value) async {
    _isPeriodTrackerEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPeriodTrackerEnabled', value);
    if (value) await _loadPeriodLogs();
  }

  Future<void> markOnboardingSeen() async {
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  Future<void> setConfetti(bool value) async {
    _isConfettiEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isConfettiEnabled', value);
  }

  Future<void> setOpenWeatherApiKey(String key) async {
    _openWeatherApiKey = key;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('openWeatherApiKey', key);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadStories() async {
    _stories = await StoryDao.instance.getAll();
    // Auto-select first story if none active
    if (_activeStory == null && _stories.isNotEmpty) {
      await selectStory(_stories.first);
    } else if (_activeStory != null) {
      // Refresh active story from DB in case it changed
      final refreshed = await StoryDao.instance.getById(_activeStory!.id);
      if (refreshed != null) {
        _activeStory = refreshed;
        await _loadEntriesForActiveStory();
      }
    }
  }

  Future<Story> createStory({
    required String title,
    String description = '',
  }) async {
    final story = Story(title: title, description: description);
    await StoryDao.instance.insert(story);
    _stories.insert(0, story);
    await selectStory(story);
    notifyListeners();
    return story;
  }

  Future<void> selectStory(Story story) async {
    _activeStory = story;
    await _loadEntriesForActiveStory();
    notifyListeners();
  }

  Future<void> updateStory(Story story) async {
    await StoryDao.instance.update(story);
    final idx = _stories.indexWhere((s) => s.id == story.id);
    if (idx != -1) _stories[idx] = story;
    if (_activeStory?.id == story.id) _activeStory = story;
    notifyListeners();
  }

  Future<void> deleteStory(String id) async {
    await StoryDao.instance.softDelete(id);
    _stories.removeWhere((s) => s.id == id);
    if (_activeStory?.id == id) {
      _activeStory = _stories.isNotEmpty ? _stories.first : null;
      _currentEntries = [];
      if (_activeStory != null) await _loadEntriesForActiveStory();
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENTRIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadEntriesForActiveStory() async {
    if (_activeStory == null) {
      _currentEntries = [];
      return;
    }
    _currentEntries = await EntryDao.instance.getByStory(_activeStory!.id);
  }

  Future<void> _loadDeletedEntries() async {
    // Load all soft-deleted entries for the bin screen
    _deletedEntries = await EntryDao.instance.getDeleted();
  }

  Future<Entry> createEntry() async {
    if (_activeStory == null) {
      throw StateError('No active story selected');
    }
    final entry = Entry(storyId: _activeStory!.id);
    await EntryDao.instance.insert(entry);
    _currentEntries.insert(0, entry);
    notifyListeners();
    return entry;
  }

  Future<void> saveEntry(Entry entry) async {
    await EntryDao.instance.update(entry);
    final idx = _currentEntries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      _currentEntries[idx] = entry;
    } else {
      _currentEntries.insert(0, entry);
    }
    notifyListeners();
  }

  /// Called when editor closes — adds session time to DB total.
  Future<void> addEntryTimeSpent(String entryId, int seconds) async {
    if (seconds <= 0) return;
    await EntryDao.instance.addTimeSpent(entryId, seconds);
    final idx = _currentEntries.indexWhere((e) => e.id == entryId);
    if (idx != -1) {
      _currentEntries[idx].timeSpentSeconds += seconds;
      notifyListeners();
    }
  }

  Future<void> deleteEntry(String id) async {
    await EntryDao.instance.softDelete(id);
    // Move entry to deleted list in memory — avoids a DB round-trip
    final idx = _currentEntries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final deleted = _currentEntries[idx].copyWith(isDeleted: true);
      _currentEntries.removeAt(idx);
      _deletedEntries.insert(0, deleted);
    }
    notifyListeners();
  }

  Future<void> refreshEntries() async {
    await _loadEntriesForActiveStory();
    notifyListeners();
  }

  /// Gets all entries including deleted ones for the bin/restore functionality.
  /// Returns all entries including soft-deleted ones (for the bin screen).
  List<Entry> get allEntries => [..._currentEntries, ..._deletedEntries];

  /// Locks the app and requires biometric authentication to unlock.
  Future<void> lockApp() async {
    // Implementation would depend on biometric authentication
    // For now, this is a placeholder
    notifyListeners();
  }

  /// Restores a soft-deleted entry.
  Future<void> restoreEntry(String id) async {
    await EntryDao.instance.restore(id);
    // Move from deleted list back to current list (if it belongs to active story)
    final idx = _deletedEntries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final restored = _deletedEntries[idx].copyWith(isDeleted: false);
      _deletedEntries.removeAt(idx);
      if (_activeStory?.id == restored.storyId) {
        _currentEntries.insert(0, restored);
      }
    }
    notifyListeners();
  }

  /// Permanently deletes a soft-deleted entry.
  Future<void> permanentlyDeleteEntry(String id) async {
    await EntryDao.instance.hardDelete(id);
    _deletedEntries.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  /// Exports all entries as a ZIP file for download.
  Future<void> exportAllEntries() async {
    // Implementation would depend on file export functionality
    // For now, this is a placeholder
    notifyListeners();
  }

  /// Clears all soft-deleted entries from the database.
  Future<void> clearDeletedEntries() async {
    // Hard-delete every soft-deleted entry from the database
    for (final entry in _deletedEntries) {
      await EntryDao.instance.hardDelete(entry.id);
    }
    _deletedEntries.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODOS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadTodos() async {
    // Run mercy archival before loading
    await TodoDao.instance.archiveExpired();
    _activeTodos = await TodoDao.instance.getActive();
    _archivedTodos = await TodoDao.instance.getArchived();
  }

  Future<Todo> addTodo({required String title, DateTime? deadline}) async {
    final todo = Todo(title: title, deadline: deadline);
    await TodoDao.instance.insert(todo);
    _activeTodos.add(todo);
    notifyListeners();
    return todo;
  }

  Future<void> updateTodoTitle(String id, String newTitle) async {
    final idx = _activeTodos.indexWhere((t) => t.id == id);
    if (idx == -1) return;
    final updated = _activeTodos[idx].copyWith(title: newTitle);
    _activeTodos[idx] = updated;
    await TodoDao.instance.update(updated);
    notifyListeners();
  }

  /// Marks complete in DB. UI calls this immediately; AnimatedOpacity
  /// handles the 3-second fade, then calls archiveTodo().
  Future<void> completeTodo(String id) async {
    await TodoDao.instance.complete(id);
    final idx = _activeTodos.indexWhere((t) => t.id == id);
    if (idx != -1) {
      _activeTodos[idx] = _activeTodos[idx].copyWith(
        isCompleted: true,
        completedAt: DateTime.now(),
      );
    }
    notifyListeners();
  }

  /// Called after the 3-second fade animation finishes.
  Future<void> archiveTodo(String id) async {
    await TodoDao.instance.archive(id);
    _activeTodos.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  /// Restores an archived todo back to active list.
  Future<void> restoreTodo(String id) async {
    await TodoDao.instance.restore(id);
    await _loadTodos(); // Reload both active and archived lists
    notifyListeners();
  }

  /// Permanently deletes an archived todo from database.
  Future<void> permanentlyDeleteTodo(String id) async {
    await TodoDao.instance.hardDelete(id);
    _archivedTodos.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  Future<void> runMercyArchive() async {
    await _loadTodos();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TIME CAPSULES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadTimeCapsules() async {
    _timeCapsules = await CapsuleDao.instance.getAllCapsules();
  }

  Future<void> _loadTimeCapsuleEntries() async {
    _timeCapsuleEntries =
        await EntryDao.instance.getTimeCapsuleEntries(DateTime.now());
  }

  Future<void> addTimeCapsule({
    required String message,
    required DateTime openAt,
  }) async {
    final capsule = TimeCapsule(message: message, openAt: openAt);
    await CapsuleDao.instance.insertCapsule(capsule);
    _timeCapsules.add(capsule);
    notifyListeners();
  }

  Future<void> openCapsule(String id) async {
    await CapsuleDao.instance.markOpened(id);
    final idx = _timeCapsules.indexWhere((c) => c.id == id);
    if (idx != -1) {
      _timeCapsules[idx] = _timeCapsules[idx].copyWith(isOpened: true);
    }
    notifyListeners();
  }

  Future<void> deleteCapsule(String id) async {
    await CapsuleDao.instance.deleteCapsule(id);
    _timeCapsules.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  List<TimeCapsule> get readyCapsules =>
      _timeCapsules.where((c) => c.isReadyToOpen && !c.isOpened).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // PERIOD LOGS (optional)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadPeriodLogs() async {
    _periodLogs = await CapsuleDao.instance.getAllPeriodLogs();
  }

  Future<void> startPeriod() async {
    final log = PeriodLog(startDate: DateTime.now());
    await CapsuleDao.instance.insertPeriodLog(log);
    _periodLogs.insert(0, log);
    notifyListeners();
  }

  Future<void> endPeriod(String id) async {
    final idx = _periodLogs.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final updated = _periodLogs[idx].copyWith(closeLog: true);
    await CapsuleDao.instance.updatePeriodLog(updated);
    _periodLogs[idx] = updated;
    notifyListeners();
  }

  PeriodLog? get activePeriod {
    try {
      return _periodLogs.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }
}
