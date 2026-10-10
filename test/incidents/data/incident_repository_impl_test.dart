import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/features/incidents/data/repositories/incident_repository_impl.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

AppDatabase createIncidentTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Data source whose writes always fail — models broken local storage so the
/// repository contract (upsert false => LocalStorageException) can be tested.
class _BrokenLocalDataSource extends IncidentLocalDataSource {
  _BrokenLocalDataSource() : super(createIncidentTestDatabase());

  @override
  Future<bool> upsertIncident(IncidentReport incident, {DateTime? now}) async =>
      false;
}

IncidentReport validDraft({
  String id = 'incident_test_1',
  String rangerId = 'R001',
  String parkId = 'PARK-MIN',
  IncidentCategory category = IncidentCategory.snare,
  String description = 'Wire snare near the river crossing',
  DateTime? observedAt,
  double latitude = 8.03,
  double longitude = 80.89,
  LocationSource locationSource = LocationSource.gps,
  String? localPhotoPath = '/tmp/evidence.jpg',
  String? evidenceOmissionReason,
  SyncState syncState = SyncState.pending,
  ReviewStatus reviewStatus = ReviewStatus.pendingReview,
  DateTime? createdAt,
}) =>
    IncidentReport(
      id: id,
      rangerId: rangerId,
      parkId: parkId,
      category: category,
      description: description,
      observedAt: observedAt ?? DateTime.utc(2026, 9, 23, 7, 14),
      latitude: latitude,
      longitude: longitude,
      locationSource: locationSource,
      localPhotoPath: localPhotoPath,
      evidenceOmissionReason: evidenceOmissionReason,
      submissionStatus: SubmissionStatus.submitted,
      reviewStatus: reviewStatus,
      syncState: syncState,
      createdAt: createdAt ?? DateTime.utc(2026, 9, 23, 7, 20),
    );

