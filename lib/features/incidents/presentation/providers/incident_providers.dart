import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/enums/app_enums.dart';
import '../../../../core/errors/exceptions.dart';

import '../../../../core/sync/sync_service.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../../shared/models/incident_report.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/repositories/incident_repository.dart';
import '../../data/datasources/incident_evidence_source.dart';
import '../../data/datasources/incident_local_data_source.dart';
import '../../data/repositories/incident_repository_impl.dart';
import '../../domain/field_incident_draft.dart';
import '../../domain/incident_categories.dart';
import 'evidence_providers.dart';
import '../../domain/usecases/submit_incident_usecase.dart';

// Re-export the shared providers UC02 screens/tests need, so callers can use a
// single import (mirrors the patrol feature's re-export pattern).
export '../../../../shared/providers/providers.dart'
    show
        locationServiceProvider,
        connectivityServiceProvider,
        storageServiceProvider,
        remoteWriterProvider,
        syncServiceProvider;

// ---------------------------------------------------------------------------
// Infrastructure (feature-local providers over shared abstractions)
// ---------------------------------------------------------------------------

final incidentLocalDataSourceProvider = Provider<IncidentLocalDataSource>(
  (ref) => IncidentLocalDataSource(ref.watch(appDatabaseProvider)),
);

final incidentRepositoryProvider = Provider<IncidentRepository>(
  (ref) => IncidentRepositoryImpl(ref.watch(incidentLocalDataSourceProvider)),
);

/// In-progress patrol for the signed-in ranger, read from the patrol store.
/// UC02 only consumes that store; it does not start or complete patrols.
final activePatrolIdProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user.id.isEmpty) return null;
  final db = ref.watch(appDatabaseProvider);
  final rows = await (db.select(db.patrolsTable)
        ..where((t) => t.rangerId.equals(user.id)))
      .get();
  for (final row in rows) {
    if (row.status == PatrolStatus.inProgress.wire) return row.id;
  }
  return null;
});

// ---------------------------------------------------------------------------
// Ranger form (UC02-S01, screens 1–4)
// ---------------------------------------------------------------------------

/// Where the form's photo evidence currently stands.
class IncidentEvidenceState {
  const IncidentEvidenceState(
      {this.localPath, this.evidence, this.omissionReason});

  final String? localPath;
  final CapturedEvidence? evidence;
  final String? omissionReason;

  bool get hasPhoto => localPath != null && localPath!.trim().isNotEmpty;
  bool get hasOmissionReason =>
      omissionReason != null && omissionReason!.trim().isNotEmpty;

  /// The business rule: a photo OR a non-empty omission reason — never both,
  /// never neither.
  bool get isValid => hasPhoto != hasOmissionReason;
}

/// Full draft state for the new-incident wizard. Plain immutable state kept in
/// one controller so back/forward navigation never loses the ranger's input.
class IncidentFormState {
  const IncidentFormState({
    this.category,
    this.evidence = const IncidentEvidenceState(),
    this.latitude,
    this.longitude,
    this.locationSource,
    this.gpsError,
    this.photoError,
    this.isLocating = false,
    this.observedAt,
    this.gpsCapturedAt,
    this.patrolId,
    this.description = '',
  });

  final IncidentReportCategory? category;
  final IncidentEvidenceState evidence;
  final double? latitude;
  final double? longitude;

  /// gps | manual — never fabricated; null until a fix or a manual pick.
  final LocationSource? locationSource;
  final String? gpsError;
  final String? photoError;
  final bool isLocating;

  /// When the ranger says the incident was observed.
  final DateTime? observedAt;

  /// When latitude/longitude were captured. Stored as the report time.
  final DateTime? gpsCapturedAt;

  /// In-progress patrol this report belongs to. Null until one is bound.
  final String? patrolId;
  final String description;

  bool get hasLocation => latitude != null && longitude != null;
  bool get hasDescription => description.trim().isNotEmpty;

  /// Per-step readiness used by the wizard's Next buttons and review screen.
  bool get categoryValid => category != null;
  bool get evidenceValid => evidence.isValid;
  bool get locationValid => hasLocation;
  bool get descriptionValid =>
      hasDescription &&
      description.trim().length <= FieldIncidentDraft.descriptionMaxLength;
  bool get captureTimeValid => gpsCapturedAt != null;
  bool get patrolValid => patrolId != null && patrolId!.trim().isNotEmpty;
  bool get readyToSubmit =>
      categoryValid &&
      evidenceValid &&
      locationValid &&
      captureTimeValid &&
      descriptionValid &&
      patrolValid;

  List<String> missingLabels({required bool hasRanger}) =>
      FieldIncidentDraft.missing(
        hasIncidentType: categoryValid,
        hasPhotograph: evidenceValid,
        hasLocation: locationValid,
        hasCaptureTime: captureTimeValid,
        description: description,
        hasRanger: hasRanger,
        hasActivePatrol: patrolValid,
      );

