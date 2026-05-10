import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';

class SupabaseService {
  static SupabaseClient get _db => Supabase.instance.client;
  static const _uuid = Uuid();

  static String generateParticipantId() => _uuid.v4();

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static Future<({String sessionId, String code})> createSession({
    required Recipe recipe,
    required String hostName,
    required String hostEmoji,
    required String participantId,
  }) async {
    final code = _generateCode();
    final session = await _db.from('cook_sessions').insert({
      'code': code,
      'recipe_id': recipe.id,
      'recipe_title': recipe.title,
      'recipe_json': recipe.toJson(),
      'host_name': hostName,
    }).select().single();

    final sessionId = session['id'] as String;

    await _db.from('session_participants').insert({
      'session_id': sessionId,
      'participant_id': participantId,
      'name': hostName,
      'emoji': hostEmoji,
      'current_step': 0,
    });

    return (sessionId: sessionId, code: code);
  }

  static Future<({String sessionId, Recipe recipe, String code})?> joinSession({
    required String code,
    required String name,
    required String emoji,
    required String participantId,
  }) async {
    try {
      final sessions = await _db
          .from('cook_sessions')
          .select()
          .eq('code', code.toUpperCase().trim())
          .eq('status', 'active');

      if (sessions.isEmpty) return null;
      final session = sessions[0] as Map<String, dynamic>;
      final sessionId = session['id'] as String;

      await _db.from('session_participants').upsert({
        'session_id': sessionId,
        'participant_id': participantId,
        'name': name,
        'emoji': emoji,
        'current_step': 0,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'session_id,participant_id');

      final recipeMap = session['recipe_json'] as Map<String, dynamic>;
      final recipe = Recipe.fromJson(Map<String, dynamic>.from(recipeMap));
      return (sessionId: sessionId, recipe: recipe, code: code.toUpperCase().trim());
    } catch (_) {
      return null;
    }
  }

  static Future<void> updateStep(String sessionId, String participantId, int step) async {
    await _db.from('session_participants').update({
      'current_step': step,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('session_id', sessionId).eq('participant_id', participantId);
  }

  static Future<void> sendReaction(String sessionId, String participantName, String emoji) async {
    await _db.from('session_reactions').insert({
      'session_id': sessionId,
      'participant_name': participantName,
      'emoji': emoji,
    });
  }

  static Stream<List<Map<String, dynamic>>> streamParticipants(String sessionId) {
    return _db
        .from('session_participants')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId);
  }

  static Stream<List<Map<String, dynamic>>> streamReactions(String sessionId) {
    return _db
        .from('session_reactions')
        .stream(primaryKey: ['id'])
        .eq('session_id', sessionId);
  }

  static Future<void> endSession(String sessionId) async {
    await _db.from('cook_sessions').update({'status': 'finished'}).eq('id', sessionId);
  }

  static Future<void> leaveSession(String sessionId, String participantId) async {
    await _db.from('session_participants').delete().eq('session_id', sessionId).eq('participant_id', participantId);
  }
}
