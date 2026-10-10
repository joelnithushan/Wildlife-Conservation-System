import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/shared/models/incident_report.dart';

void main() {
  IncidentReport base() => IncidentReport.create(
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Snare near river',
        observedAt: DateTime.utc(2026, 9, 23),
        latitude: 7.9,
        longitude: 80.9,
        locationSource: LocationSource.gps,
        createdAt: DateTime.utc(2026, 9, 23),
      );

  group('Incident evidence rule: photo OR omission reason', () {
    test('draft with a photo can submit', () {
      final incident = IncidentReport.create(
        rangerId: 'R001',
        parkId: 'PARK-MIN',
        category: IncidentCategory.snare,
        description: 'Snare near river',
        observedAt: DateTime.utc(2026, 9, 23),
        latitude: 7.9,
        longitude: 80.9,
        locationSource: LocationSource.gps,
        createdAt: DateTime.utc(2026, 9, 23),
        localPhotoPath: '/tmp/e.jpg',
      );
      expect(incident.isEvidenceValid, isTrue);
      expect(incident.canSubmit, isTrue);
    });

    test('omission reason satisfies the rule', () {
      final incident =
          base().copyWith(evidenceOmissionReason: 'camera malfunction');
      expect(incident.isEvidenceValid, isTrue);
      expect(incident.canSubmit, isTrue);
    });

    test('no photo and no reason cannot submit', () {
      final incident = base();
      expect(incident.isEvidenceValid, isFalse);
      expect(incident.canSubmit, isFalse);
    });
  });
}
