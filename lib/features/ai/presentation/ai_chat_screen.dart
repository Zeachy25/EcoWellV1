import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/responsive.dart';
import '../../activities/data/activity_repository.dart';
import '../../activities/domain/activity_models.dart';
import '../../map/data/map_providers.dart';
import '../data/ai_providers.dart';
import '../domain/ai_message.dart';
import '../domain/ai_safety.dart';

/// Full-screen conversation with the EcoWell AI coach.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  static const _quickPrompts = [
    'I feel stressed today',
    'Suggest a quiet place near me',
    'Help me calm down',
    'I need a short break',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<List<String>> _nearbyContext() async {
    try {
      final spaces = await ref
          .read(greenSpacesProvider.future)
          .timeout(const Duration(seconds: 1));
      if (spaces.isEmpty) return const [];

      final position = await LocationService.positionIfPermitted().timeout(
        const Duration(seconds: 1),
      );
      final ordered = [...spaces];
      if (position != null) {
        ordered.sort((a, b) {
          final distanceA = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            a.lat,
            a.lng,
          );
          final distanceB = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            b.lat,
            b.lng,
          );
          return distanceA.compareTo(distanceB);
        });
      }
      return [
        for (final space in ordered.take(5))
          '${space.name} (${space.categoryLabel})',
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    if (preset == null) _input.clear();

    final ok = await ref
        .read(aiChatControllerProvider.notifier)
        .send(text, nearbyFuture: _nearbyContext());

    if (!ok && mounted && preset == null) {
      _input.text = text;
      _input.selection = TextSelection.collapsed(offset: text.length);
    }
  }

  Future<void> _startAction(AiAction action) async {
    final type = action == AiAction.breathing ? 'breathing' : 'grounding';
    bool? completed;
    try {
      final activities = await ref.read(activitiesByTypeProvider(type).future);
      if (!mounted) return;
      if (activities.isNotEmpty) {
        completed =
            await context.push<bool>('/activity', extra: activities.first) ==
            true;
      } else {
        completed = await _openActivityList(type);
      }
    } catch (e) {
      debugPrint('Could not load $type activity: $e');
      if (mounted) {
        completed = await _openActivityList(type);
      }
    }
    if (mounted && completed != null) {
      await ref
          .read(aiChatControllerProvider.notifier)
          .addActivityFollowUp(action: action, completed: completed);
    }
  }

  Future<bool?> _openActivityList(String type) async {
    final outcome = await context.push<ActivityRunOutcome>(
      '/activities/$type',
      extra: true,
    );
    return switch (outcome) {
      ActivityRunOutcome.completed => true,
      ActivityRunOutcome.exitedEarly => false,
      null => null,
    };
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(aiChatControllerProvider);
    ref.listen<AiChatState>(aiChatControllerProvider, (previous, next) {
      if (previous == null ||
          previous.messages.length != next.messages.length ||
          previous.sending != next.sending) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: const _ChatTitle(),
      ),
      body: Column(
        children: [
          const _DisclaimerBar(),
          if (chat.error != null)
            _ErrorBar(
              message: chat.error!,
              onClose: () =>
                  ref.read(aiChatControllerProvider.notifier).clearError(),
            ),
          Expanded(
            child: chat.loading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                ? _EmptyChat(prompts: _quickPrompts, onPrompt: _send)
                : ListView.builder(
                    controller: _scroll,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      Responsive.horizontalPadding(context),
                      16,
                      Responsive.horizontalPadding(context),
                      16,
                    ),
                    itemCount: chat.messages.length + (chat.sending ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == chat.messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(
                        message: chat.messages[index],
                        onAction: _startAction,
                      );
                    },
                  ),
          ),
          if (chat.crisis) const _CrisisCard(),
          _Composer(controller: _input, sending: chat.sending, onSend: _send),
        ],
      ),
    );
  }
}

class _ChatTitle extends StatelessWidget {
  const _ChatTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _AiAvatar(size: 36),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EcoWell AI',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              'Your wellness companion',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryButtonGradient,
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.55),
    );
  }
}

class _DisclaimerBar extends StatelessWidget {
  const _DisclaimerBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.mintLight,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              AiSafety.disclaimer,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF1E8),
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            size: 18,
            color: AppColors.streakCoral,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary),
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.prompts, required this.onPrompt});

  final List<String> prompts;
  final ValueChanged<String> onPrompt;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        Responsive.horizontalPadding(context),
        24,
        Responsive.horizontalPadding(context),
        24,
      ),
      children: [
        const Center(child: _AiAvatar(size: 64)),
        const SizedBox(height: 16),
        Text(
          'Hi, I’m here to listen.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ask about stress, sleep, motivation, or finding a quiet green '
          'space. I can also suggest a breathing or grounding exercise.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final prompt in prompts)
              ActionChip(
                avatar: const Icon(Icons.chat_bubble_outline, size: 16),
                label: Text(prompt),
                onPressed: () => onPrompt(prompt),
              ),
          ],
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.onAction});

  final AiMessage message;
  final ValueChanged<AiAction> onAction;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: isUser ? AppColors.primaryButtonGradient : null,
        color: isUser ? null : AppColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
        border: isUser ? null : Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isUser ? Colors.white : AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          if (!isUser && message.action != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => onAction(message.action!),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              icon: Icon(
                message.action == AiAction.breathing ? Icons.air : Icons.spa,
                size: 18,
              ),
              label: Text(
                message.action == AiAction.breathing
                    ? 'Start breathing exercise'
                    : 'Start grounding exercise',
              ),
            ),
          ],
          if (!isUser && message.isLocalFallback) ...[
            const SizedBox(height: 6),
            Text(
              'Local suggestion',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[const _AiAvatar(size: 28), const SizedBox(width: 8)],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const _AiAvatar(size: 28),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Thinking…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CrisisCard extends StatelessWidget {
  const _CrisisCard();

  Future<void> _call(BuildContext context, String phone) async {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: phone),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the dialer for $phone.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4ED),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFD8C2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite_outline, color: AppColors.streakCoral),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You deserve immediate support',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'If you are in danger, call 911. You can also reach a crisis '
            'hotline below.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final resource in AiSafety.crisisResources)
                OutlinedButton.icon(
                  onPressed: () => _call(context, resource.phone),
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: Text(
                    resource.phone == '911' ? 'Call 911' : resource.label,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final Future<void> Function([String? preset]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about stress, sleep, or a nearby place…',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppColors.inputBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: IconButton.filled(
                onPressed: sending ? null : () => onSend(),
                tooltip: 'Send',
                icon: sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
