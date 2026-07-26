import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/published_entry.dart';
import '../models/community_comment.dart';
import '../models/entry.dart';
import '../services/supabase_service.dart';

class CommunityState extends ChangeNotifier {
  // Auto-load profile from SharedPreferences immediately on creation.
  // This ensures avatar/username are available before any screen calls loadProfile().
  CommunityState() {
    SharedPreferences.getInstance().then((prefs) {
      _profileDisplayName = prefs.getString('communityDisplayName');
      _profileImagePath = prefs.getString('communityProfileImage');
      _profileBannerPath = prefs.getString('communityProfileBanner');
      _profileBio = prefs.getString('communityProfileBio');
      notifyListeners();
    });
  }

  List<PublishedEntry> _feed = [];
  List<PublishedEntry> _myPosts = [];
  bool _feedLoading = false;
  bool _myPostsLoading = false;
  int _totalUniqueViews = 0;
  int get totalUniqueViews => _totalUniqueViews;
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
  String? _profileImageUrl;
  String? _profileBannerPath;
  String? _profileBio;
  String? get profileDisplayName => _profileDisplayName;
  String? get profileImagePath => _profileImagePath;
  String? get profileImageUrl => _profileImageUrl;
  String? get profileBannerPath => _profileBannerPath;
  String? get profileBio => _profileBio;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _profileDisplayName = prefs.getString('communityDisplayName');
    _profileImagePath = prefs.getString('communityProfileImage');
    _profileImageUrl = prefs.getString('communityProfileImageUrl');
    _profileBannerPath = prefs.getString('communityProfileBanner');
    _profileBio = prefs.getString('communityProfileBio');
    notifyListeners();
  }

  Future<void> saveProfile({String? name, String? imagePath, String? bannerPath, String? bio}) async {
    final prefs = await SharedPreferences.getInstance();
    if (name != null) {
      _profileDisplayName = name;
      await prefs.setString('communityDisplayName', name);
    }
    if (imagePath != null) {
      _profileImagePath = imagePath;
      await prefs.setString('communityProfileImage', imagePath);
      notifyListeners();
      // Upload so OTHER users can see this avatar too. This is the piece
      // that was missing before — local paths never left the device.
      final url = await SupabaseService.instance.uploadProfileImage(imagePath);
      if (url != null) {
        _profileImageUrl = url;
        await prefs.setString('communityProfileImageUrl', url);
        // Refresh this user's avatar on every record they've already created
        // so old posts/comments/replies show the new photo too.
        await SupabaseService.instance.backfillProfileImageUrl(url);
      }
    }
    if (bannerPath != null) {
      _profileBannerPath = bannerPath;
      await prefs.setString('communityProfileBanner', bannerPath);
    }
    if (bio != null) {
      _profileBio = bio;
      await prefs.setString('communityProfileBio', bio);
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
    final data = await SupabaseService.instance.getActiveFeatured();
    if (data != null) {
      _featuredEntryId = data['entry_id'] as String?;
      final untilStr = data['featured_until'] as String?;
      _featuredUntil = untilStr != null ? DateTime.parse(untilStr) : null;
    } else {
      _featuredEntryId = null;
      _featuredUntil = null;
    }
    notifyListeners();
  }

  /// Pins [entryId] as the featured reflection for [duration] (default 7 days).
  /// Global — stored server-side so every user sees the same featured entry.
  Future<void> setFeatured(String entryId,
      {Duration duration = const Duration(days: 7)}) async {
    _featuredEntryId = entryId;
    _featuredUntil = DateTime.now().add(duration);
    notifyListeners();
    await SupabaseService.instance.setFeaturedEntry(entryId, duration);
  }

  Future<void> clearFeatured() async {
    _featuredEntryId = null;
    _featuredUntil = null;
    notifyListeners();
  }

  // ── Bookmarks ──────────────────────────────────────────────────────────────
  List<String> _bookmarkedIds = [];
  List<String> get bookmarkedIds => _bookmarkedIds;

  /// Returns feed entries the user has bookmarked locally.
  List<PublishedEntry> get bookmarkedEntries =>
      _feed.where((e) => _bookmarkedIds.contains(e.id)).toList();

  Future<void> loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    _bookmarkedIds = prefs
        .getKeys()
        .where((k) =>
            k.startsWith('bookmark_') && (prefs.getBool(k) ?? false))
        .map((k) => k.replaceFirst('bookmark_', ''))
        .toList();
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
        _totalUniqueViews =
            await SupabaseService.instance.getTotalUniqueViewsByUser(userId);
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
        profileImageUrl: _profileImageUrl,
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

    // Determine current clapped state from whichever cache holds it; if this
    // entry isn't cached anywhere (e.g. opened directly from the homescreen
    // reader, which never loads the feed), fall back to querying Supabase
    // directly so the toggle still actually persists instead of silently
    // no-op'ing (this was the bug: it used to return early here).
    bool wasClapped;
    if (feedIdx != -1) {
      wasClapped = _feed[feedIdx].hasClapped;
    } else if (myIdx != -1) {
      wasClapped = _myPosts[myIdx].hasClapped;
    } else {
      final clapped =
          await SupabaseService.instance.getClappedEntryIds([entryId]);
      wasClapped = clapped.contains(entryId);
    }

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

    _patchReflectionClapCount(entryId, wasClapped);

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
      profileImageUrl: _profileImageUrl,
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

  Future<bool> deleteComment({required String commentId, required String entryId}) async {
    final ok = await SupabaseService.instance.deleteComment(commentId);
    if (ok) {
      final idx = _feed.indexWhere((e) => e.id == entryId);
      if (idx != -1) {
        _feed[idx].commentCount = (_feed[idx].commentCount - 1).clamp(0, 999999);
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

  // ── Write Backs / Reflections ──────────────────────────────────────────────

  List<Map<String, dynamic>> _myWriteBacks = [];
  List<Map<String, dynamic>> _receivedWriteBacks = [];
  bool _writeBacksLoading = false;

  List<Map<String, dynamic>> get myWriteBacks => _myWriteBacks;
  List<Map<String, dynamic>> get receivedWriteBacks => _receivedWriteBacks;
  bool get writeBacksLoading => _writeBacksLoading;

  Future<void> loadMyWriteBacks() async {
    _writeBacksLoading = true;
    notifyListeners();
    _myWriteBacks = await SupabaseService.instance.getMyWriteBacks();
    _writeBacksLoading = false;
    notifyListeners();
  }

  Future<void> loadReceivedWriteBacks() async {
    _writeBacksLoading = true;
    notifyListeners();
    _receivedWriteBacks = await SupabaseService.instance.getReceivedWriteBacks();
    _writeBacksLoading = false;
    notifyListeners();
  }

  Future<bool> submitWriteBack(dynamic reflection) async {
    // reflection is a Reflection model — convert to map
    try {
      final map = reflection.toMap() as Map<String, dynamic>;
      final ok = await SupabaseService.instance.submitWriteBack(map);
      if (ok) {
        // Refresh my write backs list
        _myWriteBacks = await SupabaseService.instance.getMyWriteBacks();
        notifyListeners();
      }
      return ok;
    } catch (e) {
      debugPrint('[CommunityState] submitWriteBack: $e');
      return false;
    }
  }

  /// Submit from a raw map (created via EditorScreen with ReflectionHeaderBlock).
  Future<bool> submitWriteBackMap(Map<String, dynamic> map) async {
    try {
      final ok = await SupabaseService.instance.submitWriteBackMap(map);
      if (ok) {
        loadFeed(refresh: true);
        loadReceivedWriteBacks();
      }
      return ok;
    } catch (e) {
      debugPrint('[CommunityState] submitWriteBackMap: $e');
      return false;
    }
  }

  Future<bool> deleteWriteBack(String id) async {
    final ok = await SupabaseService.instance.deleteWriteBack(id);
    if (ok) {
      _myWriteBacks.removeWhere((r) => r['id'] == id);
      _receivedWriteBacks.removeWhere((r) => r['id'] == id);
      _feed.removeWhere((e) => e.id == id); // also drop from sanctuary feed cache
      notifyListeners();
    }
    return ok;
  }

  Future<bool> publishPrivateWriteBack(String id) async {
    final ok = await SupabaseService.instance.publishWriteBack(id);
    if (ok) {
      final idx = _myWriteBacks.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        _myWriteBacks[idx] = {..._myWriteBacks[idx], 'is_private': false};
        notifyListeners();
      }
      loadFeed(refresh: true);
    }
    return ok;
  }

  Future<void> toggleReflectionClap(String reflectionId, bool wasClapped) async {
    try {
      if (wasClapped) {
        await SupabaseService.instance.removereflectionClap(reflectionId);
      } else {
        await SupabaseService.instance.clapReflection(reflectionId);
      }
      _patchReflectionClapCount(reflectionId, wasClapped);
    } catch (e) {
      debugPrint('[CommunityState] toggleReflectionClap: $e');
    }
  }

  /// Patches the clap count for [reflectionId] across every list that may
  /// hold a copy of it (my write backs, received write backs, feed cache),
  /// so every screen shows the same number without needing a refetch.
  void _patchReflectionClapCount(String reflectionId, bool wasClapped) {
    void patch(List<Map<String, dynamic>> list) {
      final idx = list.indexWhere((r) => r['id'] == reflectionId);
      if (idx != -1) {
        final current = (list[idx]['clap_count'] as int? ?? 0);
        list[idx] = {
          ...list[idx],
          'clap_count': wasClapped ? (current - 1).clamp(0, 999999) : current + 1,
        };
      }
    }
    patch(_myWriteBacks);
    patch(_receivedWriteBacks);
    notifyListeners();
  }
}
