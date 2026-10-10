import '../../../core/enums/app_enums.dart';

/// Labels for the shared UC02 [IncidentCategory] values.
String incidentCategoryLabel(IncidentCategory category) => switch (category) {
      IncidentCategory.snare => 'Snare',
      IncidentCategory.carcass => 'Carcass',
      IncidentCategory.illegalCampsite => 'Illegal campsite',
      IncidentCategory.suspiciousFootprints => 'Suspicious footprints',
      IncidentCategory.other => 'Other',
    };

String userRoleLabel(UserRole role) => role.displayLabel;
