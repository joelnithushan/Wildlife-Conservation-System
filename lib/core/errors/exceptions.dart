/// Lightweight application exceptions shared across modules.
///
/// Kept intentionally small — these are thrown at boundaries (validation,
/// storage, sync, repositories) and mapped to [Failure]s for the UI where
/// needed. See `failures.dart` for the UI-facing result types.
library;

sealed class AppException implements Exception {
  const AppException(this.message);
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Input failed a business/validation rule (e.g. bad coordinates, missing
/// incident evidence, invalid date range).
final class ValidationException extends AppException {
  const ValidationException(super.message);
}

/// A local (Drift/SQLite) read or write failed.
final class LocalStorageException extends AppException {
  const LocalStorageException(super.message);
}

/// Synchronization to the remote backend failed for a record.
final class SyncException extends AppException {
  const SyncException(super.message);
}

/// A repository operation failed for a reason not covered above.
final class RepositoryException extends AppException {
  const RepositoryException(super.message);
}

/// The current user/role is not permitted to perform an action.
final class PermissionException extends AppException {
  const PermissionException(super.message);
}
