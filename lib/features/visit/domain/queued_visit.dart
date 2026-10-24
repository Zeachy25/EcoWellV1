/// A visit that lives on the phone until the server has it. Created when the
/// user starts a visit without a connection; `VisitSyncService` uploads it as
/// soon as the network returns.
class QueuedVisit {
  const QueuedVisit({
    required this.id,
    required this.userId,
    required this.placeId,
    required this.placeName,
    required this.entryTime,
    required this.status,
    this.serverVisitId,
    this.preAnswers,
    this.postAnswers,
    this.quietRating,
  });

  /// Client-generated id (the server id is added by [serverVisitId]).
  final String id;
  final String userId;
  final String placeId;

  /// Kept on the phone so the Home card can name the place offline.
  final String placeName;

  /// Set once the visit row exists in Supabase.
  final String? serverVisitId;
  final DateTime entryTime;

  /// PSS-4 answers, 4 numbers 0-4 each.
  final List<int>? preAnswers;
  final List<int>? postAnswers;
  final int? quietRating;
  final QueuedVisitStatus status;

  bool get isFinished => status == QueuedVisitStatus.pendingSync;

  QueuedVisit copyWith({
    String? serverVisitId,
    List<int>? preAnswers,
    List<int>? postAnswers,
    int? quietRating,
    QueuedVisitStatus? status,
  }) {
    return QueuedVisit(
      id: id,
      userId: userId,
      placeId: placeId,
      placeName: placeName,
      serverVisitId: serverVisitId ?? this.serverVisitId,
      entryTime: entryTime,
      preAnswers: preAnswers ?? this.preAnswers,
      postAnswers: postAnswers ?? this.postAnswers,
      quietRating: quietRating ?? this.quietRating,
      status: status ?? this.status,
    );
  }
}

enum QueuedVisitStatus {
  /// Started, still going. The user is inside the green space.
  inProgress,

  /// Post answers and Quiet rating are stored, waiting for the network.
  pendingSync,

  /// Cancelled while offline, waiting to be marked abandoned on the server.
  abandoned,
}
