/// Shared enumerations for the whole application.
///
/// All persisted status values live here so raw strings are never scattered
/// through the codebase. Serialization uses the stable Dart [Enum.name]
/// (camelCase) as the wire value. Use [parseEnum] / [parseEnumOrNull] to read
/// values back safely.
library;

// ---------------------------------------------------------------------------
// Enum definitions
// ---------------------------------------------------------------------------

enum PatrolStatus { assigned, inProgress, completed }

/// Record-level offline synchronization state (persisted on every syncable row).
enum SyncState { pending, synchronized, failed }

enum CaptureMode { gps, manual }

/// Where an incident's location came from.
enum LocationSource { gps, manual }

enum SubmissionStatus { draft, submitted }

enum ReviewStatus { pendingReview, underReview, verified, rejected }

enum AlertStatus { newAlert, assigned, acknowledged, responseInProgress, resolved }

/// Notification delivery state for a response assignment.
enum DeliveryState { pending, delivered, failed }

/// Staff roles. `admin` is a SUPPORTING role (system administrator) used only for
/// account management — it is NOT one of the four graded business use cases.
/// See AGENTS.md §10/§35.
enum UserRole {
  ranger,
  parkManager,
  communityLiaisonOfficer,
  conservationResearcher,
  admin,
}

/// Biological sex recorded on a staff profile (collected by the admin).
enum Gender { male, female, other }

enum ResponderRole { ranger, communityLiaisonOfficer }

enum AlertSource { collar, communityReport }

enum IncidentCategory {
  snare,
  carcass,
  illegalCampsite,
  suspiciousFootprints,
  other,
}

enum AlertSeverity { low, medium, high, critical }

enum RiskLevel { low, medium, high }

// ---------------------------------------------------------------------------
// Serialization helpers
// ---------------------------------------------------------------------------

/// Stable wire value for any enum (its Dart [Enum.name]).
extension EnumWire on Enum {
  String get wire => name;
}

/// Parse [raw] into one of [values], falling back to [fallback] when the value
/// is null or unrecognized. Safe for reading persisted/remote data.
T parseEnum<T extends Enum>(
  Iterable<T> values,
  Object? raw, {
  required T fallback,
}) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

/// Like [parseEnum] but returns null for null/unknown input instead of a
/// fallback. Use for optional fields.
T? parseEnumOrNull<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw is! String) return null;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return null;
}

// ---------------------------------------------------------------------------
// Domain rules that belong to the enums themselves
// ---------------------------------------------------------------------------

extension PatrolStatusTransitions on PatrolStatus {
  /// Allowed lifecycle: assigned -> inProgress -> completed. No skips, no reversals.
  bool canTransitionTo(PatrolStatus next) {
    return switch (this) {
      PatrolStatus.assigned => next == PatrolStatus.inProgress,
      PatrolStatus.inProgress => next == PatrolStatus.completed,
      PatrolStatus.completed => false,
    };
  }
}

extension UserRoleX on UserRole {
  /// Human-readable label for UI (dashboards, profile, pickers).
  String get displayLabel => switch (this) {
        UserRole.parkManager => 'Park Manager',
        UserRole.ranger => 'Ranger',
        UserRole.communityLiaisonOfficer => 'Community Liaison Officer',
        UserRole.conservationResearcher => 'Conservation Researcher',
        UserRole.admin => 'System Admin',
      };

  /// Short code used when generating usernames (`role_firstname_seq`),
  /// e.g. ranger -> `ranger_kumar_001`. Part of the username data contract.
  String get usernameCode => switch (this) {
        UserRole.parkManager => 'manager',
        UserRole.ranger => 'ranger',
        UserRole.communityLiaisonOfficer => 'clo',
        UserRole.conservationResearcher => 'researcher',
        UserRole.admin => 'admin',
      };

  /// Roles the admin can create from the dashboard. Admin accounts are seeded,
  /// never created through the user-management form.
  static const assignableByAdmin = <UserRole>[
    UserRole.parkManager,
    UserRole.ranger,
    UserRole.communityLiaisonOfficer,
    UserRole.conservationResearcher,
  ];
}

extension GenderX on Gender {
  String get displayLabel => switch (this) {
        Gender.male => 'Male',
        Gender.female => 'Female',
        Gender.other => 'Other',
      };
}

/// Parse a role coming from a Firestore profile. Returns `null` for missing or
/// unsupported values so callers can treat the profile as invalid rather than
/// silently defaulting to a role the account should not have.
UserRole? parseSupportedRole(Object? raw) =>
    parseEnumOrNull(UserRole.values, raw);

extension AlertStatusTransitions on AlertStatus {
  /// Allowed lifecycle:
  /// newAlert -> assigned -> acknowledged -> responseInProgress -> resolved.
  bool canTransitionTo(AlertStatus next) {
    return switch (this) {
      AlertStatus.newAlert => next == AlertStatus.assigned,
      AlertStatus.assigned => next == AlertStatus.acknowledged,
      AlertStatus.acknowledged => next == AlertStatus.responseInProgress,
      AlertStatus.responseInProgress => next == AlertStatus.resolved,
      AlertStatus.resolved => false,
    };
  }
}
