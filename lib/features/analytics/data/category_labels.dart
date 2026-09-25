import '../../../core/enums/app_enums.dart';

/// Labels for the shared UC02 [IncidentCategory] values.
String incidentCategoryLabel(IncidentCategory category) => switch (category) {
      IncidentCategory.poaching => 'Poaching',
      IncidentCategory.animalInjury => 'Animal injury',
      IncidentCategory.humanWildlifeConflict => 'Human-wildlife conflict',
      IncidentCategory.illegalLogging => 'Illegal logging',
      IncidentCategory.other => 'Other',
    };

String userRoleLabel(UserRole role) => switch (role) {
      UserRole.ranger => 'Ranger',
      UserRole.parkManager => 'Park Manager',
      UserRole.communityLiaisonOfficer => 'Community Liaison Officer',
      UserRole.conservationResearcher => 'Conservation Researcher',
    };
