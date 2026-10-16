import 'package:flutter/material.dart';

import '../domain/green_space.dart';

IconData categoryIcon(String? category) {
  switch (category) {
    case 'park':
      return Icons.park;
    case 'mangrove':
      return Icons.water;
    case 'trail':
      return Icons.hiking;
    case 'beach':
      return Icons.beach_access;
    case 'garden':
      return Icons.local_florist;
    default:
      return Icons.nature;
  }
}

String quietScoreText(GreenSpace s) {
  final avg = s.quietScoreAvg;
  if (avg == null) return 'No ratings yet';
  return '\u2605 ${avg.toStringAsFixed(1)} (${s.quietRatingCount})';
}
