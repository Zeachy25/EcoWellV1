import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../domain/run_models.dart';

/// Map snapshot + stats of one finished run. Used both by the record
/// screen's summary (after Stop) and by the history list's detail sheet.
class RunSummaryView extends StatefulWidget {
  const RunSummaryView({
    super.key,
    required this.record,
    this.interactiveMap = false,
  });

  final RunRecord record;

  /// History detail allows panning the map; the post-run summary is a
  /// static snapshot.
  final bool interactiveMap;

  @override
  State<RunSummaryView> createState() => _RunSummaryViewState();
}

class _RunSummaryViewState extends State<RunSummaryView> {
  GoogleMapController? _map;

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  void _fitToBounds(List<LatLng> points) {
    final controller = _map;
    if (controller == null || points.length < 2) return;
    var south = points.first.latitude, north = south;
    var west = points.first.longitude, east = west;
    for (final p in points) {
      south = p.latitude < south ? p.latitude : south;
      north = p.latitude > north ? p.latitude : north;
      west = p.longitude < west ? p.longitude : west;
      east = p.longitude > east ? p.longitude : east;
    }
    // A single point (or a tiny wiggle) makes zero-size bounds; pad them.
    const pad = 0.0015;
    if (north - south < pad) {
      south -= pad;
      north += pad;
    }
    if (east - west < pad) {
      west -= pad;
      east += pad;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        controller.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(south, west),
              northeast: LatLng(north, east),
            ),
            48,
          ),
        );
      } catch (e) {
        debugPrint('Map bounds error: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final textTheme = Theme.of(context).textTheme;
    final points = [for (final p in record.path) p.latLng];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 220,
            color: AppColors.surfaceMuted,
            child: points.isEmpty
                ? const Center(
                    child: Icon(Icons.route_outlined,
                        size: 56, color: AppColors.textTertiary),
                  )
                : GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: points[points.length ~/ 2],
                      zoom: points.length > 1 ? 15 : 18,
                    ),
                    polylines: {
                      Polyline(
                        polylineId: const PolylineId('run'),
                        points: points,
                        width: 6,
                        color: AppColors.primaryGreen,
                        jointType: JointType.round,
                        startCap: Cap.roundCap,
                        endCap: Cap.roundCap,
                      ),
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('start'),
                        position: points.first,
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueGreen,
                        ),
                      ),
                      if (points.length > 1)
                        Marker(
                          markerId: const MarkerId('end'),
                          position: points.last,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange,
                          ),
                        ),
                    },
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: widget.interactiveMap,
                    rotateGesturesEnabled: widget.interactiveMap,
                    tiltGesturesEnabled: widget.interactiveMap,
                    onMapCreated: (c) {
                      _map = c;
                      _fitToBounds(points);
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _Stat(
              label: 'Time',
              value: formatTimer(record.durationSeconds),
              textTheme: textTheme,
            ),
            _Stat(
              label: 'Distance',
              value: formatDistance(record.distanceMeters),
              textTheme: textTheme,
            ),
            _Stat(
              label: 'Pace',
              value: record.avgPaceSecondsPerKm == null
                  ? '-'
                  : '${formatPace(record.avgPaceSecondsPerKm)} /km',
              textTheme: textTheme,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.textTheme});

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}
