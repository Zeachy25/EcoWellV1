/// 850 -> "850 m", 1340 -> "1.3 km"
String formatDistance(double meters) {
  if (meters < 1000) return '${meters.round()} m';
  return '${(meters / 1000).toStringAsFixed(1)} km';
}

/// 40 -> "< 1 min", 600 -> "10 min", 4500 -> "1 h 15 min"
String formatDuration(double seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 1) return '< 1 min';
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "Oct 15"
String formatShortDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

/// "3:05 PM"
String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
}

/// 950 -> "950", 18300 -> "18.3k", 1250000 -> "1.3M"
String formatCount(int n) {
  String trim(double v, int digits) =>
      v.toStringAsFixed(digits).replaceAll(RegExp(r'\.0$'), '');
  if (n < 1000) return '$n';
  if (n < 1000000) {
    final k = n / 1000;
    return '${trim(k, k >= 100 ? 0 : 1)}k';
  }
  return '${trim(n / 1000000, 1)}M';
}

/// "just now", "5m ago", "3h ago", "2d ago", or "Oct 15"
String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return formatShortDate(t);
}
