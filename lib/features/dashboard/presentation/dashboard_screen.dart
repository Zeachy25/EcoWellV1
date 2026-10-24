import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/format.dart';
import '../../runs/data/run_repository.dart';
import '../../runs/presentation/run_list_tile.dart';
import '../data/dashboard_repository.dart';
import '../domain/dashboard_models.dart';
import 'reduction_chart.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    try {
      await ref.read(dashboardProvider.future);
    } catch (_) {
      // The error state is shown by the screen itself.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Dashboard error: $e');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load your dashboard. '
                    'Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _refresh(ref),
                    child: const Text('Try again'),
                  ),
                ],
              ),
            ),
          );
        },
        data: (d) => RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: _Content(data: d),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data});

  final DashboardData data;

  String get _bestText {
    final b = data.bestReduction;
    if (b == null) return '-';
    return b > 0 ? '+$b' : '$b';
  }

  String get _avgText {
    final a = data.avgReduction;
    if (a == null) return '-';
    return '${a > 0 ? '+' : ''}${a.toStringAsFixed(1)}';
  }

  /// formatDuration() rounds up to "< 1 min", so show a plain zero instead.
  String get _outdoorsText => data.totalMinutes <= 0
      ? '0 min'
      : formatDuration(data.totalMinutes * 60.0);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Chart: last 10 visits, oldest on the left.
    final chartVisits = data.recent.take(10).toList().reversed.toList();
    final chartValues = [for (final v in chartVisits) v.reduction];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // A brand-new user sees the whole layout, plus a short explanation.
        if (data.totalVisits == 0) ...[
          const _GettingStartedCard(),
          const SizedBox(height: 12),
        ],
        _StatRow(
          left: _StatCard(
            icon: Icons.local_fire_department,
            value: '${data.streakCount}',
            label: 'Day streak',
          ),
          right: _StatCard(
            icon: Icons.emoji_events,
            value: '${data.longestStreak}',
            label: 'Longest streak',
          ),
        ),
        const SizedBox(height: 12),
        _StatRow(
          left: _StatCard(
            icon: Icons.park,
            value: '${data.totalVisits}',
            label: data.totalVisits == 1 ? 'Visit' : 'Visits',
          ),
          right: _StatCard(
            icon: Icons.place,
            value: '${data.distinctPlaces}',
            label:
                data.distinctPlaces == 1 ? 'Place visited' : 'Places visited',
          ),
        ),
        const SizedBox(height: 12),
        _StatRow(
          left: _StatCard(
            icon: Icons.self_improvement,
            value: _avgText,
            label: 'Avg stress reduction',
          ),
          right: _StatCard(
            icon: Icons.schedule,
            value: _outdoorsText,
            label: 'Time outdoors',
          ),
        ),
        const SizedBox(height: 12),
        _StatRow(
          left: _StatCard(
            icon: Icons.spa,
            value: '${data.activitiesDone}',
            label: data.activitiesDone == 1 ? 'Activity done' : 'Activities done',
          ),
          right: _StatCard(
            icon: Icons.military_tech,
            value: _bestText,
            label: 'Best reduction',
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stress Reduction by visit',
                    style: textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  chartValues.isEmpty
                      ? 'Finish your first visit and your scores will show up here.'
                      : 'Last ${chartValues.length} '
                          '${chartValues.length == 1 ? 'visit' : 'visits'}. '
                          'Bars above the line mean your stress went down.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (chartValues.isEmpty)
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, size: 40, color: scheme.outline),
                          const SizedBox(height: 8),
                          Text(
                            'No visits recorded yet',
                            style: textTheme.bodyMedium
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ReductionChart(values: chartValues),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _RunsSection(),
        const SizedBox(height: 20),
        Text('Recent visits',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (data.recent.isEmpty) const _NoVisitsCard(),
        if (data.recent.isNotEmpty)
          for (final v in data.recent.take(10)) _VisitTile(visit: v),
        const SizedBox(height: 16),
        Text(
          'EcoWell is a wellness tool, not a medical assessment.',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Recent Quick Runs, read from the phone so the section works offline.
class _RunsSection extends ConsumerWidget {
  const _RunsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final async = ref.watch(runHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Quick Runs',
                style: textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            TextButton(
              onPressed: () => context.push('/runs'),
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        async.when(
          loading: () => const SizedBox.shrink(),
          error: (e, _) {
            debugPrint('Dashboard runs error: $e');
            return const SizedBox.shrink();
          },
          data: (runs) {
            if (runs.isEmpty) return const _NoRunsCard();
            return Column(
              children: [
                for (final run in runs.take(3)) RunListTile(record: run),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _NoRunsCard extends StatelessWidget {
  const _NoRunsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.directions_run, color: scheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Record a walk or run with Quick Run (the + button) '
                'and it will show up here.',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown to a user who has not finished a visit yet: the dashboard is not
/// empty, it just has nothing to count.
class _GettingStartedCard extends StatelessWidget {
  const _GettingStartedCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      color: scheme.primaryContainer,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.insights, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Getting started',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Visit a green space and complete the short check-in. '
                    'Your streak, scores and history will fill in on this page.',
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder in the Recent visits list before the first finished visit.
class _NoVisitsCard extends StatelessWidget {
  const _NoVisitsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.park_outlined, color: scheme.outline),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No visits yet. Your first finished visit will appear here.',
                style: textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two cards side by side. Both take the height of the taller one, so the
/// content never overflows (even with long labels or large text sizes).
class _StatRow extends StatelessWidget {
  const _StatRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            Text(label, style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  const _VisitTile({required this.visit});

  final VisitRecord visit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final r = visit.reduction;
    final color = r > 0 ? scheme.primary : (r < 0 ? scheme.error : scheme.outline);
    final d = visit.duration;

    final parts = [
      formatShortDate(visit.entryTime),
      formatTime(visit.entryTime),
      if (d != null) formatDuration(d.inSeconds.toDouble()),
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            r > 0
                ? Icons.trending_down
                : (r < 0 ? Icons.trending_up : Icons.trending_flat),
            color: color,
          ),
        ),
        title: Text(visit.placeName),
        subtitle: Text(parts.join(' \u00b7 ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              r > 0 ? '+$r' : '$r',
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: color),
            ),
            Text('${visit.preScore} \u2192 ${visit.postScore}',
                style: textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
