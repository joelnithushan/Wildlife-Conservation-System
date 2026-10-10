import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wildlife_conservation_system/app.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/data/drift_report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/firestore_alert_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_export_service_impl.dart';
import 'package:wildlife_conservation_system/features/analytics/data/report_read_store.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_source_data.dart';
import 'package:wildlife_conservation_system/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/session/current_user.dart';

/// Counts read-store loads so an export can be shown not to query again.
class CountingReportReadStore implements ReportReadStore {
  CountingReportReadStore(this.inner);

  final ReportReadStore inner;
  int loads = 0;

  @override
  Future<ReportSourceData> load(String parkId) async {
    loads++;
    return inner.load(parkId);
  }
}

class ReportFlowHarness {
  ReportFlowHarness({required this.store, required this.saved});

  final CountingReportReadStore store;
  final Map<String, List<int>> saved;

  static Future<ReportFlowHarness> pump(
    WidgetTester tester, {
    bool researcher = false,
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final db = AppDatabase(NativeDatabase.memory());
    await _seed(db);
    final store = CountingReportReadStore(
      DriftReportReadStore(db, alerts: const EmptyAlertReadStore()),
    );
    final saved = <String, List<int>>{};

    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (researcher)
            currentUserProvider.overrideWith(_ResearcherUser.new),
          appDatabaseProvider.overrideWith((ref) {
            ref.onDispose(db.close);
            return db;
          }),
          reportReadStoreProvider.overrideWithValue(store),
          reportExportServiceProvider.overrideWithValue(
            ReportExportServiceImpl(
              save: (name, bytes) async {
                saved[name] = bytes;
                return name;
              },
            ),
          ),
        ],
        child: const WildlifeApp(),
      ),
    );
    await tester.pumpAndSettle();
    return ReportFlowHarness(store: store, saved: saved);
  }
}

Future<void> _seed(AppDatabase db) async {
  // Inside today's local calendar day, and before the snapshot cutoff.
  final observed = DateTime.now();
  await db.into(db.incidentReportsTable).insert(
        IncidentReportsTableCompanion(
          id: const Value('synced-incident'),
          rangerId: const Value('R001'),
          parkId: const Value('PARK-MIN'),
          category: Value(IncidentCategory.snare.wire),
          description: const Value('Snare on the trail'),
          observedAt: Value(observed),
          latitude: const Value(8.1),
          longitude: const Value(80.4),
          locationSource: Value(LocationSource.gps.wire),
          submissionStatus: Value(SubmissionStatus.submitted.wire),
          reviewStatus: Value(ReviewStatus.pendingReview.wire),
          syncState: Value(SyncState.synchronized.wire),
          createdAt: Value(observed),
        ),
      );
  await db.into(db.incidentReportsTable).insert(
        IncidentReportsTableCompanion(
          id: const Value('pending-incident'),
          rangerId: const Value('R001'),
          parkId: const Value('PARK-MIN'),
          category: Value(IncidentCategory.snare.wire),
          description: const Value('Not yet synchronized'),
          observedAt: Value(observed),
          latitude: const Value(8.1),
          longitude: const Value(80.4),
          locationSource: Value(LocationSource.gps.wire),
          submissionStatus: Value(SubmissionStatus.submitted.wire),
          reviewStatus: Value(ReviewStatus.pendingReview.wire),
          syncState: Value(SyncState.pending.wire),
          createdAt: Value(observed),
        ),
      );
  await db.into(db.patrolsTable).insert(
        PatrolsTableCompanion(
          id: const Value('patrol-done'),
          routeId: const Value('RT-07'),
          rangerId: const Value('R001'),
          parkId: const Value('PARK-MIN'),
          scheduledFor: Value(observed),
          status: Value(PatrolStatus.completed.wire),
          assignedAt: Value(observed),
          completedAt: Value(observed),
          coveragePercent: const Value(80),
          syncState: Value(SyncState.synchronized.wire),
        ),
      );
}

/// Confirms the currently highlighted day in the material date picker.
Future<void> confirmDatePicker(WidgetTester tester) async {
  await tester.tap(find.text('Required').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

class _ResearcherUser extends CurrentUserNotifier {
  @override
  AppUser build() => DemoData.researcher;
}
