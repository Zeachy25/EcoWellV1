import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/visit_models.dart';
import 'visit_repository.dart';

/// The user's open visit, if any. ref.invalidate(activeVisitProvider) after
/// a visit starts, finishes or is cancelled.
final activeVisitProvider = FutureProvider.autoDispose<ActiveVisitInfo?>(
  (ref) => ref.watch(visitRepositoryProvider).fetchActiveVisit(),
);
