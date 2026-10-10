/// Rules for one UC02-S01 field incident before it is stored.
///
/// The wizard, review screen, and submission use case all ask this class what
/// is still missing so a ranger sees the same list everywhere.
abstract final class FieldIncidentDraft {
  static const int descriptionMaxLength = 160;

  /// Labels the ranger picks from. Persistence still uses the shared category.
  static const List<String> incidentTypeLabels = [
    'Snare',
    'Carcass',
    'Illegal campsite',
    'Suspicious footprints',
    'Other',
  ];

  static List<String> missing({
    required bool hasIncidentType,
    required bool hasPhotograph,
    required bool hasLocation,
    required bool hasCaptureTime,
    required String description,
    required bool hasRanger,
    required bool hasActivePatrol,
  }) {
    final trimmed = description.trim();
    return [
      if (!hasIncidentType) 'incident type',
      if (!hasPhotograph) 'photograph',
      if (!hasLocation) 'GPS location',
      if (!hasCaptureTime) 'GPS capture time',
      if (trimmed.isEmpty) 'description',
      if (trimmed.length > descriptionMaxLength) 'shorter description',
      if (!hasRanger) 'authenticated ranger',
      if (!hasActivePatrol) 'active patrol',
    ];
  }

  static bool isComplete({
    required bool hasIncidentType,
    required bool hasPhotograph,
    required bool hasLocation,
    required bool hasCaptureTime,
    required String description,
    required bool hasRanger,
    required bool hasActivePatrol,
  }) =>
      missing(
        hasIncidentType: hasIncidentType,
        hasPhotograph: hasPhotograph,
        hasLocation: hasLocation,
        hasCaptureTime: hasCaptureTime,
        description: description,
        hasRanger: hasRanger,
        hasActivePatrol: hasActivePatrol,
      ).isEmpty;
}
