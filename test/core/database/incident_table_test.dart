import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';

void main() {
  late AppDatabase db;
  final observedAt = DateTime.utc(2026, 9, 23, 7, 14);

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  IncidentReportsTableCompanion draft(String id) => IncidentReportsTableCompanion(
        id: Value(id),
        rangerId: const Value('R001'),
        parkId: const Value('PARK-MIN'),
        category: Value(IncidentCategory.poaching.wire),
        description: const Value('Wire snare near the trail'),
        observedAt: Value(observedAt),
        latitude: const Value(8.412),
        longitude: const Value(80.402),
        locationSource: Value(LocationSource.gps.wire),
        submissionStatus: Value(SubmissionStatus.draft.wire),
        reviewStatus: Value(ReviewStatus.pendingReview.wire),
        syncState: Value(SyncState.pending.wire),
      );

  test('IncidentReports insert and read back preserves fields', () async {
    await db.into(db.incidentReportsTable).insert(draft('incident_1'));

    final row = await (db.select(db.incidentReportsTable)
          ..where((t) => t.id.equals('incident_1')))
        .getSingle();

    expect(row.rangerId, 'R001');
    expect(row.parkId, 'PARK-MIN');
    expect(row.category, IncidentCategory.poaching.wire);
    // Domain event time is preserved (same instant; Drift returns it as local).
    expect(row.observedAt.isAtSameMomentAs(observedAt), isTrue);
    expect(row.submissionStatus, SubmissionStatus.draft.wire);
    expect(row.reviewStatus, ReviewStatus.pendingReview.wire);
    expect(row.syncState, SyncState.pending.wire);
  });

  test('pending incidents query returns unsynced rows only', () async {
    await db.into(db.incidentReportsTable).insert(draft('incident_pending'));
    await db.into(db.incidentReportsTable).insert(
          draft('incident_synced')
              .copyWith(syncState: Value(SyncState.synchronized.wire)),
        );

    final pending = await (db.select(db.incidentReportsTable)
          ..where((t) => t.syncState.equals(SyncState.pending.wire)))
        .get();

    expect(pending, hasLength(1));
    expect(pending.single.id, 'incident_pending');
  });

  test('insertOnConflictUpdate is idempotent on the stable id', () async {
    await db
        .into(db.incidentReportsTable)
        .insertOnConflictUpdate(draft('incident_1'));
    await db.into(db.incidentReportsTable).insertOnConflictUpdate(
          draft('incident_1').copyWith(reviewStatus: Value(ReviewStatus.verified.wire)),
        );

    final rows = await db.select(db.incidentReportsTable).get();
    expect(rows, hasLength(1)); // no duplicate
    expect(rows.single.reviewStatus, ReviewStatus.verified.wire);
  });
}
