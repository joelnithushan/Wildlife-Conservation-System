/// Abstract gateway to Firebase.
/// Concrete implementation uses firebase_core / firestore / storage.
/// All feature repositories depend only on this interface — never on Firebase directly.
abstract class FirebaseService {
  Future<void> initialize();
  bool get isInitialized;
}
