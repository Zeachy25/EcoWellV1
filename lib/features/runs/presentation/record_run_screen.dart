import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/offline/connectivity_service.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/format.dart';
import '../data/run_recorder.dart';
import '../data/run_repository.dart';
import '../data/run_sync_service.dart';
import '../domain/run_models.dart';
import 'run_summary_view.dart';

/// Quick Run: the Strava-style recorder. Pick walk or run, press Start,
/// and the map draws the path while the timer, distance and pace tick up.
/// Works offline; finished runs sync when the network returns.
class RecordRunScreen extends ConsumerStatefulWidget {
  const RecordRunScreen({super.key});

  @override
  ConsumerState<RecordRunScreen> createState() => _RecordRunScreenState();
}

class _RecordRunScreenState extends ConsumerState<RecordRunScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _map;
  LatLng? _lastFollowed;

  RunActivityType _type = RunActivityType.walk;

  /// Set once Stop was pressed; shown as the save/discard summary.
  RunRecord? _summary;

  bool _starting = false;
  bool _saving = false;

  bool _recoveryChecked = false;
  Completer<void>? _returnedFromSettings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _moveToUser();
      _checkUnfinishedRun();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _map?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final completer = _returnedFromSettings;
    if (completer != null && !completer.isCompleted) {
      // Give the system a beat to settle the permission change.
      Timer(const Duration(seconds: 1), completer.complete);
    }
  }

  // ---- interrupted-run recovery ------------------------------------------

  Future<void> _checkUnfinishedRun() async {
    if (_recoveryChecked) return;
    _recoveryChecked = true;

    final recorder = ref.read(runRecorderProvider);
    if (recorder.state.value.isTracking) return;

    final repo = ref.read(runRepositoryProvider);
    final active = await repo.activeRun();
    if (active == null || !mounted) return;

    // A leftover blip is not a run worth recovering.
    if (active.durationSeconds < 10 && active.path.length < 2) {
      await repo.discardCheckpoint(active.id);
      return;
    }

    final resumeRun = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Unfinished Quick Run'),
        content: Text(
          'Your ${active.type.label.toLowerCase()} from '
          '${formatShortDate(active.startedAt)} at '
          '${formatTime(active.startedAt)} was interrupted. '
          'Continue it or throw it away?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (resumeRun == true) {
      await recorder.resume(active);
    } else {
      await repo.discardCheckpoint(active.id);
    }
  }

  // ---- start / stop -------------------------------------------------------

  Future<void> _start() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      if (!await LocationService.ensurePermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Location is needed to record your run. '
            'Turn it on in Settings and try again.',
          ),
        ));
        return;
      }
      await _ensureBackgroundTracking();
      if (!mounted) return;
      final started = await ref.read(runRecorderProvider).start(_type);
      if (!started && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not start recording. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// Best effort: ask for "allow all the time" so the run keeps going with
  /// the screen off. The recording starts either way - EcoWell's running
  /// notification keeps tracking while the app is minimized even without it.
  Future<void> _ensureBackgroundTracking() async {
    if (await LocationService.hasBackgroundPermission()) return;
    if (!mounted) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_outline),
        title: const Text('Keep recording in your pocket?'),
        content: const Text(
          'Choose "Allow all the time" so Quick Run keeps tracking with '
          'your screen off. Recording still works with just '
          '"While using the app", just less reliably when closed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (proceed != true || !mounted) return;

    // Android 10 answers with the system dialog; 11+ only accepts a trip
    // through the app settings screen.
    final permission = await Geolocator.requestPermission();
    if (!mounted || permission == LocationPermission.always) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    final openSettings = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One more step'),
        content: const Text(
          'On the next screen, choose "Allow all the time" for EcoWell, '
          'then come back to start your run.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
    if (openSettings != true || !mounted) return;

    final returned = _returnedFromSettings = Completer<void>();
    await Geolocator.openAppSettings();
    await returned.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {},
    );
  }

  void _stop() {
    final record = ref.read(runRecorderProvider).finish();
    setState(() => _summary = record);
  }

  Future<void> _save() async {
    final record = _summary;
    if (record == null || _saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(runRepositoryProvider);
      final uid = repo.currentUserId;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please sign in again to save your run.'),
          ));
        }
        return;
      }
      await repo.save(record.copyWith(userId: uid));
      ref.invalidate(runHistoryProvider);
      ref.read(runRecorderProvider).reset();

      // Upload straight away when online; queued rows are retried by
      // MainShell whenever the network comes back.
      final synced = await ref.read(runSyncServiceProvider).syncAll();
      if (synced) ref.invalidate(runHistoryProvider);

      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _discardSummary() async {
    await ref.read(runRecorderProvider).discard();
    if (mounted) setState(() => _summary = null);
  }

  // ---- leaving while recording / unsaved ----------------------------------

  Future<void> _confirmLeave(bool tracking) async {
    final recorder = ref.read(runRecorderProvider);
    if (tracking) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Quick Run is still recording'),
          content: const Text(
            'Keep it going and come back to this screen, or stop and '
            'throw the run away?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Stop & discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep recording'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        await recorder.discard();
        if (mounted) context.pop();
      }
      return;
    }

    if (_summary != null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('This run is not saved'),
          content: const Text(
            'Save it before leaving, or throw it away.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Discard run'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Stay'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        await recorder.discard();
        if (mounted) context.pop();
      }
    }
  }

  // ---- map -----------------------------------------------------------------

  Future<void> _moveToUser() async {
    final pos = await LocationService.positionIfPermitted();
    if (pos == null || _map == null) return;
    final target = LatLng(pos.latitude, pos.longitude);
    _lastFollowed = target;
    _map?.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(target: target, zoom: 16),
    ));
  }

  void _followCamera(RunState state) {
    final target = state.lastPosition;
    if (target == null || _map == null) return;
    if (state.phase != RunPhase.recording && state.phase != RunPhase.paused) {
      return;
    }
    if (target == _lastFollowed) return;
    _lastFollowed = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _map?.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 17),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorder = ref.watch(runRecorderProvider);

    return ListenableBuilder(
      listenable: recorder.state,
      builder: (context, _) {
        final state = recorder.state.value;
        _followCamera(state);

        final tracking = state.isTracking;
        final canPop = !tracking && _summary == null;

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _confirmLeave(tracking);
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Quick Run'),
              actions: [
                IconButton(
                  tooltip: 'Run history',
                  icon: const Icon(Icons.history),
                  onPressed: () => context.push('/runs'),
                ),
              ],
            ),
            body: _summary != null
                ? _SummaryPane(
                    record: _summary!,
                    saving: _saving,
                    onSave: _save,
                    onDiscard: _discardSummary,
                  )
                : Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: const CameraPosition(
                          target: LatLng(14.5995, 120.9842),
                          zoom: 16,
                        ),
                        polylines: {
                          if (state.path.length > 1)
                            Polyline(
                              polylineId: const PolylineId('run'),
                              points: [
                                for (final p in state.path) p.latLng,
                              ],
                              width: 6,
                              color: AppColors.primaryGreen,
                              jointType: JointType.round,
                              startCap: Cap.roundCap,
                              endCap: Cap.roundCap,
                            ),
                        },
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) {
                          _map = c;
                          _moveToUser();
                        },
                      ),
                      if (!ref.watch(isOnlineProvider))
                        const Positioned(
                          top: 12,
                          left: 16,
                          right: 16,
                          child: _OfflineHint(),
                        ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: state.phase == RunPhase.recording ||
                                state.phase == RunPhase.paused
                            ? _TrackingPane(
                                state: state,
                                onPauseResume: () {
                                  state.phase == RunPhase.recording
                                      ? recorder.pause()
                                      : recorder.resumePaused();
                                },
                                onStop: _stop,
                              )
                            : _StartPane(
                                type: _type,
                                starting: _starting,
                                onTypeChanged: (t) =>
                                    setState(() => _type = t),
                                onStart: _start,
                              ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom panels
// ---------------------------------------------------------------------------

/// Walk / Run picker + the big Start button (idle phase).
class _StartPane extends StatelessWidget {
  const _StartPane({
    required this.type,
    required this.starting,
    required this.onTypeChanged,
    required this.onStart,
  });

  final RunActivityType type;
  final bool starting;
  final ValueChanged<RunActivityType> onTypeChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, spreadRadius: -2),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SegmentedButton<RunActivityType>(
              segments: [
                ButtonSegment(
                  value: RunActivityType.walk,
                  icon: const Icon(Icons.directions_walk),
                  label: const Text('Walk'),
                ),
                ButtonSegment(
                  value: RunActivityType.run,
                  icon: const Icon(Icons.directions_run),
                  label: const Text('Run'),
                ),
              ],
              selected: {type},
              onSelectionChanged: (s) => onTypeChanged(s.first),
            ),
            const SizedBox(height: 10),
            Text(
              'Records your route on the map. Works offline too.',
              style: textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                ),
                onPressed: starting ? null : onStart,
                icon: starting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Live stats + Pause / Stop while a run is going.
class _TrackingPane extends StatelessWidget {
  const _TrackingPane({
    required this.state,
    required this.onPauseResume,
    required this.onStop,
  });

  final RunState state;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final paused = state.phase == RunPhase.paused;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 12, spreadRadius: -2),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (paused) ...[
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pause_circle_outline,
                      color: AppColors.streakOrange, size: 20),
                  SizedBox(width: 6),
                  Text('Paused',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.streakOrange)),
                ],
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                _LiveStat(
                  label: 'Time',
                  value: formatTimer(state.elapsedSeconds),
                  textTheme: textTheme,
                ),
                _LiveStat(
                  label: 'Distance',
                  value: formatDistance(state.distanceMeters),
                  textTheme: textTheme,
                ),
                _LiveStat(
                  label: 'Pace',
                  value: state.avgPaceSecondsPerKm == null
                      ? '-'
                      : '${formatPace(state.avgPaceSecondsPerKm)} /km',
                  textTheme: textTheme,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: onPauseResume,
                    icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                    label: Text(paused ? 'Resume' : 'Pause'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: AppColors.streakOrange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: onStop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveStat extends StatelessWidget {
  const _LiveStat({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(label, style: textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Map snapshot + stats of the stopped run, with Save / Discard.
class _SummaryPane extends StatelessWidget {
  const _SummaryPane({
    required this.record,
    required this.saving,
    required this.onSave,
    required this.onDiscard,
  });

  final RunRecord record;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Nice ${record.type.label.toLowerCase()}!',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Check the route and stats, then save it. It is kept on this '
          'phone either way, so saving works offline too.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        RunSummaryView(record: record),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
            ),
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('Save & finish'),
          ),
        ),
        TextButton(
          onPressed: saving ? null : onDiscard,
          child: const Text('Discard run'),
        ),
      ],
    );
  }
}

class _OfflineHint extends StatelessWidget {
  const _OfflineHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.forestDark.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Flexible(
            child: Text(
              'Offline \u2014 the run still records; the map may look blank.',
              style: TextStyle(color: Colors.white, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