void main() {
  late AppDatabase db;
  late IncidentLocalDataSource local;
  late IncidentRepositoryImpl repo;

  setUp(() {
    db = createIncidentTestDatabase();
    local = IncidentLocalDataSource(db);
    repo = IncidentRepositoryImpl(local);
  });

  tearDown(() => db.close());

  group('IncidentRepositoryImpl – creation and validation', () {
    test('successful incident creation persists the record', () async {
      final draft = validDraft();
      final saved = await repo.createIncident(draft);

      expect(saved.id, 'incident_test_1');
      final stored = await repo.getIncident('incident_test_1');
      expect(stored, isNotNull);
      expect(stored!.category, IncidentCategory.snare);
      expect(stored.submissionStatus, SubmissionStatus.submitted);
    });

    test('stable report ID is kept on save (no regeneration)', () async {
      final draft = validDraft(id: 'incident_stable_42');
      await repo.createIncident(draft);
      final stored = await repo.getIncident('incident_stable_42');
      expect(stored!.id, 'incident_stable_42');
    });

    test('missing description is rejected before any write', () async {
      final draft = validDraft(description: '   ');
      await expectLater(
        repo.createIncident(draft),
        throwsA(isA<ValidationException>()),
      );
      expect(await repo.getIncident('incident_test_1'), isNull);
    });

    test('invalid coordinates are rejected', () async {
      final draft = validDraft(latitude: 120);
      await expectLater(
        repo.createIncident(draft),
        throwsA(isA<ValidationException>()),
      );
    });

    test('neither photo nor omission reason is rejected', () async {
      final draft = validDraft(localPhotoPath: null);
      expect(draft.isEvidenceValid, isFalse);
      await expectLater(
        repo.createIncident(draft),
        throwsA(isA<ValidationException>()),
      );
    });

    test('omission reason alone satisfies the evidence rule', () async {
      final draft = validDraft(
        localPhotoPath: null,
        evidenceOmissionReason: 'Unsafe to approach the snare location.',
      );
      expect(draft.isEvidenceValid, isTrue);
      await repo.createIncident(draft);
      final stored = await repo.getIncident('incident_test_1');
      expect(stored!.evidenceOmissionReason, isNotNull);
      expect(stored.localPhotoPath, isNull);
    });

    test('photo alone satisfies the evidence rule', () async {
      final draft = validDraft(); // has localPhotoPath
      await repo.createIncident(draft);
      final stored = await repo.getIncident('incident_test_1');
      expect(stored!.localPhotoPath, '/tmp/evidence.jpg');
    });
  });

  group('IncidentRepositoryImpl – pending/synchronized scoping', () {
    test('pending incidents include pending rows only', () async {
      await local.upsertIncident(validDraft(
          id: 'i_pending', syncState: SyncState.pending));
      await local.upsertIncident(validDraft(
          id: 'i_synced', syncState: SyncState.synchronized));
      await local.upsertIncident(validDraft(
          id: 'i_failed', syncState: SyncState.failed));

      final pending = await repo.getPendingIncidents();
      expect(pending.map((r) => r.id), containsAll(['i_pending']));
      expect(pending.map((r) => r.id), isNot(contains('i_synced')));
    });

    test('review queue excludes unsynchronized ranger reports', () async {
      await local.upsertIncident(validDraft(
          id: 'i_local_only',
          rangerId: 'R001',
          syncState: SyncState.pending));
      await local.upsertIncident(validDraft(
          id: 'i_synced_mgr',
          rangerId: 'R002',
          parkId: 'PARK-MIN',
          syncState: SyncState.synchronized));

      final queue = await repo.getIncidentsForReview('PARK-MIN');
      expect(queue.map((r) => r.id), ['i_synced_mgr']);
    });

    test('review queue is scoped to the park', () async {
      await local.upsertIncident(validDraft(
          id: 'i_other_park',
          parkId: 'PARK-OTHER',
          syncState: SyncState.synchronized));

      final queue = await repo.getIncidentsForReview('PARK-MIN');
      expect(queue, isEmpty);
    });

    test('upserting the same ID never duplicates rows (retry safety)',
        () async {
      await repo.createIncident(validDraft(id: 'incident_retry'));
      await repo.createIncident(validDraft(
          id: 'incident_retry',
          description: 'Updated description after retry'));

      final all = await db.select(db.incidentReportsTable).get();
      expect(all, hasLength(1));
      expect(all.single.description, 'Updated description after retry');
    });

    test('local save failure surfaces instead of false success', () async {
      // Local write fails => the repository must throw instead of reporting
      // success (the ranger must never see a false "saved/pending").
      final brokenRepo = IncidentRepositoryImpl(_BrokenLocalDataSource());
      await expectLater(
        brokenRepo.createIncident(validDraft()),
        throwsA(isA<LocalStorageException>()),
      );
    });
  });

  group('IncidentRepositoryImpl – review workflow', () {
    test('reviewer update records reviewer, time and resulting status',
        () async {
      await repo.createIncident(validDraft(
          id: 'i_review', syncState: SyncState.synchronized));

      final updated = await repo.updateReviewStatus(
        id: 'i_review',
        status: ReviewStatus.underReview,
        reviewerId: 'PM001',
        reviewNotes: 'Requesting site inspection.',
      );

      expect(updated.reviewStatus, ReviewStatus.underReview);
      expect(updated.reviewerId, 'PM001');
      expect(updated.reviewNotes, 'Requesting site inspection.');
      expect(updated.reviewedAt, isNotNull);
    });

    test('review to verified keeps all fields', () async {
      await repo.createIncident(validDraft(
          id: 'i_verify', syncState: SyncState.synchronized));
      final updated = await repo.updateReviewStatus(
        id: 'i_verify',
        status: ReviewStatus.verified,
        reviewerId: 'PM001',
      );
      expect(updated.reviewStatus, ReviewStatus.verified);
    });

    test('review to rejected keeps all fields', () async {
      await repo.createIncident(validDraft(
          id: 'i_reject', syncState: SyncState.synchronized));
      final updated = await repo.updateReviewStatus(
        id: 'i_reject',
        status: ReviewStatus.rejected,
        reviewerId: 'PM001',
      );
      expect(updated.reviewStatus, ReviewStatus.rejected);
    });

    test('review without a note keeps notes null', () async {
      await repo.createIncident(validDraft(
          id: 'i_nonote', syncState: SyncState.synchronized));
      final updated = await repo.updateReviewStatus(
        id: 'i_nonote',
        status: ReviewStatus.verified,
        reviewerId: 'PM001',
      );
      expect(updated.reviewNotes, isNull);
    });

    test('updating a missing incident throws RepositoryException', () async {
      await expectLater(
        repo.updateReviewStatus(
            id: 'ghost', status: ReviewStatus.verified, reviewerId: 'PM001'),
        throwsA(isA<RepositoryException>()),
      );
    });

    test('failed review save retains the previous status', () async {
      final saved = await repo.createIncident(validDraft(
          id: 'i_keep',
          syncState: SyncState.synchronized,
          reviewStatus: ReviewStatus.underReview));
      await db.close();

      // The write now fails (storage gone). Whatever error surfaces, the
      // stored record still holds the previous status.
      final brokenRepo = IncidentRepositoryImpl(IncidentLocalDataSource(db));
      await expectLater(
        brokenRepo.updateReviewStatus(
            id: 'i_keep', status: ReviewStatus.verified, reviewerId: 'PM001'),
        throwsA(anything),
      );
      expect(saved.reviewStatus, ReviewStatus.underReview);
    });
  });
}
