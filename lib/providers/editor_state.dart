import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'atmosphere_state.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR STATE
// Tracks everything that happens inside the entry editor:
//   - Writing session timer (Proof of Work)
//   - Word count (live)
//   - Auto-save debouncing
//   - Comfort mode trigger (sentiment detection)
//   - Whisper text display
// This provider is scoped to the editor's lifetime. AppState.addEntryTimeSpent()
// is called when the editor closes and this state is reset.
// ─────────────────────────────────────────────────────────────────────────────

// ── Comfort Engine keywords ────────────────────────────────────────────────
// Requires 3+ matches to trigger (per Master Specification §5).
const List<String> _comfortTriggerWords = [
  'lonely',
  'grief',
  'tired',
  'empty',
  'broken',
  'sad',
  'pain',
  'loss',
  'alone',
  'hurt',
  'dark',
  'hopeless',
  'numb',
  'heavy',
  'weary',
  'overwhelmed',
  'desperate',
  'scared',
  'afraid',
  'anxious',
  'worthless',
  'defeated',
  'forgotten',
];

const int _comfortThreshold = 3;

// ── Whisper messages ──────────────────────────────────────────────────────
const List<String> _whisperMessages = [
  'take your time',
  'you\'re not alone',
  'it\'s okay',
  'breathe',
  'one moment at a time',
];

class EditorState extends ChangeNotifier {
  // ── Session timing (Proof of Work) ────────────────────────────────────────
  DateTime? _sessionStart;
  int _sessionSeconds = 0; // Seconds accumulated this session
  Timer? _sessionTimer;

  int get sessionSeconds => _sessionSeconds;

  // ── Word count ────────────────────────────────────────────────────────────
  int _wordCount = 0;
  int get wordCount => _wordCount;

  // ── Auto-save ─────────────────────────────────────────────────────────────
  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  /// Called by editor when it's ready to persist. Set externally.
  VoidCallback? onAutoSave;

  // ── Comfort mode ──────────────────────────────────────────────────────────
  bool _isComfortMode = false;
  bool get isComfortMode => _isComfortMode;

  // Slow transition: 50 steps over 50 seconds
  // Progress goes from 0.0 to 1.0 — used by AtmosphereOverlay for lerp.
  double _comfortProgress = 0.0;
  double get comfortProgress => _comfortProgress;
  Timer? _comfortTransitionTimer;

  // ── Whisper text ──────────────────────────────────────────────────────────
  bool _showWhisper = false;
  String _whisperText = '';
  Timer? _whisperTimer;

  bool get showWhisper => _showWhisper;
  String get whisperText => _whisperText;

  // ── Word milestone easter eggs ─────────────────────────────────────────────
  int _lastMilestone = 0;
  bool _showMilestone = false;
  int _milestoneWords = 0;
  bool get showMilestone => _showMilestone;
  int get milestoneWords => _milestoneWords;

  // ── Long session easter egg ────────────────────────────────────────────────
  bool _longSessionTriggered = false;
  Timer? _longSessionTimer;

  // ── Atmosphere reference (to push comfort mode upstream) ──────────────────
  AtmosphereState? _atmosphereState;

  void bindAtmosphere(AtmosphereState atmosphere) {
    _atmosphereState = atmosphere;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION TIMER
  // ─────────────────────────────────────────────────────────────────────────

  /// Call when the editor screen is pushed / becomes active.
  void startSession() {
    _sessionStart = DateTime.now();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _sessionSeconds++;
      // No notifyListeners here — it would rebuild too often.
    });

