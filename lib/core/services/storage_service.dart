import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Abstraction over file storage for evidence photos (UC02 later).
///
/// Kept feature-agnostic: features depend on this interface, never on
/// `firebase_storage` directly. Bytes are used (not `dart:io File`) so the same
/// API works on web and mobile.
abstract interface class StorageService {
  /// Uploads incident evidence and returns its download URL.
  /// Path: `incident-evidence/{incidentId}/{filename}`.
  Future<String> uploadIncidentEvidence({
    required String incidentId,
    required String filename,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  });

  /// Deletes a previously uploaded evidence file (if genuinely required).
  Future<void> deleteIncidentEvidence({
    required String incidentId,
    required String filename,
  });
}

/// Firebase Storage implementation. Requires Firebase to be initialized.
class FirebaseStorageService implements StorageService {
  FirebaseStorageService([FirebaseStorage? storage])
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  static const _root = 'incident-evidence';

  Reference _ref(String incidentId, String filename) =>
      _storage.ref().child('$_root/$incidentId/$filename');

  @override
  Future<String> uploadIncidentEvidence({
    required String incidentId,
    required String filename,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _ref(incidentId, filename);
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  @override
  Future<void> deleteIncidentEvidence({
    required String incidentId,
    required String filename,
  }) {
    return _ref(incidentId, filename).delete();
  }
}

/// No-op storage used when Firebase is not configured, so the app runs and code
/// that depends on [StorageService] still compiles/links. Throws only if
/// actually invoked.
class UnavailableStorageService implements StorageService {
  const UnavailableStorageService();

  Never _unavailable() => throw StateError(
      'Firebase Storage is not configured. Run `flutterfire configure` and '
      'enable Storage in the Firebase console.');

  @override
  Future<String> uploadIncidentEvidence({
    required String incidentId,
    required String filename,
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) async =>
      _unavailable();

  @override
  Future<void> deleteIncidentEvidence({
    required String incidentId,
    required String filename,
  }) async =>
      _unavailable();
}
