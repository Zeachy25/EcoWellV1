import 'package:flutter_test/flutter_test.dart';
import 'package:ecowell/features/ai/domain/ai_message.dart';

void main() {
  test('local messages round-trip through JSON as local rows', () {
    final created = DateTime.utc(2026, 11, 7, 10, 30);
    final message = AiMessage.local(
      role: AiRole.assistant,
      content: 'Take three slow breaths.',
      createdAt: created,
      action: AiAction.breathing,
    );

    expect(message.isUser, isFalse);
    expect(message.isLocal, isTrue);
    expect(message.id, startsWith('local:'));
    expect(message.action, AiAction.breathing);

    final restored = AiMessage.fromJson(message.toJson());
    expect(restored.role, AiRole.assistant);
    expect(restored.content, 'Take three slow breaths.');
    expect(restored.isLocal, isTrue);
    expect(restored.isLocalFallback, isFalse);
    expect(restored.createdAt.toUtc(), created);
    expect(restored.id, message.id);
    expect(restored.action, AiAction.breathing);
  });

  test('fallback messages retain their local suggestion marker in cache', () {
    final message = AiMessage.local(
      role: AiRole.assistant,
      content: 'Try a breathing pause.',
      isLocalFallback: true,
    );

    final restored = AiMessage.fromJson(message.toJson());

    expect(restored.isLocal, isTrue);
    expect(restored.isLocalFallback, isTrue);
  });

  test('server rows parse user and assistant roles with UTC timestamps', () {
    final user = AiMessage.fromJson({
      'id': 'row-1',
      'role': 'user',
      'content': 'I feel overwhelmed',
      'created_at': '2026-11-07T02:00:00.000Z',
    });
    final assistant = AiMessage.fromJson({
      'id': 'row-2',
      'role': 'assistant',
      'content': 'Let us try a grounding exercise.',
      'action': 'grounding',
      'created_at': '2026-11-07T02:00:01.000Z',
    });

    expect(user.isUser, isTrue);
    expect(user.isLocal, isFalse);
    expect(user.action, isNull);
    expect(assistant.role, AiRole.assistant);
    expect(assistant.action, AiAction.grounding);
    expect(assistant.createdAt.isUtc, isFalse);
    expect(assistant.createdAt.toUtc(), DateTime.utc(2026, 11, 7, 2, 0, 1));
  });

  test('missing fields fall back to safe defaults', () {
    final message = AiMessage.fromJson(const {});

    expect(message.role, AiRole.user);
    expect(message.content, isEmpty);
    expect(message.id, startsWith('local:'));
    expect(message.isLocal, isFalse);
    expect(message.action, isNull);
  });

  test('unknown or missing action values are ignored', () {
    expect(AiMessage.actionFromJson('breathing'), AiAction.breathing);
    expect(AiMessage.actionFromJson('grounding'), AiAction.grounding);
    expect(AiMessage.actionFromJson('none'), isNull);
    expect(AiMessage.actionFromJson('unknown'), isNull);
    expect(AiMessage.actionFromJson(null), isNull);
  });

  test('AiException only allows fallback for recoverable codes', () {
    expect(
      const AiException('offline', 'No connection').canUseFallback,
      isTrue,
    );
    expect(const AiException('timeout', 'Timed out').canUseFallback, isTrue);
    expect(
      const AiException('ai_unavailable', 'No key').canUseFallback,
      isTrue,
    );
    expect(
      const AiException('rate_limited', 'Slow down').canUseFallback,
      isFalse,
    );
    expect(
      const AiException('unauthorized', 'Sign in again').canUseFallback,
      isFalse,
    );
  });
}
