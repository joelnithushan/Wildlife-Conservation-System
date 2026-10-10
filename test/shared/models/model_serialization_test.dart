import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/shared/models/models.dart';

void main() {
  final now = DateTime.utc(2026, 9, 23, 8, 30);

  group('toMap/fromMap round trips', () {
    test('Patrol', () {
      final patrol = Patrol(
        id: 'patrol_1',
        routeId: 'RT-07',
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        scheduledFor: now,
        assignedAt: now,
        status: PatrolStatus.inProgress,
        startedAt: now.add(const Duration(minutes: 5)),
        coveragePercent: 42.5,
        syncState: SyncState.pending,
      );
      expect(Patrol.fromMap(patrol.toMap()), patrol);
    });

    test('PatrolPosition', () {
      final pos = PatrolPosition(
        id: 'pos_1',
        patrolId: 'patrol_1',
        latitude: 7.9,
        longitude: 80.9,
        timestamp: now,
        captureMode: CaptureMode.manual,
      );
      expect(PatrolPosition.fromMap(pos.toMap()), pos);
    });

    test('IncidentReport', () {
      final incident = IncidentReport(
        id: 'incident_1',
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Snare found near river',
        observedAt: now,
        latitude: 7.9,
        longitude: 80.9,
        locationSource: LocationSource.gps,
        createdAt: now,
        localPhotoPath: '/tmp/evidence.jpg',
        submissionStatus: SubmissionStatus.submitted,
        reviewStatus: ReviewStatus.underReview,
      );
      expect(IncidentReport.fromMap(incident.toMap()), incident);
    });

    test('WildlifeRiskAlert', () {
      final alert = WildlifeRiskAlert(
        id: 'alert_1',
        parkId: 'PARK-MIN',
        source: AlertSource.collar,
        latitude: 7.9,
        longitude: 80.9,
        severity: AlertSeverity.high,
        createdAt: now,
        animalId: 'EL-07',
        status: AlertStatus.assigned,
      );
      expect(WildlifeRiskAlert.fromMap(alert.toMap()), alert);
    });

    test('ResponseAssignment', () {
      final assignment = ResponseAssignment(
        id: 'assignment_1',
        alertId: 'alert_1',
        responderId: 'R002',
        responderRole: ResponderRole.ranger,
        assignedBy: 'PM001',
        assignedAt: now,
        deliveryState: DeliveryState.delivered,
        acknowledgedAt: now.add(const Duration(minutes: 2)),
      );
      expect(ResponseAssignment.fromMap(assignment.toMap()), assignment);
    });

    test('CommunityReport', () {
      final report = CommunityReport(
        id: 'community_1',
        parkId: 'PARK-MIN',
        description: 'Elephant near village',
        latitude: 7.9,
        longitude: 80.9,
        createdAt: now,
        verified: true,
        verifiedBy: 'CLO001',
      );
      expect(CommunityReport.fromMap(report.toMap()), report);
    });

    test('AppUser', () {
      const user = AppUser(
        id: 'R001',
        name: 'K. Perera',
        role: UserRole.ranger,
        parkId: 'PARK-MIN',
      );
      expect(AppUser.fromMap(user.toMap()), user);
    });

    test('PatrolRoute with planned path', () {
      const route = PatrolRoute(
        id: 'RT-07',
        parkId: 'PARK-MIN',
        name: 'North Ridge',
        description: 'ridge',
        distanceKm: 7.4,
        plannedPath: [
          GeoCoordinate(latitude: 7.9, longitude: 80.9),
          GeoCoordinate(latitude: 8.0, longitude: 81.0),
        ],
      );
      expect(PatrolRoute.fromMap(route.toMap()), route);
    });
  });
}
