import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/connectivity_service.dart';

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
