import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/offline_strip.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../explore/presentation/explore_screen.dart';
import '../../geofence/data/geofence_providers.dart';
import '../../geofence/data/geofence_service.dart';
import '../../weather/data/weather_providers.dart';
import '../../home/data/profile_providers.dart';
import '../../home/presentation/home_screen.dart';
import '../../map/data/map_providers.dart';
import '../../map/domain/green_space.dart';
import '../../map/presentation/map_screen.dart';
import '../../runs/data/run_repository.dart';
import '../../runs/data/run_sync_service.dart';
import '../../visit/data/visit_providers.dart';
import '../../visit/data/visit_repository.dart';
import '../../visit/data/visit_sync_service.dart';

/// Lets other screens (for example Home's "Start Now") switch the main tab:
/// 0 Home, 1 Explore, 2 Map, 3 Dashboard.
final ValueNotifier<int> shellTabIndex = ValueNotifier<int>(0);

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
  StreamSubscription<String>? _tapSub;
  bool _appResumed = true;
  bool _visitOpen = false;
  GreenSpace? _pendingArrival;
  GreenSpace? _pendingExit;

  /// The offline notice is not permanent: it appears when the app opens
  /// without a connection, and each time the connection drops, then hides
  /// itself after [_offlineNoticeDuration] so it never covers the screens.
  bool _showOfflineNotice = false;
  Timer? _offlineNoticeTimer;
  static const _offlineNoticeDuration = Duration(seconds: 4);

  static const _pages = <Widget>[
    HomeScreen(),
    ExploreScreen(),
    MapScreen(),
    DashboardScreen(),
  ];

  // Choices shown when the "+" button is tapped. Quick Run is the hero
  // card on top of the sheet; these fill the grid below it.
  static const _actions = <_CreateAction>[
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
    shellTabIndex.value = 0;
    shellTabIndex.addListener(_onTabRequested);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initGeofence();
      _syncQueuedData(); // anything recorded offline last time
      if (!ref.read(isOnlineProvider)) _showOfflineNoticeForAWhile();
    });
  }

  @override
  void dispose() {
    _offlineNoticeTimer?.cancel();
    shellTabIndex.removeListener(_onTabRequested);
    WidgetsBinding.instance.removeObserver(this);
    _geoSub?.cancel();
    _tapSub?.cancel();
    ref.read(geofenceServiceProvider).stop();
    super.dispose();
  }

  // ---- offline notice ----------------------------------------------------

  /// Shows the offline strip for [_offlineNoticeDuration], then removes it.
  void _showOfflineNoticeForAWhile() {
    _offlineNoticeTimer?.cancel();
    if (!_showOfflineNotice) setState(() => _showOfflineNotice = true);
    _offlineNoticeTimer = Timer(_offlineNoticeDuration, _hideOfflineNotice);
  }

  void _hideOfflineNotice() {
    _offlineNoticeTimer?.cancel();
    _offlineNoticeTimer = null;
    if (_showOfflineNotice && mounted) {
      setState(() => _showOfflineNotice = false);
    }
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

      // Notifications: arrival alerts when the app is minimized.
      final notifications = NotificationService.instance;
      await notifications.init();
      _tapSub ??= notifications.taps.listen(_onNotificationTap);
      await notifications.requestPermission();
      if (!mounted) return;

      final service = ref.read(geofenceServiceProvider);
      _geoSub ??= service.events.listen(_onGeofenceEvent);

      // If a visit is still open, remember its place.
      final active = await ref.read(visitRepositoryProvider).fetchActiveVisit();
      service.setActivePlace(active?.placeId);

      final started = await service.start();
      if (started) ref.invalidate(weatherPositionProvider); // refresh weather
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
    if (ref
        .read(geofenceServiceProvider)
        .isManualNavigationTarget(e.space.id)) {
      return;
    }
    if (e.type == GeofenceEventType.entered) {
      if (_appResumed) {
        _openVisit(e.space);
      } else {
        _pendingArrival = e.space; // opens when the user comes back
        NotificationService.instance.showArrival(e.space);
      }
    } else {
      if (_appResumed) {
        _askToFinish(e.space);
      } else {
        _pendingExit = e.space;
        NotificationService.instance.showExit(e.space);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) return;

    _syncQueuedData();

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

  /// Uploads visits and runs that were recorded offline. Runs when the
  /// connection comes back and whenever the app is opened again.
  Future<void> _syncQueuedData() async {
    final syncedVisits = await ref.read(visitSyncServiceProvider).syncAll();
    final syncedRuns = await ref.read(runSyncServiceProvider).syncAll();
    if ((!syncedVisits && !syncedRuns) || !mounted) return;
    ref.invalidate(profileProvider); // streak may have changed
    ref.invalidate(dashboardProvider);
    ref.invalidate(activeVisitProvider);
    ref.invalidate(greenSpacesProvider); // Quiet Scores may have changed
    ref.invalidate(runHistoryProvider);
  }

  /// Opens the visit flow (before questions, or where the visit left off).
  void _openVisit(GreenSpace space) {
    if (!mounted || _visitOpen) return;
    _visitOpen = true;
    NotificationService.instance.cancelAll();
    context.push<void>('/visit', extra: space).whenComplete(() {
      _visitOpen = false;
      ref.invalidate(activeVisitProvider);
    });
  }

  /// The user tapped an EcoWell notification ("arrival:id" / "exit:id").
  Future<void> _onNotificationTap(String payload) async {
    final parts = payload.split(':');
    if (parts.length != 2) return;
    try {
      final spaces = await ref.read(greenSpacesProvider.future);
      final match = spaces.where((s) => s.id == parts[1]);
      if (match.isNotEmpty) _openVisit(match.first);
    } catch (e) {
      debugPrint('Notification tap error: $e');
    }
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

  /// Another screen asked for a different tab.
  void _onTabRequested() {
    final i = shellTabIndex.value;
    if (!mounted || i == _index) return;
    setState(() {
      _index = i;
      _visited.add(i);
    });
  }

  void _select(int i) {
    setState(() {
      _index = i;
      _visited.add(i);
    });
    shellTabIndex.value = i;
  }

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name is coming soon.')),
    );
  }

  /// Handles a tap on one of the "+" choices.
  void _onAction(_CreateAction a) {
    switch (a.id) {
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

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Start an activity',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _QuickRunCard(
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push('/run');
                },
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 2.0,
                children: [
                  for (final a in _actions)
                    _ActionCard(
                      action: a,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _onAction(a);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Back online: send whatever the user did without a connection.
    // Losing the connection later only earns a short notice, no permanent bar.
    ref.listen<bool>(isOnlineProvider, (previous, next) {
      if (next) {
        _hideOfflineNotice();
        _syncQueuedData();
      } else {
        _showOfflineNoticeForAWhile();
      }
    });

    return Scaffold(
      body: Column(
        children: [
          if (_showOfflineNotice) const OfflineStrip(),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  _visited.contains(i) ? _pages[i] : const SizedBox.shrink(),
              ],
            ),
          ),
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

/// The big "Quick Run" card at the top of the "+" sheet.
class _QuickRunCard extends StatelessWidget {
  const _QuickRunCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryButtonGradient,
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_run,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Run',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Record your walk or run on the map. '
                        'Works offline too.',
                        style: TextStyle(
                          color: AppColors.textOnDarkMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One card of the grid under the Quick Run hero card.
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action, required this.onTap});

  final _CreateAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Icon(action.icon, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      action.subtitle,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
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
