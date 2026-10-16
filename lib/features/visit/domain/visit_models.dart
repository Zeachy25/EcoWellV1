/// A visit that is currently in progress.
class ActiveVisit {
  const ActiveVisit({
    required this.id,
    required this.entryTime,
    required this.hasPre,
  });

  final String id;
  final DateTime entryTime;

  /// true when the "before" assessment was already saved.
  final bool hasPre;
}

/// What the app shows after a visit is finished.
class VisitResult {
  const VisitResult({
    required this.preScore,
    required this.postScore,
    required this.stressReductionScore,
    required this.streakCount,
    required this.longestStreak,
  });

  final int preScore;
  final int postScore;

  /// before minus after. Positive = stress went down.
  final int stressReductionScore;
  final int streakCount;
  final int longestStreak;

  factory VisitResult.fromJson(Map<String, dynamic> j) {
    return VisitResult(
      preScore: (j['pre_score'] as num).toInt(),
      postScore: (j['post_score'] as num).toInt(),
      stressReductionScore: (j['stress_reduction_score'] as num).toInt(),
      streakCount: (j['streak_count'] as num).toInt(),
      longestStreak: (j['longest_streak'] as num).toInt(),
    );
  }
}

/// A visit that is still open, with the place name (for the Home card).
class ActiveVisitInfo {
  const ActiveVisitInfo({
    required this.visitId,
    required this.placeId,
    required this.placeName,
    required this.entryTime,
  });

  final String visitId;
  final String placeId;
  final String placeName;
  final DateTime entryTime;
}
