import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../activities/data/activity_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../geofence/data/geofence_providers.dart';
import '../../geofence/data/geofence_service.dart';
import '../../home/data/profile_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../../map/domain/green_space.dart';
import '../../map/presentation/map_screen.dart';
import '../../visit/data/visit_providers.dart';
import '../../visit/data/visit_repository.dart';

class _CreateAction {
  const _CreateAction(this.id, this.icon, this.title, this.subtitle);
  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
}

/// The main app frame: 4 tabs + a central "+" button.
/// Tabs: Home, Explore, (+), Map, Dashboard.
///
/// It also starts the geofence watcher. When the user ENTERS a green space,
/// the check-in (before questions) opens automatically. If the app is
/// minimized at that moment, it opens when the user returns to the app.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _index = 0;
  final Set<int> _visited = {0};

  StreamSubscription<GeofenceEvent>? _geoSub;
  bool _appResumed = true;
  bool _visitOpen = false;
  GreenSpace? _pendingArrival;
  GreenSpace? _pendingExit;

  static const _pages = <Widget>[
    HomeScreen(),
    ExploreScreen(),
    MapScreen(),
    DashboardScreen(),
  ];

  // Choices shown when the "+" button is tapped.
  static const _actions = <_CreateAction>[
    _CreateAction('quick', Icons.directions_run, 'Quick Run',
        'A 2-minute reset: slow breaths, then a quick look around'),
    _CreateAction('breathing', Icons.air, 'Breathing Exercise',
        'Slow your breathing with an animated guide'),
    _CreateAction('grounding', Icons.spa, 'Grounding Exercise',
        'Come back to the present, step by step'),
    _CreateAction('share', Icons.photo_camera, 'Share a Moment',
        'Post a photo to the community'),
    _CreateAction('coach', Icons.chat_bubble_outline, 'Talk to AI Coach',
        'Get support and ideas'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initGeofence());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _geoSub?.cancel();
    ref.read(geofenceServiceProvider).stop();
    super.dispose();
  }

  // ---- geofence ----------------------------------------------------------

  Future<void> _initGeofence() async {
    try {
      // Only after the profile is complete (birthdate + privacy consent).
      final profile = await ref.read(profileProvider.future);
      if (!mounted) return;
      if (profile['birthdate'] == null || profile['consented_at'] == null) {
        return;
      }

      await _showLocationRationaleOnce();
      if (!mounted) return;

      final service = ref.read(geofenceServiceProvider);
      _geoSub ??= service.events.listen(_onGeofenceEvent);

      // If a visit is still open, remember its place.
      final active = await ref.read(visitRepositoryProvider).fetchActiveVisit();
      service.setActivePlace(active?.placeId);

      final started = await service.start();
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Location is off or not allowed. Turn it on so EcoWell can '
            'start your check-in when you arrive.',
          ),
        ));
      }
    } catch (e) {
      debugPrint('Geofence init error: $e');
    }
  }

  Future<void> _showLocationRationaleOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('location_rationale_seen') ?? false) return;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: const Text('Location and check-ins'),
        content: const Text(
          'EcoWell uses your location to notice when you arrive at a green '
          'space so it can start your check-in, and to show the map and '
          'directions. While it is watching, a small notification stays on '
          'your screen. We do not keep a continuous trail of where you go.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    await prefs.setBool('location_rationale_seen', true);
  }

  void _onGeofenceEvent(GeofenceEvent e) {
    if (e.type == GeofenceEventType.entered) {
      if (_appResumed) {
        _openVisit(e.space);
      } else {
        _pendingArrival = e.space; // opens when the user comes back
      }
    } else {
      if (_appResumed) {
        _askToFinish(e.space);
      } else {
        _pendingExit = e.space;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) return;

    final arrival = _pendingArrival;
    final exit = _pendingExit;
    _pendingArrival = null;
    _pendingExit = null;
    if (arrival != null) {
      _openVisit(arrival);
    } else if (exit != null) {
      _askToFinish(exit);
    }
  }

  /// Opens the visit flow (before questions, or where the visit left off).
  void _openVisit(GreenSpace space) {
    if (!mounted || _visitOpen) return;
    _visitOpen = true;
    context.push<void>('/visit', extra: space).whenComplete(() {
      _visitOpen = false;
      ref.invalidate(activeVisitProvider);
    });
  }

  Future<void> _askToFinish(GreenSpace space) async {
    if (!mounted || _visitOpen) return;
    final finish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Leaving ${space.name}?'),
        content: const Text(
          'It looks like you have left. Finish your visit and tell us how '
          'you feel now?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finish visit'),
          ),
        ],
      ),
    );
    if (finish == true) _openVisit(space);
  }

  // ---- navigation bar ------------------------------------------------------

  void _select(int i) => setState(() {
        _index = i;
        _visited.add(i);
      });

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name is coming soon.')),
    );
  }

  /// Handles a tap on one of the "+" choices.
  void _onAction(_CreateAction a) {
    switch (a.id) {
      case 'quick':
        _runQuickReset();
        break;
      case 'breathing':
        context.push('/activities/breathing');
        break;
      case 'grounding':
        context.push('/activities/grounding');
        break;
      default:
        _comingSoon(a.title);
    }
  }

  Future<void> _runQuickReset() async {
    try {
      final list =
          await ref.read(activityRepositoryProvider).fetchByType('quick_run');
      if (!mounted) return;
      if (list.isEmpty) {
        _comingSoon('Quick Run');
        return;
      }
      context.push('/activity', extra: list.first);
    } catch (e) {
      debugPrint('Quick run error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not load Quick Run. Please try again.'),
      ));
    }
  }

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final a in _actions)
              ListTile(
                leading: Icon(a.icon),
                title: Text(a.title),
                subtitle: Text(a.subtitle),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _onAction(a);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _pages.length; i++)
            _visited.contains(i) ? _pages[i] : const SizedBox.shrink(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateSheet,
        shape: const CircleBorder(),
        tooltip: 'Start an activity',
        child: const Icon(Icons.add, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              selected: _index == 0,
              onTap: () => _select(0),
            ),
            _NavItem(
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore,
              label: 'Explore',
              selected: _index == 1,
              onTap: () => _select(1),
            ),
            const Expanded(child: SizedBox()), // space under the + button
            _NavItem(
              icon: Icons.map_outlined,
              selectedIcon: Icons.map,
              label: 'Map',
              selected: _index == 2,
              onTap: () => _select(2),
            ),
            _NavItem(
              icon: Icons.insights_outlined,
              selectedIcon: Icons.insights,
              label: 'Dashboard',
              selected: _index == 3,
              onTap: () => _select(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
