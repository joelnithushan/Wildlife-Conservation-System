import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/firebase_bootstrap.dart';
import 'shared/providers/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Safe Firebase startup: uses the native config (google-services.json /
  // GoogleService-Info.plist) on mobile. If Firebase is not configured yet, this
  // returns false and the app runs offline-first with local Drift + an in-memory
  // sync writer — nothing crashes.
  //
  // After `flutterfire configure` generates lib/firebase_options.dart, pass its
  // options explicitly for web support:
  //   final firebaseReady = await bootstrapFirebase(
  //     optionsOverride: DefaultFirebaseOptions.currentPlatform,
  //   );
  final firebaseReady = await bootstrapFirebase();

  runApp(
    ProviderScope(
      overrides: [
        firebaseReadyProvider.overrideWithValue(firebaseReady),
      ],
      child: const WildlifeApp(),
    ),
  );
}
