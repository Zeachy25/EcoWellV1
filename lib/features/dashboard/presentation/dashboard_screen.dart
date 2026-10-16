import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/format.dart';
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
          child: d.totalVisits == 0 ? const _EmptyState() : _Content(data: d),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // A ListView so pull-to-refresh still works.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 64),
        Icon(Icons.insights, size: 72, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          'Your dashboard is waiting',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text(
          'Complete your first visit to a green space and your streak, '
          'stress reduction scores, and history will appear here.',
          textAlign: TextAlign.center,
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Chart: last 10 visits, oldest on the left.
    final chartVisits = data.recent.take(10).toList().reversed.toList();
    final chartValues = [for (final v in chartVisits) v.reduction];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
            value: formatDuration(data.totalMinutes * 60.0),
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
                  'Last ${chartValues.length} '
                  '${chartValues.length == 1 ? 'visit' : 'visits'}. '
                  'Bars above the line mean your stress went down.',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                ReductionChart(values: chartValues),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Recent visits',
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
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
