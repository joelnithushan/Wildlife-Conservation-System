import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildlife_conservation_system/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_local_data_source.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';
import 'package:wildlife_conservation_system/shared/services/location_service.dart';

import '../helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

/// Data source whose writes always fail — models broken local storage so the
/// "Not saved – retry" path (never a false "pending") can be exercised.
class _BrokenLocalDataSource extends IncidentLocalDataSource {
  _BrokenLocalDataSource() : super(createIncidentTestDatabase());

  @override
  Future<bool> upsertIncident(IncidentReport incident, {DateTime? now}) async =>
      false;
}

/// Minimal remote writer used to prove the sync round-trip in tests.
class FakeRemoteWriter implements RemoteWriter {
  final Map<String, Map<String, dynamic>> documents = {};

  @override
  Future<void> upsert(
      String collection, String id, Map<String, dynamic> data) async {
    documents['$collection/$id'] = data;
  }
}

void main() {
  late ProviderContainer container;
  late _MockLocationService location;

  /// The default (online) container used for filling the form AND submitting,
  /// so both read the same IncidentFormController. Uses the app's default
  /// offline-first wiring with every real plugin faked out.
  ProviderContainer mainContainer({FakeConnectivityService? connectivity}) {
    return ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
      locationServiceProvider.overrideWithValue(location),
      connectivityServiceProvider.overrideWithValue(
          connectivity ?? FakeConnectivityService(online: true)),
      storageServiceProvider.overrideWithValue(FakeStorageService()),
      remoteWriterProvider.overrideWithValue(FakeRemoteWriter()),
    ]);
  }

  setUp(() {
    location = _MockLocationService();
    container = mainContainer();
    addTearDown(container.dispose);
    // Default actor for submissions/reviews is a signed-in ranger.
    container.read(currentUserProvider.notifier).signIn(
          const AppUser(
            id: 'R001',
            name: 'Test Ranger',
            parkId: 'PARK-MIN',
            role: UserRole.ranger,
          ),
        );
  });

  IncidentFormController controller() =>
      container.read(incidentFormControllerProvider.notifier);

  CapturedEvidence evidence([String path = '/tmp/photo.jpg']) =>
      CapturedEvidence(
        localPath: path,
        filename: 'photo.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

  /// Fills every prerequisite except [skip] so each step can be tested alone.
  void fillAll({String skip = ''}) {
    if (skip != 'category') controller().selectCategory(IncidentReportCategory.snare);
    if (skip != 'evidence') controller().setEvidence(evidence());
    if (skip != 'location') controller().setManualLocation(8.03, 80.89);
    if (skip != 'description') controller().setDescription('Wire snare found');
    if (skip != 'patrol') controller().bindPatrol('patrol-active');
  }

  group('UC02-S01 form – category selection', () {
    test('starts with no category', () {
      expect(container.read(incidentFormControllerProvider).category, isNull);
      expect(
          container.read(incidentFormControllerProvider).categoryValid, isFalse);
    });

    test('selecting exactly one category stores it', () {
      controller().selectCategory(IncidentReportCategory.carcass);
      final form = container.read(incidentFormControllerProvider);
      expect(form.category, IncidentReportCategory.carcass);
      expect(form.categoryValid, isTrue);
    });

    test('re-selecting replaces the previous category (still exactly one)',
        () {
      controller().selectCategory(IncidentReportCategory.snare);
      controller().selectCategory(IncidentReportCategory.other);
      expect(
          container.read(incidentFormControllerProvider).category,
          IncidentReportCategory.other);
    });
  });

  group('UC02-S01 form – evidence rule', () {
    test('photo evidence is accepted', () {
      controller().setEvidence(evidence());
      final form = container.read(incidentFormControllerProvider);
      expect(form.evidence.hasPhoto, isTrue);
      expect(form.evidenceValid, isTrue);
    });

    test('omission reason alone is accepted (no photo)', () {
      controller().setOmissionReason('Unsafe to approach the snare location.');
      final form = container.read(incidentFormControllerProvider);
      expect(form.evidence.hasPhoto, isFalse);
      expect(form.evidence.hasOmissionReason, isTrue);
      expect(form.evidenceValid, isTrue);
    });

    test('neither photo nor omission reason is invalid', () {
      final form = container.read(incidentFormControllerProvider);
      expect(form.evidenceValid, isFalse);
    });

    test('blank omission reason does not count as a reason', () {
      controller().setOmissionReason('   ');
      expect(
          container.read(incidentFormControllerProvider).evidenceValid, isFalse);
    });

    test('taking a photo clears the omission reason (they are alternatives)',
        () {
      controller().setOmissionReason('Unsafe to approach.');
      controller().setEvidence(evidence());
      final form = container.read(incidentFormControllerProvider);
      expect(form.evidence.hasPhoto, isTrue);
      expect(form.evidence.hasOmissionReason, isFalse);
    });
  });

  group('UC02-S01 form – location', () {
    test('GPS fix is stored with locationSource = gps', () async {
      when(() => location.getCurrentPosition()).thenAnswer(
          (_) async => (latitude: 8.031, longitude: 80.897));
      when(() => location.requestPermission()).thenAnswer((_) async => true);

      await controller().captureGpsLocation();

      final form = container.read(incidentFormControllerProvider);
      expect(form.latitude, 8.031);
      expect(form.longitude, 80.897);
      expect(form.locationSource, LocationSource.gps);
      expect(form.gpsCapturedAt, isNotNull);
      expect(form.locationValid, isTrue);
    });

    test('GPS failure stores an error and never fabricates coordinates',
        () async {
      when(() => location.getCurrentPosition())
          .thenThrow(Exception('no fix'));

      await controller().captureGpsLocation();

      final form = container.read(incidentFormControllerProvider);
      expect(form.hasLocation, isFalse);
      expect(form.locationSource, isNull);
      expect(form.gpsError, isNotNull);
      expect(form.locationValid, isFalse);
    });

    test('permission denial is surfaced and manual entry stays available',
        () async {
      when(() => location.getCurrentPosition()).thenThrow(
          const PermissionException('Location permission not granted.'));

      await controller().captureGpsLocation();

      final form = container.read(incidentFormControllerProvider);
      expect(form.gpsError, contains('permission'));
      // Manual fallback still works after GPS failure:
      controller().setManualLocation(8.0, 80.8);
      expect(container.read(incidentFormControllerProvider).locationSource,
          LocationSource.manual);
    });

    test('manual location is stored with locationSource = manual', () {
      controller().setManualLocation(8.05, 80.91);
      final form = container.read(incidentFormControllerProvider);
      expect(form.latitude, 8.05);
      expect(form.longitude, 80.91);
      expect(form.locationSource, LocationSource.manual);
      expect(form.locationValid, isTrue);
    });
  });

  group('UC02-S01 form – description and readiness', () {
    test('description is required', () {
      fillAll(skip: 'description');
      final form = container.read(incidentFormControllerProvider);
      expect(form.descriptionValid, isFalse);
      expect(form.readyToSubmit, isFalse);
    });

    test('whitespace-only description is not valid', () {
      fillAll();
      controller().setDescription('   ');
      expect(
          container.read(incidentFormControllerProvider).descriptionValid,
          isFalse);
    });

    test('all steps complete → readyToSubmit', () {
      fillAll();
      expect(container.read(incidentFormControllerProvider).readyToSubmit,
          isTrue);
    });

    test('missing category blocks submission readiness', () {
      fillAll(skip: 'category');
      expect(container.read(incidentFormControllerProvider).readyToSubmit,
          isFalse);
    });

    test('missing evidence blocks submission readiness', () {
      fillAll(skip: 'evidence');
      expect(container.read(incidentFormControllerProvider).readyToSubmit,
          isFalse);
    });

    test('missing location blocks submission readiness', () {
      fillAll(skip: 'location');
      expect(container.read(incidentFormControllerProvider).readyToSubmit,
          isFalse);
    });

    test('reset clears everything (fresh report after submit)', () {
      fillAll();
      controller().reset();
      final form = container.read(incidentFormControllerProvider);
      expect(form.category, isNull);
      expect(form.hasLocation, isFalse);
      expect(form.description, isEmpty);
      expect(form.readyToSubmit, isFalse);
    });
  });

  group('UC02-S01 submission – offline-first behaviour', () {
    test('online submission synchronizes and keeps the stable report ID',
        () async {
      when(() => location.getCurrentPosition()).thenAnswer(
          (_) async => (latitude: 8.031, longitude: 80.897));
      fillAll();
      final ok =
          await container.read(incidentSubmissionProvider.notifier).submit();

      expect(ok, isTrue);
      final submission = container.read(incidentSubmissionProvider);
      expect(submission.status, SubmissionPhase.synchronized);
      expect(submission.reportId, startsWith('incident_'));
      expect(submission.reference, startsWith('IR-'));
      // Report really is in the local database.
      final stored = await container
          .read(incidentRepositoryProvider)
          .getIncident(submission.reportId!);
      expect(stored!.syncState, SyncState.synchronized);
      expect(stored.reviewStatus, ReviewStatus.pendingReview);
      expect(stored.submissionStatus, SubmissionStatus.submitted);
      expect(stored.rangerId, 'R001');
      expect(stored.patrolId, 'patrol-active');
    });

    test('offline submission stores locally with pending sync state',
        () async {
      when(() => location.getCurrentPosition()).thenAnswer(
          (_) async => (latitude: 8.031, longitude: 80.897));
      // No connectivity: the fake connectivity service reports offline.
      final offlineContainer =
          mainContainer(connectivity: FakeConnectivityService(online: false));
      addTearDown(offlineContainer.dispose);
      offlineContainer.read(currentUserProvider.notifier).signIn(
            const AppUser(
              id: 'R001',
              name: 'Test Ranger',
              parkId: 'PARK-MIN',
              role: UserRole.ranger,
            ),
          );
      // Fill the form in the SAME container that will submit it.
      offlineContainer.read(incidentFormControllerProvider.notifier).selectCategory(
          IncidentReportCategory.snare);
      offlineContainer.read(incidentFormControllerProvider.notifier).setEvidence(
          evidence());
      offlineContainer.read(incidentFormControllerProvider.notifier).setManualLocation(
          8.03, 80.89);
      offlineContainer.read(incidentFormControllerProvider.notifier).setDescription(
          'Wire snare found');
      offlineContainer
          .read(incidentFormControllerProvider.notifier)
          .bindPatrol('patrol-active');

      final ok = await offlineContainer
          .read(incidentSubmissionProvider.notifier)
          .submit();

      expect(ok, isTrue);
      final submission = offlineContainer.read(incidentSubmissionProvider);
      expect(submission.status, SubmissionPhase.savedOffline);
      expect(submission.message, contains('Offline'));
      final stored = await offlineContainer
          .read(incidentRepositoryProvider)
          .getIncident(submission.reportId!);
      expect(stored!.syncState, SyncState.pending);
    });

    test('an in-progress patrol from the patrol store is attached', () async {
      final db = container.read(appDatabaseProvider);
      await db.into(db.patrolsTable).insert(
            PatrolsTableCompanion.insert(
              id: 'patrol-live',
              routeId: 'route-1',
              rangerId: 'R001',
              parkId: 'PARK-MIN',
              scheduledFor: DateTime.utc(2026, 10, 8),
              assignedAt: DateTime.utc(2026, 10, 8),
              status: const Value('inProgress'),
            ),
          );
      fillAll(skip: 'patrol');

      final ok =
          await container.read(incidentSubmissionProvider.notifier).submit();

      expect(ok, isTrue);
      final stored = await container.read(incidentRepositoryProvider).getIncident(
            container.read(incidentSubmissionProvider).reportId!,
          );
      expect(stored!.patrolId, 'patrol-live');
      expect(stored.rangerId, 'R001');
    });

    test('invalid form never creates a report (duplicate-retry safety)',
        () async {
      fillAll(skip: 'evidence'); // no photo, no omission reason
      final ok =
          await container.read(incidentSubmissionProvider.notifier).submit();

      expect(ok, isFalse);
      expect(container.read(incidentSubmissionProvider).status,
          SubmissionPhase.failed);
    });

    test('pending status is only reported after the local save succeeded',
        () async {
      // Make the local write fail: the data source reports every write as
      // failed, so the controller must show "Not saved" and never "pending".
      final brokenContainer = ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
        locationServiceProvider.overrideWithValue(location),
        connectivityServiceProvider
            .overrideWithValue(FakeConnectivityService(online: true)),
        storageServiceProvider.overrideWithValue(FakeStorageService()),
        remoteWriterProvider.overrideWithValue(FakeRemoteWriter()),
        incidentLocalDataSourceProvider
            .overrideWithValue(_BrokenLocalDataSource()),
      ]);
      addTearDown(brokenContainer.dispose);
      brokenContainer.read(currentUserProvider.notifier).signIn(
            const AppUser(
              id: 'R001',
              name: 'Test Ranger',
              parkId: 'PARK-MIN',
              role: UserRole.ranger,
            ),
          );
      // Fill the form in the SAME container that will submit it.
      brokenContainer
          .read(incidentFormControllerProvider.notifier)
          .selectCategory(IncidentReportCategory.snare);
      brokenContainer
          .read(incidentFormControllerProvider.notifier)
          .setEvidence(evidence());
      brokenContainer
          .read(incidentFormControllerProvider.notifier)
          .setManualLocation(8.03, 80.89);
      brokenContainer
          .read(incidentFormControllerProvider.notifier)
          .setDescription('Wire snare found');
      brokenContainer
          .read(incidentFormControllerProvider.notifier)
          .bindPatrol('patrol-active');

      final ok =
          await brokenContainer.read(incidentSubmissionProvider.notifier).submit();

      expect(ok, isFalse);
      final submission = brokenContainer.read(incidentSubmissionProvider);
      expect(submission.status, SubmissionPhase.failed);
      expect(submission.message, contains('Not saved'));
    });
  });
}
