import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/offline/json_cache.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../geofence/data/geofence_providers.dart';
import '../../home/data/profile_providers.dart';
import '../../map/domain/green_space.dart';
import '../data/offline_visit_store.dart';
import '../data/visit_providers.dart';
import '../data/visit_repository.dart';
import '../domain/visit_models.dart';
import 'pss_questionnaire.dart';
import 'quiet_rating_step.dart';
import 'streak_popup.dart';
import 'visit_result_view.dart';

enum _Step { loading, pre, active, post, rating, result, error }

/// One screen that walks through a whole visit:
/// before questions -> at the place -> after questions -> Quiet rating -> result.
class VisitFlowScreen extends ConsumerStatefulWidget {
  const VisitFlowScreen({super.key, required this.space});

  final GreenSpace space;

  @override
  ConsumerState<VisitFlowScreen> createState() => _VisitFlowScreenState();
}

class _VisitFlowScreenState extends ConsumerState<VisitFlowScreen> {
  _Step _step = _Step.loading;
  ActiveVisit? _visit;
  List<int>? _postAnswers;
  VisitResult? _result;
  bool _busy = false;
  bool _pendingSync = false;
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  VisitRepository get _repo => ref.read(visitRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _start() async {
    setState(() => _step = _Step.loading);
    try {
      final v = await _repo.startOrResume(widget.space);
      if (!mounted) return;
      ref.read(geofenceServiceProvider).setActivePlace(widget.space.id);
      setState(() {
        _visit = v;
        _step = v.hasPre ? _Step.active : _Step.pre;
      });
      if (v.hasPre) _startTimer();
    } catch (e) {
      debugPrint('Start visit error: $e');
      if (mounted) setState(() => _step = _Step.error);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    void tick() {
      final d = DateTime.now().difference(_visit!.entryTime);
      setState(() => _elapsed = d.isNegative ? Duration.zero : d);
    }

    tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) tick();
    });
  }

  Future<void> _submitPre(List<int> answers) async {
    setState(() => _busy = true);
    try {
      await _repo.savePreAssessment(_visit!.id, answers);
      if (!mounted) return;
      setState(() => _step = _Step.active);
      _startTimer();
    } catch (e) {
      debugPrint('Save pre-assessment error: $e');
      _message('Could not save your answers. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _submitPost(List<int> answers) {
    setState(() {
      _postAnswers = answers;
      _step = _Step.rating;
    });
  }

  /// The streak before this visit, from the last synced profile cache.
  Future<int> _previousStreak() async {
    final raw = await ref.read(jsonCacheProvider).read(CacheKeys.profile);
    final streak = raw is Map ? raw['streak_count'] : null;
    return streak is num ? streak.toInt() : 0;
  }

  Future<void> _submitRating(int rating) async {
    setState(() => _busy = true);
    try {
      final prevStreak = await _previousStreak();
      final r = await _repo.finishVisit(_visit!.id, _postAnswers!, rating);
      _timer?.cancel();
      if (!mounted) return;
      // Still on the phone? Then the result is local and the queue will
      // upload the visit when the connection returns.
      final pending =
          await ref.read(offlineVisitStoreProvider).find(_visit!.id) != null;
      ref.invalidate(profileProvider); // refresh the streak on Home
      ref.invalidate(dashboardProvider);
      ref.read(geofenceServiceProvider).onVisitClosed();
      ref.invalidate(activeVisitProvider);
      setState(() {
        _result = r;
        _pendingSync = pending;
        _step = _Step.result;
      });
      // Celebrate only when the server confirmed a higher streak.
      if (!pending && r.streakCount > prevStreak && mounted) {
        await showStreakPopup(context, r.streakCount);
      }
    } catch (e) {
      debugPrint('Finish visit error: $e');
      _message('Could not save your visit. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelVisit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this visit?'),
        content: const Text('Your answers for this visit will not be counted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel visit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.abandonVisit(_visit!.id);
      ref.read(geofenceServiceProvider).onVisitClosed();
      ref.invalidate(activeVisitProvider);
      if (mounted) context.pop();
    } catch (e) {
      debugPrint('Abandon visit error: $e');
      _message('Could not cancel the visit. Please try again.');
    }
  }

  String _formatElapsed(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.space.name)),
      body: SafeArea(child: _buildStep()),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.loading:
        return const Center(child: CircularProgressIndicator());

      case _Step.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Could not start your visit. Check your connection and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _start, child: const Text('Try again')),
              ],
            ),
          ),
        );

      case _Step.pre:
        return PssQuestionnaire(
          title: 'Welcome to ${widget.space.name}',
          intro: 'You have arrived. Answer 4 quick questions about how you '
              'feel right now. There are no right or wrong answers.',
          submitLabel: 'Start visit',
          busy: _busy,
          onSubmit: _submitPre,
        );

      case _Step.active:
        return _buildActive();

      case _Step.post:
        return PssQuestionnaire(
          title: 'How do you feel now?',
          intro: 'Answer the same 4 questions again, based on how you feel '
              'right now.',
          submitLabel: 'Continue',
          onSubmit: _submitPost,
        );

      case _Step.rating:
        return QuietRatingStep(
          placeName: widget.space.name,
          busy: _busy,
          onSubmit: _submitRating,
        );

      case _Step.result:
        return VisitResultView(
          result: _result!,
          pendingSync: _pendingSync,
          onDone: () => context.pop(),
        );
    }
  }

  Widget _buildActive() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.park, size: 64, color: scheme.primary),
          const SizedBox(height: 12),
          Text('You are at ${widget.space.name}',
              textAlign: TextAlign.center, style: textTheme.titleLarge),
          const SizedBox(height: 16),
          Text(
            _formatElapsed(_elapsed),
            style: textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const Text('time spent here'),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('While you are here',
                      style: textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('\u2022 Take a few slow, deep breaths.'),
                  const Text('\u2022 Notice 5 things you can see and 4 you can hear.'),
                  const Text('\u2022 Put your phone away for a few minutes.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/activities/breathing'),
                  icon: const Icon(Icons.air),
                  label: const Text('Breathing'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/activities/grounding'),
                  icon: const Icon(Icons.spa),
                  label: const Text('Grounding'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(() => _step = _Step.post),
            child: const Text('End visit'),
          ),
          TextButton(
            onPressed: _cancelVisit,
            child: const Text('Cancel visit'),
          ),
        ],
      ),
    );
  }
}
