import 'package:flutter/foundation.dart';
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
//   2. Copy Project URL + anon key into the constants below
//   3. Run the SQL in Supabase SQL editor (see SCHEMA section at bottom)
//   4. Enable email auth in Supabase Dashboard → Auth → Providers
// ─────────────────────────────────────────────────────────────────────────────

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  // ── Replace these with your project credentials ───────────────────────────
  static const String _supabaseUrl = 'https://vjmzileqdrhxiklxqftv.supabase.co';
  static const String _supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZqbXppbGVxZHJoeGlrbHhxZnR2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3MjM2NTMsImV4cCI6MjEwMDI5OTY1M30.4DLkLbMfJ67JeJGwjoJ9lXlIGMWAE_N0hEQD4Lm1HQo';
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
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
        redirectTo: 'flow://auth/callback',
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
        redirectTo: 'flow://auth/callback',
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
        redirectTo: 'flow://auth/callback',
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
        redirectTo: 'flow://auth/callback',
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
        redirectTo: 'flow://auth/callback',
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
        redirectTo: 'flow://auth/callback',
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
      await _client?.from('community_claps').insert({
        'entry_id': entryId,
        'user_id': userId,
      });
      await _client
          ?.rpc('increment_clap_count', params: {'p_entry_id': entryId});
    } catch (e) {
      debugPrint('[Supabase] clapEntry: $e');
    }
  }

  Future<void> removeClap(String entryId) async {
    if (!isAuthenticated) return;
    try {
      await _client
          ?.from('community_claps')
          .delete()
          .eq('entry_id', entryId)
          .eq('user_id', userId!);
      await _client
          ?.rpc('decrement_clap_count', params: {'p_entry_id': entryId});
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
  }) async {
    if (!isAuthenticated) return false;
    try {
      await _client?.from('community_comments').insert({
        'entry_id': entryId,
        'user_id': userId,
        'body': body,
        'is_anonymous': isAnonymous,
        'display_name': isAnonymous ? null : displayName,
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
      final pub = PublishedEntry.fromMap(response as Map<String, dynamic>);
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
}
