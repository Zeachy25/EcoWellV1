import 'package:flutter/material.dart';

import '../../../core/utils/format.dart';
import '../domain/run_models.dart';

/// One row of Quick Run history (dashboard and the history screen).
class RunListTile extends StatelessWidget {
  const RunListTile({super.key, required this.record, this.onTap});

  final RunRecord record;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final pending = record.status == RunStatus.pendingSync;

    final subtitle = [
      formatShortDate(record.startedAt),
      formatTime(record.startedAt),
      formatTimer(record.durationSeconds),
      if (record.avgPaceSecondsPerKm != null)
        '${formatPace(record.avgPaceSecondsPerKm)} /km',
    ].join(' \u00b7 ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(record.type.icon, color: scheme.primary),
        ),
        title: Text(record.type.label),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatDistance(record.distanceMeters),
              style: textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (pending)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, size: 12, color: scheme.outline),
                  const SizedBox(width: 2),
                  Text('waiting to sync',
                      style: textTheme.labelSmall
                          ?.copyWith(color: scheme.outline)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
