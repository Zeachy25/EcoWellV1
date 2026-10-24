import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/location_service.dart';
import '../../../core/utils/format.dart';
import '../../geofence/data/geofence_providers.dart';
import '../../map/domain/geo_utils.dart';
import '../../map/domain/green_space.dart';
import '../data/ors_routing_service.dart';
import '../domain/route_models.dart';
import '../domain/route_progress.dart';

/// In-app walking directions: route line, live position, next instruction,
/// automatic re-routing, and an arrival prompt that offers "Start visit".
class NavigationScreen extends ConsumerStatefulWidget {
  const NavigationScreen({
    super.key,
    required this.space,
    this.manualCheckIn = false,
  });

  final GreenSpace space;
  final bool manualCheckIn;

  @override
  ConsumerState<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends ConsumerState<NavigationScreen> {
  final _service = OrsRoutingService();

  GoogleMapController? _map;
  StreamSubscription<Position>? _sub;

  RouteInfo? _route;
  RouteProgress? _progress;
  Position? _pos;

  String? _error;
  bool _loading = true;
  bool _rerouting = false;
  bool _arrived = false;
  bool _following = true;
  bool _animating = false;
  double _bearing = 0;
  DateTime? _lastReroute;
  bool _visitStartedFromArrival = false;

  LatLng get _dest => LatLng(widget.space.lat, widget.space.lng);

  @override
  void initState() {
    super.initState();
    if (widget.manualCheckIn) {
      ref
          .read(geofenceServiceProvider)
          .setManualNavigationTarget(widget.space.id);
    }
    _begin();
  }

  @override
  void dispose() {
    if (widget.manualCheckIn) {
      ref
          .read(geofenceServiceProvider)
          .clearManualNavigationTarget(
            widget.space.id,
            visitStarted: _visitStartedFromArrival,
          );
    }
    _sub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  void _startVisit() {
    _visitStartedFromArrival = true;
    context.push<void>('/visit', extra: widget.space);
  }

  // ---- loading the first route ----------------------------------------

  Future<void> _begin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final pos = await LocationService.currentPosition();
    if (!mounted) return;
    if (pos == null) {
      setState(() {
        _loading = false;
        _error = 'Turn on location and allow it for EcoWell to get directions.';
      });
      return;
    }
    _pos = pos;

    // Already at the place: no route needed.
    if (isInsideGeofence(pos, widget.space)) {
      setState(() {
        _loading = false;
        _arrived = true;
      });
      return;
    }

    try {
      final route = await _service.walkingRoute(
        from: LatLng(pos.latitude, pos.longitude),
        to: _dest,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _progress = computeProgress(route, pos.latitude, pos.longitude);
        _loading = false;
      });
      _listen();
    } on RoutingException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (e) {
      debugPrint('Navigation error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not get directions right now.';
        });
      }
    }
  }

  /// Fallback when in-app directions cannot be fetched (no connection,
  /// routing quota, ...): hand the trip to the Google Maps app.
  Future<void> _openInGoogleMaps() async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${widget.space.lat},${widget.space.lng}',
      'travelmode': 'walking',
    });
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Open in Google Maps failed: $e');
    }
  }

  // ---- live position ----------------------------------------------------

  void _listen() {
    _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen(_onPosition, onError: (Object e) {
      debugPrint('Position stream error: $e');
    });
  }

  void _onPosition(Position p) {
    final route = _route;
    if (route == null || _arrived) return;

    final progress = computeProgress(route, p.latitude, p.longitude);
    final arrived = isInsideGeofence(p, widget.space);

    setState(() {
      _pos = p;
      _progress = progress;
      _arrived = arrived;
    });

    if (arrived) {
      _sub?.cancel();
      return;
    }

    if (p.speed > 1 && p.heading >= 0) _bearing = p.heading;
    if (_following) _followCamera(p);
    if (progress.offRouteMeters > 40) _maybeReroute(p);
  }

  Future<void> _followCamera(Position p) async {
    final c = _map;
    if (c == null) return;
    _animating = true;
    try {
      await c.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(
        target: LatLng(p.latitude, p.longitude),
        zoom: 18,
        bearing: _bearing,
        tilt: 40,
      )));
    } catch (_) {
      // The map may be closing; ignore.
    } finally {
      _animating = false;
    }
  }

  /// Asks for a new route when the user leaves the current one
  /// (at most once every 15 seconds).
  Future<void> _maybeReroute(Position p) async {
    if (_rerouting) return;
    final last = _lastReroute;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 15)) {
      return;
    }
    _lastReroute = DateTime.now();
    setState(() => _rerouting = true);
    try {
      final route = await _service.walkingRoute(
        from: LatLng(p.latitude, p.longitude),
        to: _dest,
      );
      if (!mounted) return;
      setState(() {
        _route = route;
        _progress = computeProgress(route, p.latitude, p.longitude);
      });
    } catch (e) {
      debugPrint('Reroute failed: $e');
    } finally {
      if (mounted) setState(() => _rerouting = false);
    }
  }

  // ---- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Directions to ${widget.space.name}',
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Finding the best way...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: _begin,
        onClose: () => context.pop(),
        onOpenExternal: _openInGoogleMaps,
      );
    }
    final route = _route;
    if (route == null) return _buildAlreadyThere();
    return _buildNavigation(route);
  }

  Widget _buildAlreadyThere() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'You are already at ${widget.space.name}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'You are inside the location. Start your check-in when you are ready.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _startVisit,
              child: const Text('Start check-in'),
            ),
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigation(RouteInfo route) {
    final progress = _progress!;
    final pos = _pos!;
    final space = widget.space;

    // What the banner shows
    final steps = route.steps;
    final atStart = progress.traveledMeters < 15 && steps.isNotEmpty;
    String instruction;
    IconData icon;
    if (_arrived) {
      instruction = 'You have arrived';
      icon = Icons.flag;
    } else if (atStart) {
      instruction = steps.first.instruction;
      icon = _iconForType(steps.first.type);
    } else if (progress.stepIndex + 1 < steps.length) {
      final next = steps[progress.stepIndex + 1];
      instruction = next.instruction;
      icon = _iconForType(next.type);
    } else {
      instruction = 'Continue to your destination';
      icon = Icons.flag;
    }

    final remainingTime = route.distanceMeters <= 0
        ? 0.0
        : route.durationSeconds *
            (progress.remainingMeters / route.distanceMeters);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: 17,
          ),
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: route.points,
              width: 6,
              color: Colors.blue.shade700,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          },
          polygons: {
            if (space.boundary.length >= 3)
              Polygon(
                polygonId: const PolygonId('destination'),
                points: space.boundary,
                strokeWidth: 2,
                strokeColor: Colors.green.shade800,
                fillColor: Colors.green.withValues(alpha: 0.25),
              ),
          },
          markers: {
            Marker(
              markerId: const MarkerId('destination'),
              position: _dest,
              infoWindow: InfoWindow(title: space.name),
            ),
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) => _map = c,
          onCameraMoveStarted: () {
            // A finger gesture (not our own animation) stops auto-follow.
            if (!_animating && _following) {
              setState(() => _following = false);
            }
          },
        ),

        // Next instruction
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _InstructionBanner(
            icon: icon,
            distanceText:
                _arrived ? '' : formatDistance(progress.toNextMeters),
            instruction: instruction,
            rerouting: _rerouting,
          ),
        ),

        // Bottom panel
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_following && !_arrived)
                Padding(
                  padding: const EdgeInsets.only(right: 16, bottom: 8),
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    tooltip: 'Recenter',
                    onPressed: () {
                      setState(() => _following = true);
                      _followCamera(pos);
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),
              _BottomPanel(
                arrived: _arrived,
                placeName: space.name,
                remainingDistance: formatDistance(progress.remainingMeters),
                remainingTime: formatDuration(remainingTime),
                onEnd: () => context.pop(),
                onStartVisit: _startVisit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// openrouteservice maneuver codes -> icons.
  IconData _iconForType(int type) {
    switch (type) {
      case 0:
        return Icons.turn_left;
      case 1:
        return Icons.turn_right;
      case 2:
        return Icons.turn_sharp_left;
      case 3:
        return Icons.turn_sharp_right;
      case 4:
        return Icons.turn_slight_left;
      case 5:
        return Icons.turn_slight_right;
      case 6:
        return Icons.straight;
      case 7:
      case 8:
        return Icons.roundabout_left;
      case 9:
        return Icons.u_turn_left;
      case 10:
        return Icons.flag;
      case 11:
        return Icons.navigation;
      case 12:
        return Icons.fork_left;
      case 13:
        return Icons.fork_right;
      default:
        return Icons.straight;
    }
  }
}

class _InstructionBanner extends StatelessWidget {
  const _InstructionBanner({
    required this.icon,
    required this.distanceText,
    required this.instruction,
    required this.rerouting,
  });

  final IconData icon;
  final String distanceText;
  final String instruction;
  final bool rerouting;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.primaryContainer,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 40, color: scheme.onPrimaryContainer),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (distanceText.isNotEmpty)
                    Text(
                      distanceText,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  Text(
                    rerouting ? 'Rerouting...' : instruction,
                    style: textTheme.bodyLarge
                        ?.copyWith(color: scheme.onPrimaryContainer),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.arrived,
    required this.placeName,
    required this.remainingDistance,
    required this.remainingTime,
    required this.onEnd,
    required this.onStartVisit,
  });

  final bool arrived;
  final String placeName;
  final String remainingDistance;
  final String remainingTime;
  final VoidCallback onEnd;
  final VoidCallback onStartVisit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: scheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (arrived) ...[
                Row(
                  children: [
                    Icon(Icons.flag, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You have arrived at $placeName',
                        style: textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Start your check-in when you are ready.'),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: onStartVisit,
                  child: const Text('Start check-in'),
                ),
                TextButton(onPressed: onEnd, child: const Text('Not now')),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            remainingTime,
                            style: textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text('$remainingDistance remaining'),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onEnd,
                      child: const Text('End'),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                'Routes \u00a9 openrouteservice.org | '
                'Map data \u00a9 OpenStreetMap contributors',
                style: textTheme.bodySmall?.copyWith(fontSize: 10),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
    required this.onClose,
    this.onOpenExternal,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;
  final VoidCallback? onOpenExternal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alt_route,
                size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
            if (onOpenExternal != null)
              TextButton(
                onPressed: onOpenExternal,
                child: const Text('Open in Google Maps'),
              ),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