  IncidentFormState copyWith({
    IncidentReportCategory? category,
    IncidentEvidenceState? evidence,
    double? latitude,
    double? longitude,
    LocationSource? locationSource,
    String? gpsError,
    String? photoError,
    bool clearGpsError = false,
    bool clearPhotoError = false,
    bool? isLocating,
    DateTime? observedAt,
    DateTime? gpsCapturedAt,
    String? patrolId,
    String? description,
  }) =>
      IncidentFormState(
        category: category ?? this.category,
        evidence: evidence ?? this.evidence,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        locationSource: locationSource ?? this.locationSource,
        gpsError: clearGpsError ? null : (gpsError ?? this.gpsError),
        photoError: clearPhotoError ? null : (photoError ?? this.photoError),
        isLocating: isLocating ?? this.isLocating,
        observedAt: observedAt ?? this.observedAt,
        gpsCapturedAt: gpsCapturedAt ?? this.gpsCapturedAt,
        patrolId: patrolId ?? this.patrolId,
        description: description ?? this.description,
      );
}

/// Drives the new-incident wizard (UC02-S01).
class IncidentFormController extends Notifier<IncidentFormState> {
  @override
  IncidentFormState build() => IncidentFormState(observedAt: DateTime.now());

  void selectCategory(IncidentReportCategory category) =>
      state = state.copyWith(category: category);

  /// Keep at most one of photo / omission reason (they are alternatives).
  void setOmissionReason(String reason) => state = state.copyWith(
        evidence: IncidentEvidenceState(
          omissionReason: reason.trim().isEmpty ? null : reason.trim(),
        ),
      );

  void setEvidence(CapturedEvidence evidence) => state = state.copyWith(
        evidence: IncidentEvidenceState(
          localPath: evidence.localPath,
          evidence: evidence,
        ),
        clearPhotoError: true,
      );

  /// E2: capture failed. Type, description, and GPS already entered stay put.
  void setPhotoError(String message) =>
      state = state.copyWith(photoError: message);

  void clearEvidence() => state = state.copyWith(
        evidence: const IncidentEvidenceState(),
        clearPhotoError: true,
      );

  void bindPatrol(String? patrolId) => state = state.copyWith(
        patrolId: (patrolId == null || patrolId.trim().isEmpty)
            ? state.patrolId
            : patrolId.trim(),
      );

  void setObservationTime(DateTime when) =>
      state = state.copyWith(observedAt: when);

  void setDescription(String text) => state = state.copyWith(description: text);

  /// Attempts a GPS fix. Never fabricates coordinates: on any failure it
  /// records a friendly message and leaves manual map entry available.
  Future<void> captureGpsLocation() async {
    state = state.copyWith(isLocating: true, clearGpsError: true);
    final location = ref.read(locationServiceProvider);
    try {
      final pos = await location.getCurrentPosition();
      final capturedAt = DateTime.now();
      state = state.copyWith(
        latitude: pos.latitude,
        longitude: pos.longitude,
        locationSource: LocationSource.gps,
        gpsCapturedAt: capturedAt,
        observedAt: capturedAt,
        isLocating: false,
        clearGpsError: true,
      );
    } on PermissionException catch (e) {
      state = state.copyWith(
        isLocating: false,
        gpsError: e.message.toLowerCase().contains('permanently')
            ? 'Location permission permanently denied. Set the location manually.'
            : 'Location permission not granted. Set the location manually.',
      );
    } catch (_) {
      state = state.copyWith(
        isLocating: false,
        gpsError: 'No GPS fix. Retry or set the location manually.',
      );
    }
  }

  /// Manual fallback from the cached map view.
  void setManualLocation(double latitude, double longitude) {
    final capturedAt = DateTime.now();
    state = state.copyWith(
      latitude: latitude,
      longitude: longitude,
      locationSource: LocationSource.manual,
      gpsCapturedAt: capturedAt,
      observedAt: capturedAt,
      isLocating: false,
      clearGpsError: true,
    );
  }

  /// Clears everything after a successful submission.
  void reset() => state = IncidentFormState(observedAt: DateTime.now());
}

final incidentFormControllerProvider =
    NotifierProvider<IncidentFormController, IncidentFormState>(
  IncidentFormController.new,
);

// ---------------------------------------------------------------------------
// Submission (UC02-S01, screens 5–6)
// ---------------------------------------------------------------------------

enum SubmissionPhase { idle, submitting, savedOffline, synchronized, failed }

/// Outcome of submitting one incident report.
class IncidentSubmissionState {
  const IncidentSubmissionState({
    this.status = SubmissionPhase.idle,
    this.reportId,
    this.report,
    this.message,
  });

  final SubmissionPhase status;
  final String? reportId;
  final IncidentReport? report;
  final String? message;

