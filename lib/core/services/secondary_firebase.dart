import 'package:firebase_core/firebase_core.dart';

/// Runs [action] against a temporary SECONDARY Firebase app.
///
/// Firebase Auth's `createUserWithEmailAndPassword` signs the *new* user into the
/// app it runs on. To create accounts (or seed the admin) without logging the
/// current admin out, we do it on a throwaway secondary app that reuses the
/// primary app's options. The secondary app is always disposed afterwards.
Future<T> withSecondaryFirebaseApp<T>(
  Future<T> Function(FirebaseApp app) action, {
  String name = 'wg_secondary',
}) async {
  FirebaseApp app;
  try {
    // Reuse a lingering instance (e.g. after a hot restart) if present.
    app = Firebase.app(name);
  } catch (_) {
    app = await Firebase.initializeApp(
      name: name,
      options: Firebase.app().options,
    );
  }
  try {
    return await action(app);
  } finally {
    await app.delete();
  }
}
