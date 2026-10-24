import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Answers one question: does the phone currently have a network?
///
/// The answer drives the short offline notice in the app frame and decides
/// when queued visits can be sent to Supabase. Screens do not need it: they
/// try the network call and fall back to the cache when it fails.
class ConnectivityService {
  ConnectivityService([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;
  final _controller = StreamController<bool>.broadcast();

  /// Assumed true until the first check says otherwise, so the app does not
  /// flash the offline notice while starting.
  bool _online = true;

  bool get isOnline => _online;

  /// Emits only when the state actually changes.
  Stream<bool> get changes => _controller.stream;

  /// Starts listening. Safe to call once, from the provider.
  Future<void> start() async {
    await refresh();
    _connectivity.onConnectivityChanged.listen(
      (_) => refresh(),
      onError: (Object e) => debugPrint('Connectivity error: $e'),
    );
  }

  /// Re-checks the network now. Returns the new state.
  Future<bool> refresh() async {
    final online = await _hasNetwork();
    if (online != _online) {
      _online = online;
      _controller.add(online);
    }
    return online;
  }

  Future<bool> _hasNetwork() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return _online;
    }
  }

  void dispose() {
    _controller.close();
  }
}

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final service = ConnectivityService()..start();
  ref.onDispose(service.dispose);
  return service;
});

/// True while the phone has a network. Rebuilds screens that watch it.
final isOnlineProvider = NotifierProvider<IsOnlineNotifier, bool>(
  IsOnlineNotifier.new,
);

class IsOnlineNotifier extends Notifier<bool> {
  @override
  bool build() {
    final service = ref.watch(connectivityServiceProvider);
    final sub = service.changes.listen((online) => state = online);
    ref.onDispose(sub.cancel);
    return service.isOnline;
  }
}
