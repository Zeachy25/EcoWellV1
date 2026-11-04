import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../../map/data/map_providers.dart';
import '../../map/domain/green_space.dart';
import '../../weather/data/weather_providers.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

class CommunityPostDetailsValue {
  const CommunityPostDetailsValue({
    required this.place,
    required this.visit,
    required this.includeVisit,
  });

  final GreenSpace place;
  final VisitStats? visit;
  final bool includeVisit;

  String? get visitId => includeVisit ? visit?.visitId : null;
  int? get visitMinutes => includeVisit ? visit?.minutes : null;
  int? get stressReduction => includeVisit ? visit?.reduction : null;
}

/// Shared place and visit selection for regular posts and My Day stories.
class CommunityPostDetails extends ConsumerStatefulWidget {
  const CommunityPostDetails({
    super.key,
    required this.onChanged,
    this.compact = false,
  });

  final ValueChanged<CommunityPostDetailsValue> onChanged;
  final bool compact;

  @override
  ConsumerState<CommunityPostDetails> createState() =>
      _CommunityPostDetailsState();
}

class _CommunityPostDetailsState extends ConsumerState<CommunityPostDetails> {
  GreenSpace? _place;
  VisitStats? _visit;
  bool _includeVisit = false;
  int _placeRequest = 0;

  @override
  void initState() {
    super.initState();
    _chooseDefaultPlace();
  }

  void _notifyChanged() {
    final place = _place;
    if (place == null) return;
    widget.onChanged(
      CommunityPostDetailsValue(
        place: place,
        visit: _visit,
        includeVisit: _includeVisit,
      ),
    );
  }

  Future<void> _chooseDefaultPlace() async {
    try {
      final spaces = await ref.read(greenSpacesProvider.future);
      if (spaces.isEmpty || !mounted) return;
      final Position? position = await ref.read(weatherPositionProvider.future);
      var best = spaces.first;
      if (position != null) {
        double distance(GreenSpace space) => Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          space.lat,
          space.lng,
        );
        best = spaces.reduce((a, b) => distance(a) <= distance(b) ? a : b);
      }
      await _selectPlace(best);
    } catch (e) {
      debugPrint('Default place error: $e');
    }
  }

  Future<void> _selectPlace(GreenSpace place) async {
    final request = ++_placeRequest;
    setState(() {
      _place = place;
      _visit = null;
      _includeVisit = false;
    });
    _notifyChanged();
    try {
      final visit = await ref
          .read(communityRepositoryProvider)
          .latestVisitAt(place.id);
      if (!mounted || request != _placeRequest) return;
      setState(() {
        _visit = visit;
        _includeVisit = visit != null;
      });
      _notifyChanged();
    } catch (_) {
      // Sharing still works without visit stats.
    }
  }

  Future<void> _pickPlace() async {
    final spaces = await ref.read(greenSpacesProvider.future);
    if (!mounted) return;
    final chosen = await showModalBottomSheet<GreenSpace>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final space in spaces)
                ListTile(
                  leading: const Icon(Icons.eco, color: AppColors.mintGreen),
                  title: Text(space.name),
                  subtitle: Text(space.categoryLabel),
                  selected: space.id == _place?.id,
                  onTap: () => Navigator.pop(ctx, space),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) await _selectPlace(chosen);
  }

  String _visitDescription(VisitStats visit) {
    final score = visit.reduction > 0
        ? 'stress score down ${visit.reduction}'
        : visit.reduction < 0
        ? 'stress score up ${-visit.reduction}'
        : 'stress score unchanged';
    return '${formatDuration(visit.minutes * 60.0)} · $score';
  }

  @override
  Widget build(BuildContext context) {
    final place = _place;
    final visit = _visit;
    if (widget.compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ActionChip(
            avatar: const Icon(Icons.location_on_outlined, size: 18),
            label: Text(
              place == null ? 'Choose location' : 'Location: ${place.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: _pickPlace,
          ),
          if (visit != null)
            FilterChip(
              avatar: const Icon(Icons.self_improvement_outlined, size: 18),
              label: const Text('Visit details'),
              selected: _includeVisit,
              onSelected: (value) {
                setState(() => _includeVisit = value);
                _notifyChanged();
              },
              tooltip: _visitDescription(visit),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Place',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickPlace,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.mintGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    place?.name ?? 'Choose a place',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
        if (visit != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _includeVisit,
            onChanged: (value) {
              setState(() => _includeVisit = value);
              _notifyChanged();
            },
            title: const Text('Include my visit'),
            subtitle: Text(_visitDescription(visit)),
          ),
      ],
    );
  }
}
