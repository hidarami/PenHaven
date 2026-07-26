import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/story.dart';
import '../models/entry.dart';
import '../models/todo.dart';
import '../models/time_capsule.dart';
import '../models/published_entry.dart';
import '../models/community_comment.dart';

// OAuth provider helper methods
// ─────────────────────────────────────────────────────────────────────────────
// SUPABASE SERVICE
// Handles auth + cloud sync. All operations fail silently so local SQLite
// always wins — internet is optional, never a blocker.
//
// Setup:
//   1. Go to supabase.com → New project
//   2. Copy Project URL + anon key into .env file (see .env.example)
//   3. Run the SQL in Supabase SQL editor (see SCHEMA section at bottom)
//   4. Enable email auth in Supabase Dashboard → Auth → Providers
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // ── Load credentials from .env file ─────────────────────────────────────────
  static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get _supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        debug: kDebugMode,
      );
    } catch (e) {
      // Supabase unavailable — app works fully offline
      debugPrint('[Supabase] init failed: $e');
    }
  }

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────────────

  bool get isAuthenticated {
    try {
      return _client?.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  String? get userId => _client?.auth.currentUser?.id;
  String? get userEmail => _client?.auth.currentUser?.email;

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      await _client?.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return null; // null = success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    try {
      await _client?.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> signOut() async {
    try {
      await _client?.auth.signOut();
    } catch (_) {}
  }

  // ── OAuth / Social Login ────────────────────────────────────────────────────

  /// Sign in with Google
  Future<String?> signInWithGoogle() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with Apple
  Future<String?> signInWithApple() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with Facebook
  Future<String?> signInWithFacebook() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.facebook,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with GitHub
  Future<String?> signInWithGitHub() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.github,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with Discord
  Future<String?> signInWithDiscord() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.discord,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with Twitter/X
  Future<String?> signInWithTwitter() async {
    try {
      await _client?.auth.signInWithOAuth(
        OAuthProvider.twitter,
        redirectTo: 'penhaven://auth/callback',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Stream<AuthState>? get authStream => _client?.auth.onAuthStateChange;

  // ── Stories ───────────────────────────────────────────────────────────────

  Future<void> upsertStory(Story story) async {
    if (!isAuthenticated) return;
    try {
      await _client?.from('stories').upsert({
        ...story.toMap(),
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('[Supabase] upsertStory: $e');
    }
  }

  Future<void> deleteStory(String id) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('stories')
          .update({
            'isDeleted': 1,
          })
          .eq('id', id)
          .eq('user_id', userId!);
    } catch (e) {
      debugPrint('[Supabase] deleteStory: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchStories() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          ?.from('stories')
          .select()
          .eq('user_id', userId!)
          .eq('isDeleted', 0)
          .order('updatedAt', ascending: false);
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('[Supabase] fetchStories: $e');
      return [];
    }
  }

  // ── Entries ───────────────────────────────────────────────────────────────

  Future<void> upsertEntry(Entry entry) async {
    if (!isAuthenticated) return;
    try {
      final map = entry.toMap();
      // DB column is blocks_json
      if (entry.blocksJson != null) map['blocks_json'] = entry.blocksJson;
      map.remove('blocksJson');
      await _client?.from('entries').upsert({
        ...map,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('[Supabase] upsertEntry: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchEntries(String storyId) async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          ?.from('entries')
          .select()
          .eq('user_id', userId!)
          .eq('storyId', storyId)
          .eq('isDeleted', 0)
          .order('createdAt', ascending: false);
      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      debugPrint('[Supabase] fetchEntries: $e');
      return [];
    }
  }

  // ── Todos ─────────────────────────────────────────────────────────────────

  Future<void> upsertTodo(Todo todo) async {
    if (!isAuthenticated) return;
    try {
      await _client?.from('todos').upsert({
        ...todo.toMap(),
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('[Supabase] upsertTodo: $e');
    }
  }

  Future<void> archiveTodo(String id) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('todos')
          .update({
            'isArchived': 1,
          })
          .eq('id', id)
          .eq('user_id', userId!);
    } catch (e) {
      debugPrint('[Supabase] archiveTodo: $e');
    }
  }

  // ── Time Capsules ─────────────────────────────────────────────────────────

  Future<void> upsertCapsule(TimeCapsule capsule) async {
    if (!isAuthenticated) return;
    try {
      await _client?.from('time_capsules').upsert({
        ...capsule.toMap(),
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('[Supabase] upsertCapsule: $e');
    }
  }
  // ─────────────────────────────────────────────────────────────────────────
  // COMMUNITY
  // ─────────────────────────────────────────────────────────────────────────

  bool get isSupabaseConfigured =>
      _supabaseUrl != 'YOUR_SUPABASE_URL' &&
      _supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  Future<void> publishEntry({
    required Entry entry,
    bool isAnonymous = false,
    String? displayName,
    String? category,
    String? profileImageUrl,
  }) async {
    if (!isAuthenticated) throw Exception('Not authenticated');
    final map = {
      'id': entry.id,
      'user_id': userId,
      'title': entry.title,
      'content': entry.content,
      'blocks_json': entry.blocksJson,
      'is_anonymous': isAnonymous,
      'display_name': isAnonymous ? null : displayName,
      'header_image': entry.headerImage,
      'category': category,
      'profile_image_url': isAnonymous ? null : profileImageUrl,
    };
    await _client?.from('published_entries').upsert(map);
  }

  Future<List<PublishedEntry>> getPublishedEntries({
    int page = 0,
    int limit = 20,
  }) async {
    try {
      final from = page * limit;
      final to = from + limit - 1;
      final response = await _client
          ?.from('published_entries')
          .select()
          .eq('is_hidden', false)
          .order('created_at', ascending: false)
          .range(from, to);
      if (response == null) return [];
      return (response as List)
          .map((e) => PublishedEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Supabase] getPublishedEntries: $e');
      return [];
    }
  }

  Future<List<PublishedEntry>> getMyPublishedEntries() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          ?.from('published_entries')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);
      if (response == null) return [];
      return (response as List)
          .map((e) => PublishedEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Supabase] getMyPublishedEntries: $e');
      return [];
    }
  }

  Future<void> clapEntry(String entryId) async {
    if (!isAuthenticated) return;
    try {
      // Idempotent: if the row already exists (e.g. a fast double-tap),
      // skip the counter bump instead of throwing and silently dropping it.
      final result = await _client?.from('community_claps').upsert(
        {'entry_id': entryId, 'user_id': userId},
        onConflict: 'entry_id,user_id',
        ignoreDuplicates: true,
      ).select();
      final inserted = result != null && (result as List).isNotEmpty;
      if (inserted) {
        await _client
            ?.rpc('increment_clap_count', params: {'p_entry_id': entryId});
      }
    } catch (e) {
      debugPrint('[Supabase] clapEntry: $e');
    }
  }

  Future<void> removeClap(String entryId) async {
    if (!isAuthenticated) return;
    try {
      final deleted = await _client
          ?.from('community_claps')
          .delete()
          .eq('entry_id', entryId)
          .eq('user_id', userId!)
          .select();
      final removed = deleted != null && (deleted as List).isNotEmpty;
      if (removed) {
        await _client
            ?.rpc('decrement_clap_count', params: {'p_entry_id': entryId});
      }
    } catch (e) {
      debugPrint('[Supabase] removeClap: $e');
    }
  }

  Future<Set<String>> getClappedEntryIds(List<String> entryIds) async {
    if (!isAuthenticated || entryIds.isEmpty) return {};
    try {
      final response = await _client
          ?.from('community_claps')
          .select('entry_id')
          .eq('user_id', userId!)
          .inFilter('entry_id', entryIds);
      if (response == null) return {};
      return Set<String>.from(
        (response as List).map((r) => r['entry_id'] as String),
      );
    } catch (e) {
      return {};
    }
  }

  /// Same as [getClappedEntryIds] but for reflections (write_backs), which
  /// use a separate reflection_claps table.
  Future<Set<String>> getClappedReflectionIds(List<String> ids) async {
    if (!isAuthenticated || ids.isEmpty) return {};
    try {
      final response = await _client
          ?.from('reflection_claps')
          .select('reflection_id')
          .eq('user_id', userId!)
          .inFilter('reflection_id', ids);
      if (response == null) return {};
      return Set<String>.from(
        (response as List).map((r) => r['reflection_id'] as String),
      );
    } catch (e) {
      return {};
    }
  }

  Future<List<CommunityComment>> getCommunityComments(String entryId) async {
    try {
      final response = await _client
          ?.from('community_comments')
          .select()
          .eq('entry_id', entryId)
          .order('created_at', ascending: true);
      if (response == null) return [];
      return (response as List)
          .map((e) => CommunityComment.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Supabase] getCommunityComments: $e');
      return [];
    }
  }

  Future<bool> addCommunityComment({
    required String entryId,
    required String body,
    bool isAnonymous = false,
    String? displayName,
    String? profileImageUrl,
  }) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('community_comments').insert({
        'entry_id': entryId,
        'user_id': userId,
        'body': body,
        'is_anonymous': isAnonymous,
        'display_name': isAnonymous ? null : displayName,
        'profile_image_url': isAnonymous ? null : profileImageUrl,
      });
      await _client
          ?.rpc('increment_comment_count', params: {'p_entry_id': entryId});
      return true;
    } catch (e) {
      debugPrint('[Supabase] addCommunityComment: $e');
      return false;
    }
  }

  /// Fetches a single published entry by its local entry ID.
  /// Returns null if the entry has not been published or on error.
  Future<PublishedEntry?> getPublishedEntry(String entryId) async {
    try {
      final response = await _client
          ?.from('published_entries')
          .select()
          .eq('id', entryId)
          .maybeSingle();
      if (response == null) return null;
      final pub = PublishedEntry.fromMap(response);
      // Tag if owned by current user
      pub.isOwner = pub.userId == userId;
      final clapped = await getClappedEntryIds([entryId]);
      pub.hasClapped = clapped.contains(entryId);
      return pub;
    } catch (e) {
      debugPrint('[Supabase] getPublishedEntry: $e');
      return null;
    }
  }

  Future<bool> deleteComment(String commentId) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('community_comments').delete().eq('id', commentId);
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteComment: $e');
      return false;
    }
  }

  // ── Featured Entry (global, server-side) ──────────────────────────────────

  Future<Map<String, dynamic>?> getActiveFeatured() async {
    try {
      final response = await _client
          ?.from('featured_entries')
          .select()
          .gt('featured_until', DateTime.now().toIso8601String())
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[Supabase] getActiveFeatured: $e');
      return null;
    }
  }

  Future<void> setFeaturedEntry(String entryId, Duration duration) async {
    if (!isAuthenticated) return;
    try {
      final until = DateTime.now().add(duration);
      await _client?.from('featured_entries').insert({
        'entry_id': entryId,
        'featured_until': until.toIso8601String(),
      });
    } catch (e) {
      debugPrint('[Supabase] setFeaturedEntry: $e');
    }
  }

  /// Uploads the user's profile photo to Supabase Storage and returns its
  /// public URL. This is what makes avatars visible to OTHER users —
  /// local file paths only work on the owner's own device.
  Future<String?> uploadProfileImage(String localPath) async {
    if (!isAuthenticated) return null;
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final storagePath = 'avatars/$userId.png';
      await _client?.storage.from('profile-images').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/png', upsert: true),
          );
      // Cache-bust so the new photo shows immediately everywhere
      final base =
          _client?.storage.from('profile-images').getPublicUrl(storagePath);
      return base == null
          ? null
          : '$base?t=${DateTime.now().millisecondsSinceEpoch}';
    } catch (e) {
      debugPrint('[Supabase] uploadProfileImage: $e');
      return null;
    }
  }

  /// Updates this user's avatar URL on every past row they own, so changing
  /// your profile photo updates it everywhere retroactively (not just new posts).
  Future<void> backfillProfileImageUrl(String url) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('published_entries')
          .update({'profile_image_url': url})
          .eq('user_id', userId!)
          .eq('is_anonymous', false);
      await _client
          ?.from('write_backs')
          .update({'profile_image_url': url})
          .eq('user_id', userId!)
          .eq('is_anonymous', false);
      await _client
          ?.from('community_comments')
          .update({'profile_image_url': url})
          .eq('user_id', userId!)
          .eq('is_anonymous', false);
      await _client
          ?.from('reflection_replies')
          .update({'profile_image_url': url})
          .eq('user_id', userId!)
          .eq('is_anonymous', false);
    } catch (e) {
      debugPrint('[Supabase] backfillProfileImageUrl: $e');
    }
  }

  /// Uploads a share card PNG to Supabase Storage and returns its public URL.
  /// Requires a public 'share-cards' bucket in your Supabase project.
  Future<String?> uploadShareCard(String localPath, String entryId) async {
    try {
      final file = File(localPath);
      final bytes = await file.readAsBytes();
      final storagePath =
          'cards/${entryId}_${DateTime.now().millisecondsSinceEpoch}.png';
      await _client?.storage.from('share-cards').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/png', upsert: true),
          );
      return _client?.storage.from('share-cards').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('[Supabase] uploadShareCard: $e');
      return null;
    }
  }

  Future<void> deletePublishedEntry(String entryId) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('published_entries')
          .delete()
          .eq('id', entryId)
          .eq('user_id', userId!);
    } catch (e) {
      debugPrint('[Supabase] deletePublishedEntry: $e');
    }
  }

  /// Hides (or restores) every published entry and write back belonging to
  /// this user, without deleting anything. Used by the Sanctuary on/off
  /// toggle in Settings — turning it back on undoes this completely.
  Future<void> setSanctuaryVisibility(bool visible) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('published_entries')
          .update({'is_hidden': !visible}).eq('user_id', userId!);
      await _client
          ?.from('write_backs')
          .update({'is_hidden': !visible}).eq('user_id', userId!);
    } catch (e) {
      debugPrint('[Supabase] setSanctuaryVisibility: $e');
    }
  }

  /// Records a unique view for [entryId] by the current user.
  /// Requires in Supabase SQL editor:
  /// CREATE TABLE community_views (
  ///   entry_id TEXT NOT NULL, user_id TEXT NOT NULL,
  ///   viewed_at TIMESTAMPTZ DEFAULT NOW(),
  ///   PRIMARY KEY (entry_id, user_id)
  /// );
  Future<void> recordView(String entryId) async {
    if (!isAuthenticated) return;
    try {
      await _client?.from('community_views').upsert(
        {'entry_id': entryId, 'user_id': userId},
        onConflict: 'entry_id,user_id',
      );
    } catch (_) {}
  }

  /// Total unique (entry, viewer) pairs across all entries by [publisherUserId].
  /// One user viewing two of your entries = 2 reads. Same user viewing one entry
  /// five times = 1 read.
  Future<int> getTotalUniqueViewsByUser(String publisherUserId) async {
    try {
      final entries = await _client
          ?.from('published_entries')
          .select('id')
          .eq('user_id', publisherUserId);
      if (entries == null || (entries as List).isEmpty) return 0;
      final entryIds = (entries as List).map((e) => e['id'] as String).toList();
      final views = await _client
          ?.from('community_views')
          .select('entry_id, user_id')
          .inFilter('entry_id', entryIds);
      if (views == null) return 0;
      // Count unique (entry_id, user_id) pairs — already unique by primary key
      return (views as List).length;
    } catch (_) {
      return 0;
    }
  }

  /// Fetches public (non-anonymous) published entries by a specific user.
  Future<List<PublishedEntry>> getPublicEntriesByUser(String targetUserId,
      {int limit = 12}) async {
    try {
      final response = await _client
          ?.from('published_entries')
          .select()
          .eq('user_id', targetUserId)
          .eq('is_anonymous', false)
          .order('created_at', ascending: false)
          .limit(limit);
      if (response == null) return [];
      return (response as List)
          .map((e) => PublishedEntry.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WRITE BACKS / REFLECTIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Submit a write back (private or public reflection).
  Future<bool> submitWriteBack(Map<String, dynamic> map) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('write_backs').upsert(map);
      // If public, also upsert into the main sanctuary feed
      if (!(map['is_private'] as bool? ?? true)) {
        await _client?.from('published_entries').upsert({
          'id': map['id'],
          'user_id': userId,
          'title': map['title'] ?? '',
          'content': map['content'] ?? '',
          'blocks_json': map['blocks_json'],
          'is_anonymous': map['is_anonymous'] ?? false,
          'display_name': map['display_name'],
          'header_image': map['header_image'],
          'category': map['category'],
          'clap_count': 0,
          'comment_count': 0,
        });
      }
      return true;
    } catch (e) {
      debugPrint('[Supabase] submitWriteBack: $e');
      return false;
    }
  }

  /// Submit write back from a raw map (used when creating from an Entry).
  Future<bool> submitWriteBackMap(Map<String, dynamic> map) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('write_backs').upsert(map);
      // If public, also upsert into the main sanctuary feed
      if (!(map['is_private'] as bool? ?? true)) {
        await _client?.from('published_entries').upsert({
          'id': map['id'],
          'user_id': userId,
          'title': map['title'] ?? '',
          'content': map['content'] ?? '',
          'blocks_json': map['blocks_json'],
          'is_anonymous': map['is_anonymous'] ?? false,
          'display_name': map['display_name'],
          'header_image': map['header_image'],
          'category': map['category'],
          'clap_count': 0,
          'comment_count': 0,
        });
      }
      return true;
    } catch (e) {
      debugPrint('[Supabase] submitWriteBackMap: $e');
      return false;
    }
  }

  Future<bool> updateWriteBack(String id, Map<String, dynamic> updates) async {
    if (!isAuthenticated) return false;
    try {
      await _client
          ?.from('write_backs')
          .update(updates)
          .eq('id', id)
          .eq('user_id', userId!);
      return true;
    } catch (e) {
      debugPrint('[Supabase] updateWriteBack: $e');
      return false;
    }
  }

  Future<bool> deleteWriteBack(String id) async {
    if (!isAuthenticated) return false;
    try {
      await _client
          ?.from('write_backs')
          .delete()
          .eq('id', id)
          .eq('user_id', userId!);
      return true;
    } catch (e) {
      debugPrint('[Supabase] deleteWriteBack: $e');
      return false;
    }
  }

  Future<bool> publishWriteBack(String id) async {
    if (!isAuthenticated) return false;
    try {
      await _client
          ?.from('write_backs')
          .update({'is_private': false})
          .eq('id', id)
          .eq('user_id', userId!);
      return true;
    } catch (e) {
      debugPrint('[Supabase] publishWriteBack: $e');
      return false;
    }
  }

  /// Fetch public reflections for an origin entry.
  Future<List<Map<String, dynamic>>> getReflectionsForEntry(
      String originEntryId) async {
    try {
      final response = await _client
          ?.from('write_backs')
          .select()
          .eq('origin_entry_id', originEntryId)
          .eq('is_private', false)
          .eq('is_hidden', false)
          .order('created_at', ascending: false);
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[Supabase] getReflectionsForEntry: $e');
      return [];
    }
  }

  /// Fetch all write backs (private + public) for the current user.
  Future<List<Map<String, dynamic>>> getMyWriteBacks() async {
    if (!isAuthenticated) return [];
    try {
      final response = await _client
          ?.from('write_backs')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);
      if (response == null) return [];
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('[Supabase] getMyWriteBacks: $e');
      return [];
    }
  }

  /// Fetch write backs received — either (a) written on an entry I published,
  /// or (b) written on (inspired by) one of my OWN reflections. Both count
  /// as "received" so the Library Reflections tab surfaces everything sent
  /// to or about the user, whether public or private (RLS governs actual
  /// visibility of private rows).
  Future<List<Map<String, dynamic>>> getReceivedWriteBacks() async {
    if (!isAuthenticated) return [];
    try {
      final myEntries = await _client
          ?.from('published_entries')
          .select('id')
          .eq('user_id', userId!);
      final entryIds = myEntries == null
          ? <String>[]
          : (myEntries as List).map((e) => e['id'] as String).toList();

      final myWriteBacks = await _client
          ?.from('write_backs')
          .select('id')
          .eq('user_id', userId!);
      final myWriteBackIds = myWriteBacks == null
          ? <String>[]
          : (myWriteBacks as List).map((r) => r['id'] as String).toList();

      final results = <Map<String, dynamic>>[];
      final seenIds = <String>{};

      if (entryIds.isNotEmpty) {
        final resp = await _client
            ?.from('write_backs')
            .select()
            .inFilter('origin_entry_id', entryIds)
            .order('created_at', ascending: false);
        if (resp != null) {
          for (final r in (resp as List)) {
            final map = Map<String, dynamic>.from(r as Map);
            if (seenIds.add(map['id'] as String)) {
              map['_received_reason'] = 'entry';
              results.add(map);
            }
          }
        }
      }

      if (myWriteBackIds.isNotEmpty) {
        final resp = await _client
            ?.from('write_backs')
            .select()
            .inFilter('inspiration_id', myWriteBackIds)
            .order('created_at', ascending: false);
        if (resp != null) {
          for (final r in (resp as List)) {
            final map = Map<String, dynamic>.from(r as Map);
            if (seenIds.add(map['id'] as String)) {
              map['_received_reason'] = 'reflection';
              results.add(map);
            }
          }
        }
      }

      results.sort((a, b) {
        final da =
            DateTime.tryParse(a['created_at'] as String? ?? '') ?? DateTime(0);
        final db =
            DateTime.tryParse(b['created_at'] as String? ?? '') ?? DateTime(0);
        return db.compareTo(da);
      });

      return results;
    } catch (e) {
      debugPrint('[Supabase] getReceivedWriteBacks: $e');
      return [];
    }
  }

  /// Clap a reflection.
  Future<void> clapReflection(String reflectionId) async {
    if (!isAuthenticated) return;
    try {
      final result = await _client?.from('reflection_claps').upsert(
        {'reflection_id': reflectionId, 'user_id': userId},
        onConflict: 'reflection_id,user_id',
        ignoreDuplicates: true,
      ).select();
      final inserted = result != null && (result as List).isNotEmpty;
      if (inserted) {
        await _client
            ?.rpc('increment_reflection_clap', params: {'p_id': reflectionId});
      }
    } catch (e) {
      debugPrint('[Supabase] clapReflection: $e');
    }
  }

  /// Remove clap from a reflection.
  Future<void> removereflectionClap(String reflectionId) async {
    if (!isAuthenticated) return;
    try {
      final deleted = await _client
          ?.from('reflection_claps')
          .delete()
          .eq('reflection_id', reflectionId)
          .eq('user_id', userId!)
          .select();
      final removed = deleted != null && (deleted as List).isNotEmpty;
      if (removed) {
        await _client
            ?.rpc('decrement_reflection_clap', params: {'p_id': reflectionId});
      }
    } catch (e) {
      debugPrint('[Supabase] removereflectionClap: $e');
    }
  }

  /// Get replies for a reflection.
  Future<List<CommunityComment>> getReflectionReplies(
      String reflectionId) async {
    try {
      final response = await _client
          ?.from('reflection_replies')
          .select()
          .eq('reflection_id', reflectionId)
          .order('created_at', ascending: true);
      if (response == null) return [];
      return (response as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        // Adapt to CommunityComment shape
        m['entry_id'] = m['reflection_id'] ?? '';
        m['body'] = m['body'] ?? '';
        return CommunityComment.fromMap(m);
      }).toList();
    } catch (e) {
      debugPrint('[Supabase] getReflectionReplies: $e');
      return [];
    }
  }

  /// Add a reply to a reflection.
  /// Returns the write_back row for [id] if this published entry is a reflection,
  /// null if it is a regular published entry.
  Future<Map<String, dynamic>?> getWriteBackById(String id) async {
    try {
      final response = await _client
          ?.from('write_backs')
          .select()
          .eq('id', id)
          .maybeSingle();
      return response;
    } catch (e) {
      debugPrint('[Supabase] getWriteBackById: $e');
      return null;
    }
  }

  Future<bool> addReflectionReply({
    required String reflectionId,
    required String body,
    bool isAnonymous = false,
    String? displayName,
    String? profileImageUrl,
  }) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('reflection_replies').insert({
        'reflection_id': reflectionId,
        'user_id': userId,
        'body': body,
        'is_anonymous': isAnonymous,
        'display_name': isAnonymous ? null : displayName,
        'profile_image_url': isAnonymous ? null : profileImageUrl,
      });
    } catch (e) {
      debugPrint('[Supabase] addReflectionReply insert: $e');
      return false;
    }
    // Bump reply_count separately — if this RPC name/param doesn't match
    // your DB function signature, the reply is still saved either way.
    try {
      await _client
          ?.rpc('increment_reply_count', params: {'p_id': reflectionId});
    } catch (e) {
      debugPrint('[Supabase] increment_reply_count: $e');
    }
    return true;
  }
}
