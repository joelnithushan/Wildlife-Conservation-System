import 'dart:typed_data';

import '../../../../core/services/storage_service.dart';

/// A piece of photo evidence captured on the device.
///
/// [localPath] is the on-device file path kept for offline use; [bytes] is the
/// in-memory copy used for the later upload. [filename] is a stable client-side
/// name so a retried upload overwrites the same object.
class CapturedEvidence {
  const CapturedEvidence({
    required this.localPath,
    required this.filename,
    required this.bytes,
  });

  final String localPath;
  final String filename;
  final Uint8List bytes;
}

/// Feature-level seam over `image_picker` so widgets and controllers don't
/// touch the plugin directly (testable: fakes are trivial).
abstract interface class IncidentEvidenceSource {
  /// Opens the camera and returns the captured photo, or null when the user
  /// cancelled. Never fabricates a path.
  Future<CapturedEvidence?> captureFromCamera();

  /// Opens the gallery picker, or null when cancelled.
  Future<CapturedEvidence?> pickFromGallery();
}

/// Result of uploading evidence for an incident.
class EvidenceUploadResult {
  const EvidenceUploadResult({required this.url, this.skipped = false});

  final String url;

  /// True when there was nothing to upload (no local photo) — not an error.
  final bool skipped;
}

/// Prepares and uploads photo evidence through the shared [StorageService].
class IncidentEvidenceRepository {
  IncidentEvidenceRepository(this._storage);

  final StorageService _storage;

  /// Uploads the local photo for [incidentId]. Idempotent by filename, so
  /// retrying after an interrupted upload overwrites the same object.
  Future<EvidenceUploadResult> uploadEvidence({
    required String incidentId,
    CapturedEvidence? evidence,
  }) async {
    if (evidence == null) {
      return const EvidenceUploadResult(url: '', skipped: true);
    }
    final url = await _storage.uploadIncidentEvidence(
      incidentId: incidentId,
      filename: evidence.filename,
      bytes: evidence.bytes,
    );
    return EvidenceUploadResult(url: url);
  }
}
