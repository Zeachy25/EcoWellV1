import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/json_cache.dart';
import '../domain/ai_message.dart';

class AiRepository {
  AiRepository(this._client, this._cache);

  final SupabaseClient _client;
  final JsonCache _cache;

  String get _uid => _client.auth.currentUser?.id ?? '';

  String get _cacheKey => CacheKeys.aiChat(_uid);

  /// Messages saved on this phone, available immediately and offline.
  Future<List<AiMessage>> loadCachedHistory() async {
    if (_uid.isEmpty) return const [];
    final raw = await _cache.read(_cacheKey);
    if (raw is! List) return const [];
    return [
      for (final row in raw)
        if (row is Map) AiMessage.fromJson(Map<String, dynamic>.from(row)),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Loads the server history and keeps offline-only messages in place.
  Future<List<AiMessage>> fetchHistory() async {
    final cached = await loadCachedHistory();
    if (_uid.isEmpty) return cached;
    try {
      final rows =
          await _client
                  .from('chat_messages')
                  .select('id, role, content, action, created_at')
                  .eq('user_id', _uid)
                  .order('created_at', ascending: true)
                  .limit(100)
                  .timeout(const Duration(seconds: 8))
              as List<dynamic>;

      final server = [
        for (final row in rows)
          AiMessage.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
      final serverIds = {for (final message in server) message.id};
      final localOnly = cached.where(
        (message) => message.isLocal && !serverIds.contains(message.id),
      );
      final merged = [...server, ...localOnly]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      await cacheMessages(merged);
      return merged;
    } catch (e) {
      debugPrint('AI history fetch failed, using saved copy: $e');
      return cached;
    }
  }

  Future<void> cacheMessages(List<AiMessage> messages) async {
    if (_uid.isEmpty) return;
    await _cache.write(_cacheKey, [for (final m in messages) m.toJson()]);
  }

  Future<AiReply> sendMessage(
    String text, {
    List<String> nearby = const [],
  }) async {
    try {
      final response = await _client.functions
          .invoke('ai', body: {'message': text, 'nearby': nearby})
          .timeout(const Duration(seconds: 35));

      final data = response.data;
      if (data is Map) {
        final reply = (data['reply'] as String?)?.trim();
        if (reply != null && reply.isNotEmpty) {
          final rawMessages = data['messages'];
          final messages = rawMessages is List
              ? [
                  for (final row in rawMessages)
                    if (row is Map)
                      AiMessage.fromJson(Map<String, dynamic>.from(row)),
                ]
              : const <AiMessage>[];
          return AiReply(
            reply: reply,
            crisis: data['crisis'] == true,
            action: AiMessage.actionFromJson(data['action']),
            messages: messages,
          );
        }
      }
      throw const AiException(
        'ai_unavailable',
        'The AI assistant is unavailable right now.',
      );
    } on FunctionException catch (e) {
      final code = _codeFrom(e);
      throw AiException(code, _messageFor(code, e));
    } on TimeoutException {
      throw const AiException(
        'timeout',
        'The AI assistant took too long to respond.',
      );
    } on AiException {
      rethrow;
    } catch (e) {
      debugPrint('AI request failed: $e');
      throw const AiException(
        'offline',
        'You appear to be offline. Showing a local suggestion instead.',
      );
    }
  }

  String _codeFrom(FunctionException error) {
    final details = error.details;
    if (details is Map && details['code'] is String) {
      return details['code'] as String;
    }
    if (details is String) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is Map && decoded['code'] is String) {
          return decoded['code'] as String;
        }
      } catch (_) {
        // The function returned plain text rather than JSON.
      }
    }
    if (error.status == 401) return 'unauthorized';
    if (error.status == 429) return 'rate_limited';
    if (error.status == 0) return 'offline';
    return 'ai_unavailable';
  }

  String _messageFor(String code, FunctionException error) {
    final details = error.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    switch (code) {
      case 'unauthorized':
        return 'Your session has expired. Please sign in again.';
      case 'rate_limited':
        return 'You have reached today’s AI limit. Please try again tomorrow.';
      case 'message_too_long':
        return 'Please keep messages under 2,000 characters.';
      case 'offline':
        return 'You appear to be offline. Showing a local suggestion instead.';
      case 'timeout':
        return 'The AI assistant took too long to respond.';
      default:
        return 'The AI assistant is unavailable right now.';
    }
  }
}

final aiRepositoryProvider = Provider<AiRepository>(
  (ref) => AiRepository(Supabase.instance.client, ref.watch(jsonCacheProvider)),
);
