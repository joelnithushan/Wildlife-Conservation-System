enum SyncStatus { pending, syncing, synchronized, failed }

enum PatrolStatus { assigned, inProgress, completed }

enum AlertStatus { newAlert, acknowledged, responseInProgress, resolved }

enum IncidentCategory {
  poaching,
  animalInjury,
  humanWildlifeConflict,
  illegalLogging,
  other,
}

enum CaptureMode { gps, manual }

enum AlertSeverity { low, medium, high, critical }

enum ResponseStatus { assigned, acknowledged, inProgress, resolved }

enum UserRole { ranger, manager, communityLiaison, analyst }
