import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';
import '../../core/services/storage_service.dart';

/// Shared, feature-agnostic providers.
///
/// Feature-specific state stays in each feature module. Repository
/// implementations are provided on their feature branches by overriding the
/// interface providers declared here.
///
/// Re-exported for convenience:
export '../session/current_user.dart' show currentUserProvider, CurrentUserNotifier;

/// Connectivity abstraction (backed by connectivity_plus).
final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);

/// Live online/offline status. Defaults to `true` until the first event.
final isOnlineProvider = StreamProvider<bool>(
  (ref) => ref.watch(connectivityServiceProvider).connectionChanges,
);

/// Whether Firebase initialized successfully at startup. Overridden in `main()`
/// with the real result of [bootstrapFirebase]. Defaults to `false` so tests and
/// unconfigured runs use local/in-memory infrastructure.
final firebaseReadyProvider = Provider<bool>((_) => false);

/// File storage. Uses Firebase Storage when Firebase is ready, otherwise a no-op
/// implementation so the app still runs without configuration.
final storageServiceProvider = Provider<StorageService>((ref) {
  return ref.watch(firebaseReadyProvider)
      ? FirebaseStorageService()
      : const UnavailableStorageService();
});