  /// Human-readable reference, e.g. `IR-a1b2c3d4`.
  String? get reference =>
      reportId == null ? null : 'IR-${reportId!.split('_').last}';
}

class IncidentSubmissionController extends Notifier<IncidentSubmissionState> {
  @override
  IncidentSubmissionState build() => const IncidentSubmissionState();

  Future<bool> submit() async {
    final form = ref.read(incidentFormControllerProvider);
    final user = ref.read(currentUserProvider);

    if (user.id.isEmpty) {
      state = const IncidentSubmissionState(
        status: SubmissionPhase.failed,
        message: 'Sign in as a ranger before submitting an incident.',
      );
      return false;
    }

    String? patrolId = form.patrolId;
    try {
      patrolId = await ref.read(activePatrolIdProvider.future) ?? form.patrolId;
    } catch (_) {
      patrolId = form.patrolId;
    }
    if (patrolId == null || patrolId.trim().isEmpty) {
      state = const IncidentSubmissionState(
        status: SubmissionPhase.failed,
        message: 'An active patrol is required. Start your patrol, then submit.',
      );
      return false;
    }
    if (ref.mounted) {
      ref.read(incidentFormControllerProvider.notifier).bindPatrol(patrolId);
    }

    final ready = ref.read(incidentFormControllerProvider);
    if (!ready.readyToSubmit) {
      final missing = ready.missingLabels(hasRanger: user.id.isNotEmpty);
      state = IncidentSubmissionState(
        status: SubmissionPhase.failed,
        message: missing.isEmpty
            ? 'Missing required details. Review the report and try again.'
            : 'Missing: ${missing.join(', ')}.',
      );
      return false;
    }

    state = const IncidentSubmissionState(status: SubmissionPhase.submitting);

    // Capture all dependencies up-front: after the first await the autoDispose
    // provider may already be disposed (fast navigation), so `ref` must not be
    // touched inside the async tail.
    final repository = ref.read(incidentRepositoryProvider);
    final connectivity = ref.read(connectivityServiceProvider);
    final evidenceRepository = ref.read(incidentEvidenceRepositoryProvider);
    final syncService = ref.read(syncServiceProvider);

    // Stable client-generated ID: a retry reuses the SAME id (no duplicates).
    final reportId = IdGenerator.newId('incident');
    final report = IncidentReport(
      id: reportId,
      rangerId: user.id,
      parkId: user.parkId,
      category: ready.category!.shared,
      description: ready.description.trim(),
      observedAt: ready.gpsCapturedAt ?? ready.observedAt ?? DateTime.now(),
      latitude: ready.latitude!,
      longitude: ready.longitude!,
      locationSource: ready.locationSource!,
      patrolId: patrolId,
      localPhotoPath: ready.evidence.localPath,
      evidenceOmissionReason: ready.evidence.omissionReason,
      submissionStatus: SubmissionStatus.submitted,
      reviewStatus: ReviewStatus.pendingReview,
      syncState: SyncState.pending,
      createdAt: DateTime.now(),
    );

    final useCase = SubmitIncidentUseCase(
      repository: repository,
      connectivity: connectivity,
      evidenceRepository: evidenceRepository,
      syncService: syncService,
    );

    try {
      final synced = await useCase.execute(report, ready.evidence.evidence);
      state = IncidentSubmissionState(
        status: synced ? SubmissionPhase.synchronized : SubmissionPhase.savedOffline,
        reportId: reportId,
        report: report,
        message: synced
            ? null
            : 'Offline – report saved on this device. It will synchronize '
                'automatically when the signal returns.',
      );
      if (ref.mounted) ref.invalidate(pendingIncidentsProvider);
      return true;
    } on LocalStorageException catch (e) {
      state = IncidentSubmissionState(
        status: SubmissionPhase.failed,
        reportId: reportId,
        message: 'Not saved – retry. ${e.message}',
      );
      return false;
    } on ValidationException catch (e) {
      state = IncidentSubmissionState(
        status: SubmissionPhase.failed,
        reportId: reportId,
        message: e.message,
      );
      return false;
    } catch (e) {
      state = IncidentSubmissionState(
        status: SubmissionPhase.failed,
        reportId: reportId,
        message: 'Not saved – retry. $e',
      );
      return false;
    }
  }

