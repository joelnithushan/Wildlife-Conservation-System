import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/repositories/incident_repository.dart';
import '../datasources/incident_local_data_source.dart';

/// Offline-first [IncidentRepository] (UC02).
///
/// Every write persists locally first (Drift) with `syncState = pending`;
/// the shared `SyncService` pushes pending records to the backend later and
/// flips them to `synchronized` only after a successful idempotent upsert.
/// Validation failures throw before anything is written, and a failed local
/// save is surfaced to the caller instead of being silently swallowed.
class IncidentRepositoryImpl implements IncidentRepository {
  IncidentRepositoryImpl(this._local);

  final IncidentLocalDataSource _local;

  @override
  List<IncidentCategory> getCategories() => IncidentCategory.values;

  @override
  Future<IncidentReport> createIncident(IncidentReport draft) async {
    _validateForSubmission(draft);
    final saved = await _local.upsertIncident(draft);
    if (!saved) {
      throw const LocalStorageException(
          'Could not save the incident on this device.');
    }
    return draft;
  }

  @override
  Future<IncidentReport> submitIncident(String id) async {
    final incident = await _requireIncident(id);
    if (!incident.canSubmit) {
      throw const ValidationException(
          'Incident is missing required information.');
    }
    final updated = incident.copyWith(
      submissionStatus: SubmissionStatus.submitted,
      // A submission (or retry) must be eligible for sync again.
      syncState: SyncState.pending,
    );
    final saved = await _local.upsertIncident(updated);
    if (!saved) {
      throw const LocalStorageException(
          'Could not save the incident on this device.');
    }
    return updated;
  }

  @override
  Future<List<IncidentReport>> getPendingIncidents() =>
      _local.getPendingIncidents();

  @override
  Future<List<IncidentReport>> getIncidentsForReview(String parkId) =>
      _local.getSynchronizedIncidents(parkId);

  @override
  Future<IncidentReport?> getIncident(String id) => _local.getIncidentById(id);

  @override
  Future<IncidentReport> updateReviewStatus({
    required String id,
    required ReviewStatus status,
    required String reviewerId,
    String? reviewNotes,
  }) async {
    final incident = await _requireIncident(id);
    final updated = incident.copyWith(
      reviewStatus: status,
      reviewerId: reviewerId,
      reviewNotes: reviewNotes ?? incident.reviewNotes,
      reviewedAt: DateTime.now(),
    );
    final saved = await _local.upsertIncident(updated);
    if (!saved) {
      throw const LocalStorageException(
          'Could not save the review on this device.');
    }
    return updated;
  }

  Future<IncidentReport> _requireIncident(String id) async {
    final incident = await _local.getIncidentById(id);
    if (incident == null) {
      throw RepositoryException('Incident $id not found.');
    }
    return incident;
  }

  void _validateForSubmission(IncidentReport draft) {
    if (!Validators.validCoordinates(draft.latitude, draft.longitude)) {
      throw const ValidationException('A valid location is required.');
    }
    if (!Validators.nonEmptyDescription(draft.description)) {
      throw const ValidationException('A description is required.');
    }
    if (!draft.isEvidenceValid) {
      throw const ValidationException(
          'Add a photo or a reason for missing evidence.');
    }
  }
}
