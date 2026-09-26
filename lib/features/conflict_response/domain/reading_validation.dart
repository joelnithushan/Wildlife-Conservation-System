import '../../../shared/models/location_reading.dart';
import 'conflict_config.dart';

/// Why a reading was rejected before any alert logic runs. [none] means valid.
enum ReadingRejection {
  none,
  invalidId,
  invalidCoordinates,
  invalidTimes,
  stale,
  duplicate,
}

extension ReadingRejectionMessage on ReadingRejection {
  String get message => switch (this) {
        ReadingRejection.none => 'Valid reading.',
        ReadingRejection.invalidId => 'Reading has no stable ID.',
        ReadingRejection.invalidCoordinates =>
          'Reading has invalid coordinates.',
        ReadingRejection.invalidTimes =>
          'Reading has invalid observed/received times.',
        ReadingRejection.stale => 'Reading is too old to act on.',
        ReadingRejection.duplicate => 'Reading has already been processed.',
      };
}

/// Pure, deterministic validation for an incoming [LocationReading].
///
/// Kept isolated from UI, Firebase and the repository so it is trivially
/// testable. Duplicate detection is caller-supplied ([seenReadingIds]) so this
/// function stays free of any stored state.
abstract final class ReadingValidator {
  static bool areCoordinatesValid(double latitude, double longitude) {
    if (latitude.isNaN || longitude.isNaN) return false;
    if (latitude.isInfinite || longitude.isInfinite) return false;
    if (latitude < -90 || latitude > 90) return false;
    if (longitude < -180 || longitude > 180) return false;
    return true;
  }

  static ReadingRejection validate(
    LocationReading reading, {
    required DateTime now,
    required Set<String> seenReadingIds,
    ConflictConfig config = ConflictConfig.defaults,
  }) {
    if (reading.id.trim().isEmpty) return ReadingRejection.invalidId;
    if (reading.animalId.trim().isEmpty) return ReadingRejection.invalidId;
    if (seenReadingIds.contains(reading.id)) return ReadingRejection.duplicate;
    if (!areCoordinatesValid(reading.latitude, reading.longitude)) {
      return ReadingRejection.invalidCoordinates;
    }
    // Observed cannot be in the future relative to received; received cannot be
    // before observed.
    if (reading.receivedAt.isBefore(reading.observedAt)) {
      return ReadingRejection.invalidTimes;
    }
    if (now.difference(reading.observedAt) > config.readingFreshness) {
      return ReadingRejection.stale;
    }
    return ReadingRejection.none;
  }
}