  /// Manual "Retry sync now" from the result screen. Idempotent: re-upserts
  /// the same stable ID and never duplicates the incident or the attachment.
  Future<void> retrySync(String reportId) async {
    state = IncidentSubmissionState(
        status: SubmissionPhase.submitting, reportId: reportId);

    final repository = ref.read(incidentRepositoryProvider);
    final connectivity = ref.read(connectivityServiceProvider);
    final syncService = ref.read(syncServiceProvider);

    // Still offline? Keep the report pending — nothing is duplicated.
    if (!await connectivity.isOnline()) {
      IncidentReport? local;
      try {
        local = await repository.getIncident(reportId);
      } catch (_) {
        local = null;
      }
      state = IncidentSubmissionState(
        status: local == null ? SubmissionPhase.failed : SubmissionPhase.savedOffline,
        reportId: reportId,
        report: local,
        message: 'Still offline. The report stays saved on this device and '
            'will synchronize when the signal returns.',
      );
      return;
    }

    SyncSummary summary;
    try {
      summary = await syncService.syncPendingIncidentData();
    } catch (_) {
      summary = const SyncSummary(pushed: 0, failed: 1);
    }
    IncidentReport? report;
    try {
      report = await repository.getIncident(reportId);
    } catch (_) {
      report = null;
    }
    final ok = !summary.hasFailures && report != null;
    state = IncidentSubmissionState(
      status: ok ? SubmissionPhase.synchronized : SubmissionPhase.failed,
      reportId: reportId,
      report: report,
      message: ok
          ? null
          : 'Synchronization failed. The report stays saved on this device '
              'and will retry automatically.',
    );
    if (ref.mounted) ref.invalidate(pendingIncidentsProvider);
  }
}

final incidentSubmissionProvider =
    NotifierProvider.autoDispose<IncidentSubmissionController,
        IncidentSubmissionState>(IncidentSubmissionController.new);

// ---------------------------------------------------------------------------
// Ranger: my pending (offline-saved) incidents
// ---------------------------------------------------------------------------

/// The current ranger's reports that are still awaiting synchronization.
final pendingIncidentsProvider =
    FutureProvider.autoDispose<List<IncidentReport>>((ref) async {
  final user = ref.watch(currentUserProvider);
  return ref
      .watch(incidentLocalDataSourceProvider)
      .getPendingIncidents(rangerId: user.id);
});

/// Every incident stored on this device, including synchronized reports.
final localIncidentsProvider =
    FutureProvider.autoDispose<List<IncidentReport>>((ref) async {
  return ref.watch(incidentLocalDataSourceProvider).getLocalIncidents();
});

// ---------------------------------------------------------------------------
// Park Manager: review queue (UC02-S02) — synchronized reports only
// ---------------------------------------------------------------------------

/// Synchronized reports for the manager's park, filtered by review status.
///
/// ONLY synchronized reports are surfaced (business rule): pending/failed
/// local-only ranger records have not reached the backend, so reviewers must
/// not act on them.
final incidentReviewQueueProvider = FutureProvider.autoDispose
    .family<List<IncidentReport>, ReviewStatus>((ref, filter) async {
  final user = ref.watch(currentUserProvider);
  final all =
      await ref.watch(incidentRepositoryProvider).getIncidentsForReview(user.parkId);
  return all.where((r) => r.reviewStatus == filter).toList();
});

// ---------------------------------------------------------------------------
// Park Manager: single report + save review (screen 8)
// ---------------------------------------------------------------------------

/// A single incident for the reviewer screen.
final selectedIncidentProvider =
    FutureProvider.autoDispose.family<IncidentReport?, String>((ref, id) {
  return ref.watch(incidentRepositoryProvider).getIncident(id);
});

/// Result of a review save attempt.
class ReviewSaveState {
  const ReviewSaveState({this.saving = false, this.saved = false, this.error});

  final bool saving;
  final bool saved;
  final String? error;
}

/// Saves a review decision for one report (family arg = report id). Only
/// authorized reviewers may pass; failures retain the previous status.
class ReviewSaveController extends Notifier<ReviewSaveState> {
  ReviewSaveController(this.reportId);

  final String reportId;

  @override
  ReviewSaveState build() => const ReviewSaveState();

  Future<void> save({
    required ReviewStatus status,
    String? reviewNotes,
  }) async {
    final user = ref.read(currentUserProvider);
    if (user.role != UserRole.parkManager) {
      // Authorization rule: only authorized reviewers may update status.
      state = const ReviewSaveState(
          error: 'You are not authorized to review incident reports.');
      return;
    }
    state = const ReviewSaveState(saving: true);
    try {
      await ref.read(incidentRepositoryProvider).updateReviewStatus(
            id: reportId,
            status: status,
            reviewerId: user.id,
            reviewNotes: reviewNotes,
          );
      state = const ReviewSaveState(saved: true);
    } catch (e) {
      // Failure keeps the previous status; the reviewer can retry.
      state = ReviewSaveState(error: 'Could not save the review. $e');
    }
    ref.invalidate(incidentReviewQueueProvider);
    ref.invalidate(selectedIncidentProvider(reportId));
  }
}

final reviewSaveProvider = NotifierProvider.autoDispose
    .family<ReviewSaveController, ReviewSaveState, String>(
  (reportId) => ReviewSaveController(reportId),
);


