import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/providers.dart';

/// Coordinator that automatically triggers synchronization when the device
/// regains connectivity (offline -> online). Includes a guard to prevent
/// concurrent sync jobs.
final autoSyncCoordinatorProvider = Provider<AutoSyncCoordinator>((ref) {
  return AutoSyncCoordinator(ref);
});

class AutoSyncCoordinator {
  AutoSyncCoordinator(this.ref) {
    ref.listen<AsyncValue<bool>>(isOnlineProvider, (previous, next) async {
      final wasOffline = previous?.value == false;
      final isOnline = next.value == true;

      if (wasOffline && isOnline && !_isSyncing) {
        _isSyncing = true;
        try {
          await ref.read(syncServiceProvider).syncAllPendingData();
        } finally {
          _isSyncing = false;
        }
      }
    });
  }

  final Ref ref;
  bool _isSyncing = false;
}
