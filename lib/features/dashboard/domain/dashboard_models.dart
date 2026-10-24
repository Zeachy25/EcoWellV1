/// One finished visit, as shown in the dashboard.
class VisitRecord {
  const VisitRecord({
    required this.placeName,
    required this.entryTime,
    required this.exitTime,
    required this.preScore,
    required this.postScore,
    required this.reduction,
  });

  final String placeName;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int preScore;
  final int postScore;

  /// before minus after. Positive = stress went down.
  final int reduction;

  Duration? get duration => exitTime?.difference(entryTime);

  factory VisitRecord.fromJson(Map<String, dynamic> j) {
    final exit = j['exit_time'] as String?;
    return VisitRecord(
      placeName: (j['place_name'] as String?) ?? 'Green space',
      entryTime: DateTime.parse(j['entry_time'] as String).toLocal(),
      exitTime: exit == null ? null : DateTime.parse(exit).toLocal(),
      preScore: (j['pre_score'] as num).toInt(),
      postScore: (j['post_score'] as num).toInt(),
      reduction: (j['stress_reduction_score'] as num).toInt(),
    );
  }
}

class DashboardData {
  const DashboardData({
    required this.streakCount,
    required this.longestStreak,
    required this.totalVisits,
    required this.distinctPlaces,
    required this.avgReduction,
    required this.bestReduction,
    required this.totalMinutes,
    required this.activitiesDone,
    required this.recent,
  });

  final int streakCount;
  final int longestStreak;
  final int totalVisits;
  final int distinctPlaces;

  /// Average Stress Reduction Score (null before the first visit).
  final double? avgReduction;
  final int? bestReduction;
  final int totalMinutes;

  /// Breathing / grounding sessions finished.
  final int activitiesDone;

  /// Newest first (up to 30).
  final List<VisitRecord> recent;

  factory DashboardData.fromJson(Map<String, dynamic> j) {
    return DashboardData(
      streakCount: (j['streak_count'] as num?)?.toInt() ?? 0,
      longestStreak: (j['longest_streak'] as num?)?.toInt() ?? 0,
      totalVisits: (j['total_visits'] as num?)?.toInt() ?? 0,
      distinctPlaces: (j['distinct_places'] as num?)?.toInt() ?? 0,
      avgReduction: (j['avg_reduction'] as num?)?.toDouble(),
      bestReduction: (j['best_reduction'] as num?)?.toInt(),
      totalMinutes: (j['total_minutes'] as num?)?.toInt() ?? 0,
      activitiesDone: (j['activities_done'] as num?)?.toInt() ?? 0,
      recent: [
        for (final r in (j['recent'] as List<dynamic>? ?? const []))
          VisitRecord.fromJson(Map<String, dynamic>.from(r as Map)),
      ],
    );
  }
}
