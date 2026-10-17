import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/dev_flags.dart';
import '../../../core/utils/format.dart';
import '../../geofence/data/geofence_providers.dart';
import '../data/map_providers.dart';
import '../domain/green_space.dart';
import 'map_helpers.dart';
import 'place_details_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _controller;
  String? _selectedId;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  double? _distanceTo(GreenSpace s, Position? pos) {
    if (pos == null) return null;
    return Geolocator.distanceBetween(
        pos.latitude, pos.longitude, s.lat, s.lng);
  }

  Future<void> _focus(GreenSpace s) async {
    setState(() => _selectedId = s.id);
    final c = _controller;
    if (c == null) return;
    try {
      await c.animateCamera(CameraUpdate.newLatLngBounds(s.bounds, 80));
    } catch (_) {
      await c.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(s.lat, s.lng), 17));
    }
  }

  void _openDetails(GreenSpace s, Position? pos) {
    _focus(s);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => PlaceDetailsSheet(
        space: s,
        distanceMeters: _distanceTo(s, pos),
        onDirections: () {
          if (mounted) context.push('/navigate', extra: s);
        },
        onSimulateArrival: kEnableTestArrivalButton
            ? (delay) => ref
                .read(geofenceServiceProvider)
                .simulateArrival(s, delay: delay)
            : null,
      ),
    );
  }

  void _refresh() {
    ref.invalidate(greenSpacesProvider);
    ref.invalidate(userPositionProvider);
  }

  @override
  Widget build(BuildContext context) {
    final spacesAsync = ref.watch(greenSpacesProvider);
    final posAsync = ref.watch(userPositionProvider);
    final pos = posAsync.hasValue ? posAsync.value : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: spacesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) {
          debugPrint('Green spaces error: $e');
          return _MessageView(
            icon: Icons.cloud_off,
            message: 'Could not load green spaces. '
                'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: _refresh,
          );
        },
        data: (spaces) {
          if (spaces.isEmpty) {
            return const _MessageView(
              icon: Icons.park_outlined,
              message: 'No green spaces have been added yet.',
            );
          }
          return _buildContent(spaces, pos);
        },
      ),
    );
  }

  Widget _buildContent(List<GreenSpace> spaces, Position? pos) {
    // Nearest first when we know where the user is.
    final sorted = [...spaces];
    if (pos != null) {
      sorted.sort(
        (a, b) => _distanceTo(a, pos)!.compareTo(_distanceTo(b, pos)!),
      );
    }

    final markers = <Marker>{
      for (final s in spaces)
        Marker(
          markerId: MarkerId(s.id),
          position: LatLng(s.lat, s.lng),
          infoWindow: InfoWindow(title: s.name),
          onTap: () => _openDetails(s, pos),
        ),
    };

    final polygons = <Polygon>{
      for (final s in spaces)
        if (s.boundary.length >= 3)
          Polygon(
            polygonId: PolygonId(s.id),
            points: s.boundary,
            strokeWidth: s.id == _selectedId ? 4 : 2,
            strokeColor: Colors.green.shade800,
            fillColor:
                Colors.green.withValues(alpha: s.id == _selectedId ? 0.4 : 0.25),
            consumeTapEvents: true,
            onTap: () => _openDetails(s, pos),
          ),
    };

    final first = sorted.first;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(first.lat, first.lng),
              zoom: 15,
            ),
            markers: markers,
            polygons: polygons,
            myLocationEnabled: pos != null,
            myLocationButtonEnabled: pos != null,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) => _controller = c,
          ),
        ),
        if (pos == null)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.location_off, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Turn on location to see distances.'),
                ),
                TextButton(
                  onPressed: () => ref.invalidate(userPositionProvider),
                  child: const Text('Enable'),
                ),
              ],
            ),
          ),
        Expanded(
          flex: 4,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: sorted.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = sorted[i];
              final d = _distanceTo(s, pos);
              return ListTile(
                selected: s.id == _selectedId,
                leading: CircleAvatar(
                  child: Icon(categoryIcon(s.category)),
                ),
                title: Text(s.name),
                subtitle: Text(
                  [
                    s.categoryLabel,
                    if (d != null) formatDistance(d),
                  ].join(' \u00b7 '),
                ),
                trailing: Text(quietScoreText(s)),
                onTap: () => _openDetails(s, pos),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MessageView extends StatelessWidget {
  const _MessageView({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
