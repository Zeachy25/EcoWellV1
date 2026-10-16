import 'dart:math' as math;

import 'route_models.dart';

/// Where the user is along the route.
class RouteProgress {
  const RouteProgress({
    required this.offRouteMeters,
    required this.traveledMeters,
    required this.remainingMeters,
    required this.stepIndex,
    required this.toNextMeters,
  });

  /// How far the user is from the route line.
  final double offRouteMeters;
  final double traveledMeters;
  final double remainingMeters;

  /// Index of the step the user is currently on.
  final int stepIndex;

  /// Meters until the end of the current step (the next maneuver).
  final double toNextMeters;
}

/// Finds the closest point on the route to (lat, lng) and measures progress.
RouteProgress computeProgress(RouteInfo route, double lat, double lng) {
  final pts = route.points;
  if (pts.length < 2) {
    return const RouteProgress(
      offRouteMeters: 0,
      traveledMeters: 0,
      remainingMeters: 0,
      stepIndex: 0,
      toNextMeters: 0,
    );
  }

  // Flat (local) meters around the user: good enough for short distances.
  final mLat = 110540.0;
  final mLng = 111320.0 * math.cos(lat * math.pi / 180);

  var bestDist = double.infinity;
  var bestSeg = 0;
  var bestT = 0.0;

  for (var i = 0; i < pts.length - 1; i++) {
    final ax = (pts[i].longitude - lng) * mLng;
    final ay = (pts[i].latitude - lat) * mLat;
    final bx = (pts[i + 1].longitude - lng) * mLng;
    final by = (pts[i + 1].latitude - lat) * mLat;
    final dx = bx - ax;
    final dy = by - ay;
    final len2 = dx * dx + dy * dy;
    var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
    t = t.clamp(0.0, 1.0);
    final px = ax + t * dx;
    final py = ay + t * dy;
    final d = math.sqrt(px * px + py * py);
    if (d < bestDist) {
      bestDist = d;
      bestSeg = i;
      bestT = t;
    }
  }

  final segLen = route.cumulative[bestSeg + 1] - route.cumulative[bestSeg];
  final traveled = route.cumulative[bestSeg] + bestT * segLen;
  final remaining = math.max(0.0, route.polylineLength - traveled);

  var stepIdx = 0;
  for (var k = 0; k < route.steps.length; k++) {
    if (route.steps[k].startIndex <= bestSeg) {
      stepIdx = k;
    } else {
      break;
    }
  }

  double toNext = remaining;
  if (route.steps.isNotEmpty) {
    final endIdx = math.min(route.steps[stepIdx].endIndex, pts.length - 1);
    toNext = math.max(0.0, route.cumulative[endIdx] - traveled);
  }

  return RouteProgress(
    offRouteMeters: bestDist,
    traveledMeters: traveled,
    remainingMeters: remaining,
    stepIndex: stepIdx,
    toNextMeters: toNext,
  );
}
