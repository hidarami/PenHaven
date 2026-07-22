import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/story.dart';
import '../models/entry.dart';
import '../models/todo.dart';
import '../models/time_capsule.dart';

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
  static const String _supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String _supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
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
      await _client?.from('stories').update({
        'isDeleted': 1,
      }).eq('id', id).eq('user_id', userId!);
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
      await _client?.from('todos').update({
        'isArchived': 1,
      }).eq('id', id).eq('user_id', userId!);
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
}