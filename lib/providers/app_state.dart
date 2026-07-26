import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/lock_service.dart';
import '../services/supabase_service.dart';
import '../models/story.dart';
import '../models/entry.dart';
import '../models/todo.dart';
import '../models/time_capsule.dart';
import '../data/story_dao.dart';
import '../data/entry_dao.dart';
import '../data/todo_dao.dart';
import '../data/capsule_dao.dart';
import '../services/notification_service.dart';

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
  bool _hasSeenOnboarding = false;
  bool _isConfettiEnabled = true;
  String _preferredFont = 'crimsonPro';

  bool get isDarkMode => _storyThemeOverride == 'dark'
      ? true
      : _storyThemeOverride == 'light'
          ? false
          : _isDarkMode;
  bool get isBiometricEnabled => _isBiometricEnabled;
  bool get hasSeenOnboarding => _hasSeenOnboarding;
  bool get isConfettiEnabled => _isConfettiEnabled;
  String get preferredFont => _preferredFont;

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

  // ── Story theme override ──────────────────────────────────────────────────
  String? _storyThemeOverride; // 'dark', 'light', or null

  // ── Loading state ─────────────────────────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Lock state ────────────────────────────────────────────────────────────
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isLockEnabled = false;
  bool get isLockEnabled => _isLockEnabled;

  void setLockEnabled(bool v) {
    _isLockEnabled = v;
    if (!v) _isLocked = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _loadSettings();

    // Check PIN lock — must happen before navigating to HomeScreen
    _isLockEnabled = await LockService.instance.hasPin();
    if (_isLockEnabled) _isLocked = true;
    await _loadStories();
    await _loadDeletedEntries();
    await _loadTodos();
    await _loadTimeCapsules();
    await _loadTimeCapsuleEntries();
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
    _hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;
    _isConfettiEnabled = prefs.getBool('isConfettiEnabled') ?? true;
    _isLocked = prefs.getBool('isLocked') ?? false;
    _preferredFont = prefs.getString('preferredFont') ?? 'crimsonPro';
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

  Future<void> markOnboardingSeen() async {
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);
  }

  Future<void> resetOnboarding() async {
    _hasSeenOnboarding = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', false);
  }

  Future<void> setConfetti(bool value) async {
    _isConfettiEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isConfettiEnabled', value);
  }

  Future<void> setPreferredFont(String font) async {
    _preferredFont = font;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredFont', font);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STORIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadStories() async {
    _stories = await StoryDao.instance.getAll();
    // Apply saved custom drag order
    final _orderPrefs = await SharedPreferences.getInstance();
    final savedOrder = _orderPrefs.getStringList('storyOrder') ?? [];
    if (savedOrder.isNotEmpty) {
      _stories.sort((a, b) {
        final ai = savedOrder.indexOf(a.id);
        final bi = savedOrder.indexOf(b.id);
        if (ai == -1) return 1;
        if (bi == -1) return -1;
        return ai.compareTo(bi);
      });
    }
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
    String? coverImage,
  }) async {
    final story = Story(title: title, description: description, coverImage: coverImage);
    await StoryDao.instance.insert(story);
    _stories.insert(0, story);
    await selectStory(story);
    notifyListeners();
    return story;
  }

  Future<void> selectStory(Story story) async {
    _activeStory = story;
    _storyThemeOverride = story.themeLock;
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

  Future<void> reorderStories(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex--;
    final story = _stories.removeAt(oldIndex);
    _stories.insert(newIndex, story);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('storyOrder', _stories.map((s) => s.id).toList());
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
    // If this entry was published to Sanctuary, remove it there too
    SupabaseService.instance.deletePublishedEntry(id);
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

  /// Locks the app — shows lock screen overlay requiring biometric to re-enter.
  Future<void> lockApp() async {
    _isLocked = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLocked', true);
  }

  /// Called by LockScreen after successful biometric auth.
  void unlockApp() {
    _isLocked = false;
    notifyListeners();
    // Fire-and-forget — no need to await prefs clear
    SharedPreferences.getInstance().then((prefs) => prefs.remove('isLocked'));
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
    if (deadline != null) {
      NotificationService.instance.scheduleTaskDeadline(
        taskId: todo.id,
        title: title,
        deadline: deadline,
      );
    }
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
    // Notify if any capsules are ready and not yet opened
    final ready =
        _timeCapsules.where((c) => c.isReadyToOpen && !c.isOpened).toList();
    if (ready.isNotEmpty) {
      NotificationService.instance.showTimeCapsuleReady(
        ready.first.message,
      );
    }
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
}
