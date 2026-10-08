import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/providers/providers.dart';
import '../../data/datasources/incident_evidence_source.dart';

/// Concrete [IncidentEvidenceSource] backed by the `image_picker` plugin.
class ImagePickerEvidenceSource implements IncidentEvidenceSource {
  ImagePickerEvidenceSource([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<CapturedEvidence?> _fromXFile(XFile? file) async {
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final name = file.name.trim().isEmpty ? 'evidence.jpg' : file.name.trim();
    return CapturedEvidence(
      localPath: file.path,
      filename: name,
      bytes: bytes,
    );
  }

  @override
  Future<CapturedEvidence?> captureFromCamera() async {
    try {
      return await _fromXFile(await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      ));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<CapturedEvidence?> pickFromGallery() async {
    try {
      return await _fromXFile(await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      ));
    } catch (_) {
      return null;
    }
  }
}

/// Feature-local provider (kept inside `features/incidents/`).
final incidentEvidenceSourceProvider = Provider<IncidentEvidenceSource>(
  (_) => ImagePickerEvidenceSource(),
);

final incidentEvidenceRepositoryProvider = Provider<IncidentEvidenceRepository>(
  (ref) => IncidentEvidenceRepository(ref.watch(storageServiceProvider)),
);
