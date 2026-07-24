import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/published_entry.dart';
import '../models/community_comment.dart';
import '../models/entry.dart';
import '../services/supabase_service.dart';

class CommunityState extends ChangeNotifier {
  List<PublishedEntry> _feed = [];
  List<PublishedEntry> _myPosts = [];
  bool _feedLoading = false;
  bool _myPostsLoading = false;
  bool _hasMore = true;
  int _page = 0;
  static const int _pageSize = 20;
  String? _error;

  List<PublishedEntry> get feed => _feed;
  List<PublishedEntry> get myPosts => _myPosts;
  bool get feedLoading => _feedLoading;
  bool get myPostsLoading => _myPostsLoading;
  bool get hasMore => _hasMore;
  String? get error => _error;

  // ── Profile cache ──────────────────────────────────────────────────────────
  String? _profileDisplayName;
  String? _profileImagePath;
  String? get profileDisplayName => _profileDisplayName;
  String? get profileImagePath => _profileImagePath;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _profileDisplayName = prefs.getString('communityDisplayName');
    _profileImagePath = prefs.getString('communityProfileImage');
    notifyListeners();
  }

  Future<void> saveProfile({String? name, String? imagePath}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _profileDisplayName = name;
      await prefs.setString('communityDisplayName', name);
    }
    if (imagePath != null) {
      _profileImagePath = imagePath;
      await prefs.setString('communityProfileImage', imagePath);
    }
    notifyListeners();
  }

  // ── Featured entry management ──────────────────────────────────────────────
  String? _featuredEntryId;
  DateTime? _featuredUntil;

  /// Returns pinned featured entry ID only if it hasn't expired.
  String? get featuredEntryId {
    if (_featuredEntryId == null || _featuredUntil == null) return null;
    return _featuredUntil!.isAfter(DateTime.now()) ? _featuredEntryId : null;
  }

  /// Human-readable label for how long featured entry has remaining.
  String? get featuredUntilLabel {
    if (featuredEntryId == null || _featuredUntil == null) return null;
    final diff = _featuredUntil!.difference(DateTime.now());
    if (diff.inDays > 1) return '${diff.inDays}d remaining';
    if (diff.inHours > 0) return '${diff.inHours}h remaining';
    return 'Expiring soon';
  }

  Future<void> loadFeatured() async {
    final prefs = await SharedPreferences.getInstance();
    _featuredEntryId = prefs.getString('featuredEntryId');
    final untilMs = prefs.getInt('featuredEntryUntil');
    _featuredUntil =
        untilMs != null ? DateTime.fromMillisecondsSinceEpoch(untilMs) : null;
    notifyListeners();
  }

  /// Pins [entryId] as the featured reflection for [duration] (default 7 days).
  Future<void> setFeatured(String entryId,
      {Duration duration = const Duration(days: 7)}) async {
    final until = DateTime.now().add(duration);
    _featuredEntryId = entryId;
    _featuredUntil = until;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('featuredEntryId', entryId);
    await prefs.setInt('featuredEntryUntil', until.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> clearFeatured() async {
    _featuredEntryId = null;
    _featuredUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('featuredEntryId');
    await prefs.remove('featuredEntryUntil');
    notifyListeners();
  }

  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedLoading) return;
    if (refresh) {
      _feed = [];
      _page = 0;
      _hasMore = true;
      _error = null;
    }
    if (!_hasMore) return;

    _feedLoading = true;
    notifyListeners();

    try {
      final entries = await SupabaseService.instance.getPublishedEntries(
        page: _page,
        limit: _pageSize,
      );

      final userId = SupabaseService.instance.userId;
      if (userId != null && entries.isNotEmpty) {
        final clappedIds = await SupabaseService.instance.getClappedEntryIds(
          entries.map((e) => e.id).toList(),
        );
        for (final e in entries) {
          e.hasClapped = clappedIds.contains(e.id);
          e.isOwner = e.userId == userId;
        }
      }

      if (entries.length < _pageSize) _hasMore = false;
      _page++;
      _feed.addAll(entries);
    } catch (e) {
      _error = e.toString();
      debugPrint('[CommunityState] loadFeed: $e');
    }

    _feedLoading = false;
    notifyListeners();
  }

  Future<void> loadMyPosts() async {
    _myPostsLoading = true;
    notifyListeners();

    try {
      _myPosts = await SupabaseService.instance.getMyPublishedEntries();
      final userId = SupabaseService.instance.userId;
      if (userId != null && _myPosts.isNotEmpty) {
        final clappedIds = await SupabaseService.instance.getClappedEntryIds(
          _myPosts.map((e) => e.id).toList(),
        );
        for (final e in _myPosts) {
          e.hasClapped = clappedIds.contains(e.id);
          e.isOwner = true;
        }
      }
    } catch (e) {
      debugPrint('[CommunityState] loadMyPosts: $e');
    }

    _myPostsLoading = false;
    notifyListeners();
  }

  Future<bool> publishEntry({
    required Entry entry,
    bool isAnonymous = false,
    String? displayName,
    String? category,
  }) async {
    try {
      await SupabaseService.instance.publishEntry(
        entry: entry,
        isAnonymous: isAnonymous,
        displayName: displayName,
        category: category,
      );
      await loadFeed(refresh: true);
      await loadMyPosts();
      return true;
    } catch (e) {
      debugPrint('[CommunityState] publishEntry: $e');
      return false;
    }
  }

  Future<void> toggleClap(String entryId) async {
    final feedIdx = _feed.indexWhere((e) => e.id == entryId);
    final myIdx = _myPosts.indexWhere((e) => e.id == entryId);
    if (feedIdx == -1 && myIdx == -1) return;

    // Use feed entry as source of truth for clap state
    final target = feedIdx != -1 ? _feed[feedIdx] : _myPosts[myIdx];
    final wasClapped = target.hasClapped;

    if (feedIdx != -1) {
      _feed[feedIdx].hasClapped = !wasClapped;
      _feed[feedIdx].clapCount =
          (_feed[feedIdx].clapCount + (wasClapped ? -1 : 1)).clamp(0, 999999);
    }
    if (myIdx != -1) {
      _myPosts[myIdx].hasClapped = !wasClapped;
      _myPosts[myIdx].clapCount =
          (_myPosts[myIdx].clapCount + (wasClapped ? -1 : 1)).clamp(0, 999999);
    }
    notifyListeners();

    try {
      if (wasClapped) {
        await SupabaseService.instance.removeClap(entryId);
      } else {
        await SupabaseService.instance.clapEntry(entryId);
      }
    } catch (e) {
      // Revert on failure
      if (feedIdx != -1) {
        _feed[feedIdx].hasClapped = wasClapped;
        _feed[feedIdx].clapCount =
            (_feed[feedIdx].clapCount + (wasClapped ? 1 : -1)).clamp(0, 999999);
      }
      if (myIdx != -1) {
        _myPosts[myIdx].hasClapped = wasClapped;
        _myPosts[myIdx].clapCount =
            (_myPosts[myIdx].clapCount + (wasClapped ? 1 : -1)).clamp(0, 999999);
      }
      notifyListeners();
    }
  }

  Future<List<CommunityComment>> getComments(String entryId) async {
    return SupabaseService.instance.getCommunityComments(entryId);
  }

  Future<bool> addComment({
    required String entryId,
    required String body,
    bool isAnonymous = false,
    String? displayName,
  }) async {
    final ok = await SupabaseService.instance.addCommunityComment(
      entryId: entryId,
      body: body,
      isAnonymous: isAnonymous,
      displayName: displayName,
    );
    if (ok) {
      final idx = _feed.indexWhere((e) => e.id == entryId);
      if (idx != -1) {
        _feed[idx].commentCount++;
        notifyListeners();
      }
    }
    return ok;
  }

  Future<void> deletePost(String entryId) async {
    try {
      await SupabaseService.instance.deletePublishedEntry(entryId);
      _myPosts.removeWhere((e) => e.id == entryId);
      _feed.removeWhere((e) => e.id == entryId);
      notifyListeners();
    } catch (e) {
      debugPrint('[CommunityState] deletePost: $e');
    }
  }

  void refresh() => loadFeed(refresh: true);
}
