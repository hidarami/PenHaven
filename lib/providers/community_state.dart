import 'package:flutter/foundation.dart';
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
  }) async {
    try {
      await SupabaseService.instance.publishEntry(
        entry: entry,
        isAnonymous: isAnonymous,
        displayName: displayName,
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
    final idx = _feed.indexWhere((e) => e.id == entryId);
    if (idx == -1) return;

    final wasClapped = _feed[idx].hasClapped;
    _feed[idx].hasClapped = !wasClapped;
    _feed[idx].clapCount = (_feed[idx].clapCount + (wasClapped ? -1 : 1)).clamp(0, 999999);
    notifyListeners();

    try {
      if (wasClapped) {
        await SupabaseService.instance.removeClap(entryId);
      } else {
        await SupabaseService.instance.clapEntry(entryId);
      }
    } catch (e) {
      // Revert on failure
      _feed[idx].hasClapped = wasClapped;
      _feed[idx].clapCount = (_feed[idx].clapCount + (wasClapped ? 1 : -1)).clamp(0, 999999);
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