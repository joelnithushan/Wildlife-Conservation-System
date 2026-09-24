import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums/app_enums.dart';
import '../../../core/errors/exceptions.dart';
import '../../../shared/models/patrol_position.dart';
import '../presentation/providers/patrol_providers.dart';

/// UI-facing state for an in-progress patrol's live tracking.
class PatrolTrackingState {
  const PatrolTrackingState({
    this.isTracking = false,
    this.gpsError,
    this.lastCaptureMode,
    this.isSyncing = false,
    this.syncMessage,
  });

  final bool isTracking;
  final String? gpsError;
  final CaptureMode? lastCaptureMode;
  final bool isSyncing;
  final String? syncMessage;

  bool get gpsUnavailable => gpsError != null;

  PatrolTrackingState copyWith({
    bool? isTracking,
    String? gpsError,
    bool clearGpsError = false,
    CaptureMode? lastCaptureMode,
    bool? isSyncing,
    String? syncMessage,
  }) =>
      PatrolTrackingState(
        isTracking: isTracking ?? this.isTracking,
        gpsError: clearGpsError ? null : (gpsError ?? this.gpsError),
        lastCaptureMode: lastCaptureMode ?? this.lastCaptureMode,
        isSyncing: isSyncing ?? this.isSyncing,
        syncMessage: syncMessage ?? this.syncMessage,
      );
}

/// Drives live GPS/manual position capture for the active patrol.
///
/// A ranger runs one patrol at a time, so this is a single controller attached
/// to the current patrol via [attach]. Business logic lives here (not in the
/// widget): it saves each position locally first, then refreshes derived
/// providers. It never fabricates a GPS fix — if GPS is unavailable it records
/// the error and leaves manual entry available.
class PatrolTrackingController extends Notifier<PatrolTrackingState> {
  StreamSubscription<({double latitude, double longitude})>? _sub;
  String? _patrolId;

  @override
  PatrolTrackingState build() {
    ref.onDispose(() => _sub?.cancel());
    return const PatrolTrackingState();
  }

  /// Bind the controller to a patrol before capturing positions.
  void attach(String patrolId) {
    _patrolId = patrolId;
  }

  /// Begin streaming GPS positions. Safe to call once when the screen opens.
  Future<void> beginTracking() async {
    final location = ref.read(locationServiceProvider);
    try {
      final granted = await location.requestPermission();
      if (!granted) {
        state = state.copyWith(
            gpsError: 'Location permission not granted. Use manual waypoint.');
        return;
      }
      state = state.copyWith(isTracking: true, clearGpsError: true);
      _sub?.cancel();
      _sub = location.positionStream().listen(
        (reading) =>
            _savePosition(reading.latitude, reading.longitude, CaptureMode.gps),
        onError: (_) => state = state.copyWith(
            gpsError: 'No GPS fix. You can mark the location manually.'),
      );
    } on PermissionException catch (e) {
      state = state.copyWith(gpsError: e.message);
    } catch (_) {
      state = state.copyWith(
          gpsError: 'No GPS fix. You can mark the location manually.');
    }
  }

  /// Capture a single GPS position on demand.
  Future<void> captureGpsOnce() async {
    final location = ref.read(locationServiceProvider);
    try {
      final pos = await location.getCurrentPosition();
      await _savePosition(pos.latitude, pos.longitude, CaptureMode.gps);
      state = state.copyWith(clearGpsError: true);
    } on PermissionException catch (e) {
      state = state.copyWith(gpsError: e.message);
    } catch (_) {
      state = state.copyWith(
          gpsError: 'No GPS fix. You can mark the location manually.');
    }
  }

  /// Save a manually-placed waypoint (same model, captureMode = manual).
  Future<void> addManualWaypoint(double latitude, double longitude) async {
    await _savePosition(latitude, longitude, CaptureMode.manual);
  }

  Future<void> _savePosition(
      double latitude, double longitude, CaptureMode mode) async {
    final patrolId = _patrolId;
    if (patrolId == null) {
      throw const RepositoryException('Tracking not attached to a patrol.');
    }
    final position = PatrolPosition.create(
      patrolId: patrolId,
      latitude: latitude,
      longitude: longitude,
      timestamp: DateTime.now(),
      captureMode: mode,
    );
    await ref.read(patrolRepositoryProvider).savePosition(position);
    state = state.copyWith(lastCaptureMode: mode);
    ref.invalidate(patrolPositionsProvider(patrolId));
    ref.invalidate(pendingRecordCountProvider);
  }

  /// Push pending records to the backend when connectivity allows.
  Future<void> runSync() async {
    state = state.copyWith(isSyncing: true, syncMessage: 'Synchronizing…');
    try {
      final summary = await ref.read(syncServiceProvider).syncAllPendingData();
      state = state.copyWith(
        isSyncing: false,
        syncMessage: summary.hasFailures
            ? 'Sync incomplete: ${summary.failed} failed, will retry.'
            : 'Synchronized ${summary.pushed} record(s).',
      );
    } catch (_) {
      state = state.copyWith(
          isSyncing: false, syncMessage: 'Sync failed. Data kept on device.');
    } finally {
      ref.invalidate(pendingRecordCountProvider);
      if (_patrolId != null) {
        ref.invalidate(patrolPositionsProvider(_patrolId!));
      }
    }
  }
}

final patrolTrackingControllerProvider =
    NotifierProvider<PatrolTrackingController, PatrolTrackingState>(
  PatrolTrackingController.new,
);
