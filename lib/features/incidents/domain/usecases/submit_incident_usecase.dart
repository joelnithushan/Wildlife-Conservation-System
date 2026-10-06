import '../../../../core/services/connectivity_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/repositories/incident_repository.dart';
import '../../data/datasources/incident_evidence_source.dart';

/// UseCase for submitting an incident.
/// This cleanly separates the business logic of offline-first saving 
/// and immediate background synchronization from the UI state controllers.
class SubmitIncidentUseCase {
  SubmitIncidentUseCase({
    required this.repository,
    required this.connectivity,
    required this.evidenceRepository,
    required this.syncService,
  });

  final IncidentRepository repository;
  final ConnectivityService connectivity;
  final IncidentEvidenceRepository evidenceRepository;
  final SyncService syncService;

  /// Returns true if fully synchronized, false if saved offline-only.
  /// Throws ValidationException or LocalStorageException if it cannot be saved.
  Future<bool> execute(IncidentReport report, CapturedEvidence? evidence) async {
    // 1) Local save first (offline-first). Only a SUCCESSFUL save may be
    //    reported to the ranger as safe.
    await repository.createIncident(report);

    // 2) Attempt online submission + evidence upload right away.
    try {
      if (!await connectivity.isOnline()) return false;

      // Upload evidence (if any) before/with the record. Idempotent by
      // filename, so an interrupted upload can be retried safely.
      if (evidence != null) {
        await evidenceRepository.uploadEvidence(
          incidentId: report.id,
          evidence: evidence,
        );
      }
      final summary = await syncService.syncPendingIncidentData();
      return !summary.hasFailures;
    } catch (_) {
      return false; // stay pending; the sync engine retries later
    }
  }
}
