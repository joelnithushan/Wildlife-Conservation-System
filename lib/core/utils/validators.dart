/// Reusable validators shared by more than one module.
///
/// Each returns a bool; callers throw [ValidationException] where a hard failure
/// is required. Kept deliberately small — feature-specific rules live in their
/// own modules.
abstract final class Validators {
  /// Latitude in [-90, 90] and longitude in [-180, 180], both finite.
  static bool validCoordinates(double latitude, double longitude) {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (!latitude.isFinite || !longitude.isFinite) return false;
    return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180;
  }

  /// Start must be on or before end (inclusive).
  static bool validDateRange(DateTime start, DateTime end) =>
      !start.isAfter(end);

  /// A description with at least one non-whitespace character.
  static bool nonEmptyDescription(String? text) =>
      text != null && text.trim().isNotEmpty;

  /// Business rule for a *submitted* incident: it must carry photographic
  /// evidence (local path or uploaded URL) OR an explicit omission reason.
  /// Drafts are exempt.
  static bool incidentEvidenceValid({
    String? localPhotoPath,
    String? photoUrl,
    String? evidenceOmissionReason,
  }) {
    final hasPhoto = (localPhotoPath != null && localPhotoPath.trim().isNotEmpty) ||
        (photoUrl != null && photoUrl.trim().isNotEmpty);
    final hasReason =
        evidenceOmissionReason != null && evidenceOmissionReason.trim().isNotEmpty;
    return hasPhoto || hasReason;
  }
}
