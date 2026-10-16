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