    // Long session easter egg: trigger at 30 min
    _longSessionTriggered = false;
    _longSessionTimer = Timer(const Duration(minutes: 30), () {
      if (!_longSessionTriggered) {
        _longSessionTriggered = true;
        _showWhisperMessage(override: '30 minutes in. this is real.');
      }
    });
  }

  /// Returns accumulated session seconds and resets for next session.
  int stopSession() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
    final elapsed = _sessionStart != null
        ? DateTime.now().difference(_sessionStart!).inSeconds
        : _sessionSeconds;
    final total = elapsed > _sessionSeconds ? elapsed : _sessionSeconds;
    _sessionSeconds = 0;
    _sessionStart = null;
    return total;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTENT CHANGE HANDLER
  // Called by editor body TextField's onChanged.
  // ─────────────────────────────────────────────────────────────────────────

  Timer? _sentimentDebounce;

  void onContentChanged(String content) {
    _updateWordCount(content);
    _scheduleAutoSave();
    _checkWordMilestone(_wordCount);
    // Sentiment scanning walks every trigger word against the full entry
    // text — cheap for a short entry, wasteful to redo on every keystroke
    // once it gets long. Debounce it instead of running it live.
    _sentimentDebounce?.cancel();
    _sentimentDebounce = Timer(const Duration(milliseconds: 400), () {
      _checkSentiment(content);
    });
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WORD COUNT
  // ─────────────────────────────────────────────────────────────────────────

  void _updateWordCount(String content) {
    if (content.isEmpty) {
      _wordCount = 0;
      return;
    }
    // Single-pass scan instead of trim + split + filter — avoids allocating
    // a trimmed copy and an intermediate list on every keystroke, which
    // matters once entries get long (5,000+ words).
    int count = 0;
    bool inWord = false;
    for (int i = 0; i < content.length; i++) {
      final isSpace = content.codeUnitAt(i) <= 32;
      if (isSpace) {
        inWord = false;
      } else if (!inWord) {
        inWord = true;
        count++;
      }
    }
    _wordCount = count;
  }

// ─────────────────────────────────────────────────────────────────────────
  // WORD MILESTONE EASTER EGG
  // Celebrates 500, 1000, 2000, 5000 words with a gentle whisper.
  // ─────────────────────────────────────────────────────────────────────────

  static const List<int> _milestones = [500, 1000, 2000, 5000];
  static const Map<int, String> _milestoneMessages = {
    500: '500 words. keep going.',
    1000: 'a thousand words. remarkable.',
    2000: 'two thousand words. you\'re in it.',
    5000: 'five thousand words. extraordinary.',
  };

  void _checkWordMilestone(int count) {
    for (final m in _milestones) {
      if (count >= m && _lastMilestone < m) {
        _lastMilestone = m;
        _triggerMilestone(m);
        break;
      }
    }
  }

  void _triggerMilestone(int words) {
    HapticFeedback.mediumImpact();
    _milestoneWords = words;
    _showMilestone = true;
    notifyListeners();
    Timer(const Duration(milliseconds: 3500), () {
      _showMilestone = false;
      notifyListeners();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTO-SAVE
  // Debounced 1200ms after last keystroke.
  // ─────────────────────────────────────────────────────────────────────────

  void _scheduleAutoSave() {
    _hasUnsavedChanges = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1200), () {
      onAutoSave?.call();
      _hasUnsavedChanges = false;
    });
  }

  /// Call immediately (e.g. on back chevron tap) to force a save.
  void flushSave() {
    _autoSaveTimer?.cancel();
    if (_hasUnsavedChanges) {
      onAutoSave?.call();
      _hasUnsavedChanges = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // COMFORT ENGINE
  // Detects heavy/sad content and shifts background over 45–60 seconds.
  // Requires 3+ trigger word matches.
  // ─────────────────────────────────────────────────────────────────────────

  void _checkSentiment(String content) {
    if (_isComfortMode) return; // Already triggered, don't re-trigger

    final lower = content.toLowerCase();
    int matches = 0;
    for (final word in _comfortTriggerWords) {
      // Whole-word match using word boundaries
      final regex = RegExp(r'\b' + word + r'\b');
      if (regex.hasMatch(lower)) {
        matches++;
        if (matches >= _comfortThreshold) break;
      }
    }

    if (matches >= _comfortThreshold) {
      _triggerComfortMode();
    }
  }

  void _triggerComfortMode() {
    _isComfortMode = true;
    _atmosphereState?.setComfortMode(true);

    // Show whisper text immediately (3 seconds)
    _showWhisperMessage();

    // Slow transition over 50 steps × 1 second = ~50 seconds
    _comfortProgress = 0.0;
    _comfortTransitionTimer?.cancel();
    _comfortTransitionTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _comfortProgress = (t.tick / 50).clamp(0.0, 1.0);
      notifyListeners();
      if (t.tick >= 50) t.cancel();
    });

    notifyListeners();
  }

  void _showWhisperMessage({String? override}) {
    final messages = List<String>.from(_whisperMessages)..shuffle();
    _whisperText = override ?? messages.first;
    _showWhisper = true;
    notifyListeners();

    _whisperTimer?.cancel();
    _whisperTimer = Timer(const Duration(seconds: 3), () {
      _showWhisper = false;
      notifyListeners();
    });
  }

  /// Manually reset comfort mode (e.g. if user clears content).
  void resetComfortMode() {
    _isComfortMode = false;
    _comfortProgress = 0.0;
    _showWhisper = false;
    _comfortTransitionTimer?.cancel();
    _whisperTimer?.cancel();
    _atmosphereState?.setComfortMode(false);
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FULL RESET
  // Called when editor is closed entirely (navigated away).
  // ─────────────────────────────────────────────────────────────────────────

  void reset() {
    _sessionTimer?.cancel();
    _autoSaveTimer?.cancel();
    _comfortTransitionTimer?.cancel();
    _whisperTimer?.cancel();
    _longSessionTimer?.cancel();
    _sentimentDebounce?.cancel();
    _longSessionTriggered = false;
    _showMilestone = false;
    _lastMilestone = 0;

    _sessionSeconds = 0;
    _sessionStart = null;
    _wordCount = 0;
    _hasUnsavedChanges = false;
    _isComfortMode = false;
    _comfortProgress = 0.0;
    _showWhisper = false;
    _whisperText = '';

    _atmosphereState?.setComfortMode(false);

    notifyListeners();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _autoSaveTimer?.cancel();
    _comfortTransitionTimer?.cancel();
    _whisperTimer?.cancel();
    _longSessionTimer?.cancel();
    _sentimentDebounce?.cancel();
    super.dispose();
  }
}
