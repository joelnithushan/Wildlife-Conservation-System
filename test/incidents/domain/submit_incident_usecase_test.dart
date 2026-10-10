import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/core/errors/exceptions.dart';
import 'package:wildlife_conservation_system/core/services/connectivity_service.dart';
import 'package:wildlife_conservation_system/core/sync/sync_service.dart';
import 'package:wildlife_conservation_system/features/incidents/data/datasources/incident_evidence_source.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/usecases/submit_incident_usecase.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';
import 'package:wildlife_conservation_system/shared/repositories/incident_repository.dart';

class _MockRepo extends Mock implements IncidentRepository {}

class _MockConnectivity extends Mock implements ConnectivityService {}

class _MockEvidence extends Mock implements IncidentEvidenceRepository {}

class _MockSync extends Mock implements SyncService {}

void main() {
  late _MockRepo repo;
  late _MockConnectivity connectivity;
  late _MockEvidence evidence;
  late _MockSync sync;
  late SubmitIncidentUseCase useCase;

  final now = DateTime.utc(2026, 9, 26, 8);

  IncidentReport report() => IncidentReport.create(
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Snare found near waterhole',
        observedAt: now,
        latitude: 8.03,
        longitude: 80.9,
        locationSource: LocationSource.gps,
        createdAt: now,
      );

  final captured = CapturedEvidence(
    localPath: '/tmp/x.jpg',
    filename: 'x.jpg',
    bytes: Uint8List.fromList([1, 2, 3]),
  );

  setUpAll(() {
    registerFallbackValue(report());
  });

  setUp(() {
    repo = _MockRepo();
    connectivity = _MockConnectivity();
    evidence = _MockEvidence();
    sync = _MockSync();
    useCase = SubmitIncidentUseCase(
      repository: repo,
      connectivity: connectivity,
      evidenceRepository: evidence,
      syncService: sync,
    );
    when(() => repo.createIncident(any()))
        .thenAnswer((i) async => i.positionalArguments.first as IncidentReport);
  });

  test('saves locally and returns false when offline (stays pending)',
      () async {
    when(() => connectivity.isOnline()).thenAnswer((_) async => false);

    final r = report();
    final result = await useCase.execute(r, null);

    expect(result, isFalse); // offline → saved but not synced
    verify(() => repo.createIncident(r)).called(1);
    verifyNever(() => sync.syncPendingIncidentData());
    verifyNever(() => evidence.uploadEvidence(
        incidentId: any(named: 'incidentId'),
        evidence: any(named: 'evidence')));
  });

  test('online with no evidence syncs and returns true when sync succeeds',
      () async {
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(() => sync.syncPendingIncidentData())
        .thenAnswer((_) async => const SyncSummary(pushed: 1));

    final result = await useCase.execute(report(), null);

    expect(result, isTrue);
    verify(() => sync.syncPendingIncidentData()).called(1);
  });

  test('online with evidence uploads it before syncing', () async {
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(() => evidence.uploadEvidence(
            incidentId: any(named: 'incidentId'),
            evidence: any(named: 'evidence')))
        .thenAnswer((_) async => const EvidenceUploadResult(url: 'u'));
    when(() => sync.syncPendingIncidentData())
        .thenAnswer((_) async => const SyncSummary(pushed: 1));

    final r = report();
    final result = await useCase.execute(r, captured);

    expect(result, isTrue);
    verify(() => evidence.uploadEvidence(
        incidentId: r.id, evidence: captured)).called(1);
    verify(() => sync.syncPendingIncidentData()).called(1);
  });

  test('returns false when the sync reports failures', () async {
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(() => sync.syncPendingIncidentData())
        .thenAnswer((_) async => const SyncSummary(pushed: 0, failed: 1));

    expect(await useCase.execute(report(), null), isFalse);
  });

  test('swallows upload/sync errors and stays pending (returns false)',
      () async {
    when(() => connectivity.isOnline()).thenAnswer((_) async => true);
    when(() => sync.syncPendingIncidentData())
        .thenThrow(const RepositoryException('network down'));

    // The local save still succeeded; the error must not propagate.
    expect(await useCase.execute(report(), null), isFalse);
    verify(() => repo.createIncident(any())).called(1);
  });

  test('a failed local save propagates (nothing to report as safe)', () async {
    when(() => repo.createIncident(any()))
        .thenThrow(const LocalStorageException('disk full'));

    expect(() => useCase.execute(report(), null),
        throwsA(isA<LocalStorageException>()));
    verifyNever(() => connectivity.isOnline());
  });
}
