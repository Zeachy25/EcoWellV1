import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/ai_message.dart';
import '../domain/ai_safety.dart';
import 'ai_repository.dart';

class AiChatState {
  const AiChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
    this.crisis = false,
  });

  final List<AiMessage> messages;
  final bool loading;
  final bool sending;
  final String? error;
  final bool crisis;

  AiChatState copyWith({
    List<AiMessage>? messages,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
    bool? crisis,
  }) {
    return AiChatState(
      messages: messages ?? this.messages,
      loading: loading ?? this.loading,
      sending: sending ?? this.sending,
      error: clearError ? null : (error ?? this.error),
      crisis: crisis ?? this.crisis,
    );
  }
}

final aiChatControllerProvider =
    NotifierProvider.autoDispose<AiChatController, AiChatState>(
      AiChatController.new,
    );

class AiChatController extends Notifier<AiChatState> {
  bool _disposed = false;
  bool _hasLocalChanges = false;

  AiRepository get _repo => ref.read(aiRepositoryProvider);

  @override
  AiChatState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    Future.microtask(_loadHistory);
    return const AiChatState();
  }

  Future<void> _loadHistory() async {
    final cached = await _repo.loadCachedHistory();
    if (_disposed) return;
    if (_hasLocalChanges) {
      state = state.copyWith(loading: false);
      return;
    }
    if (cached.isNotEmpty) {
      state = state.copyWith(messages: cached, loading: false);
    }

    final history = await _repo.fetchHistory();
    if (_disposed || _hasLocalChanges) return;
    state = state.copyWith(messages: history, loading: false, clearError: true);
  }

  /// Returns true when a reply (real or local fallback) was added.
  /// Returns false when the message should stay in the input for a retry.
  Future<bool> send(String raw, {Future<List<String>>? nearbyFuture}) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return false;

    _hasLocalChanges = true;
    final stamp = DateTime.now();
    final userMessage = AiMessage.local(
      role: AiRole.user,
      content: text,
      createdAt: stamp,
    );

    if (AiSafety.isCrisis(text)) {
      final reply = AiMessage.local(
        role: AiRole.assistant,
        content: AiSafety.crisisReply,
        createdAt: stamp.add(const Duration(milliseconds: 1)),
      );
      state = state.copyWith(
        messages: [...state.messages, userMessage, reply],
        sending: false,
        crisis: true,
        clearError: true,
      );
      await _repo.cacheMessages(state.messages);
      return true;
    }

    state = state.copyWith(
      messages: [...state.messages, userMessage],
      sending: true,
      crisis: false,
      clearError: true,
    );

    try {
      var nearby = const <String>[];
      if (nearbyFuture != null) {
        try {
          nearby = await nearbyFuture;
        } catch (_) {
          // Nearby context is optional; a failure should not block the chat.
        }
      }
      if (_disposed) return false;

      final reply = await _repo.sendMessage(text, nearby: nearby);
      if (_disposed) return false;

      final withoutOptimistic = state.messages
          .where((message) => message.id != userMessage.id)
          .toList();
      if (reply.messages.isNotEmpty) {
        state = state.copyWith(
          messages: [...withoutOptimistic, ...reply.messages],
          sending: false,
          crisis: reply.crisis,
          clearError: true,
        );
      } else {
        final stamp = DateTime.now();
        final assistant = AiMessage(
          id: 'server:${stamp.microsecondsSinceEpoch}',
          role: AiRole.assistant,
          content: reply.reply,
          createdAt: stamp,
          action: reply.action,
        );
        state = state.copyWith(
          messages: [...state.messages, assistant],
          sending: false,
          crisis: reply.crisis,
          clearError: true,
        );
      }
      await _repo.cacheMessages(state.messages);
      return true;
    } on AiException catch (e) {
      if (_disposed) return false;
      if (e.canUseFallback) {
        final fallback = AiMessage.local(
          role: AiRole.assistant,
          content: AiSafety.fallbackReply(text),
          createdAt: DateTime.now(),
          isLocalFallback: true,
          action: AiSafety.fallbackAction(text),
        );
        state = state.copyWith(
          messages: [...state.messages, fallback],
          sending: false,
          clearError: true,
        );
        await _repo.cacheMessages(state.messages);
        return true;
      }

      // Keep the original text in the composer so the user can try again.
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != userMessage.id)
            .toList(),
        sending: false,
        error: e.message,
      );
      return false;
    } catch (e) {
      if (_disposed) return false;
      state = state.copyWith(
        messages: state.messages
            .where((message) => message.id != userMessage.id)
            .toList(),
        sending: false,
        error: 'The AI assistant is unavailable right now.',
      );
      return false;
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> addActivityFollowUp({
    required AiAction action,
    required bool completed,
  }) async {
    if (_disposed) return;
    _hasLocalChanges = true;
    final message = AiMessage.local(
      role: AiRole.assistant,
      content: AiSafety.activityFollowUp(action, completed: completed),
    );
    state = state.copyWith(
      messages: [...state.messages, message],
      crisis: false,
      clearError: true,
    );
    await _repo.cacheMessages(state.messages);
  }
}
