import 'package:firebase_core/firebase_core.dart';

import 'firebase_service.dart';

/// Concrete [FirebaseService] backed by `firebase_core`.
///
/// Initialization is *safe*: if Firebase is not configured on the current
/// platform (no `google-services.json` / `GoogleService-Info.plist` /
/// `firebase_options.dart`), [initialize] catches the error and leaves the app
/// running in offline / in-memory mode instead of crashing.
///
/// Once `flutterfire configure` has generated `lib/firebase_options.dart`, pass
/// its options in via [optionsOverride] from `main.dart`:
///
/// ```dart
/// await initializer.initialize(
///   optionsOverride: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class FirebaseInitializer implements FirebaseService {
  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize({FirebaseOptions? optionsOverride}) async {
    if (_initialized) return;
    try {
      if (optionsOverride != null) {
        await Firebase.initializeApp(options: optionsOverride);
      } else {
        // Uses the native config file on Android/iOS. Throws on web / when
        // unconfigured — handled below.
        await Firebase.initializeApp();
      }
      _initialized = true;
    } catch (_) {
      // Not configured yet — continue offline. Sync falls back to the in-memory
      // writer; local Drift persistence is unaffected.
      _initialized = false;
    }
  }
}

/// Attempts to initialize Firebase and returns whether it succeeded.
/// Call once from `main()` before `runApp`.
Future<bool> bootstrapFirebase({FirebaseOptions? optionsOverride}) async {
  final initializer = FirebaseInitializer();
  await initializer.initialize(optionsOverride: optionsOverride);
  return initializer.isInitialized;
}
