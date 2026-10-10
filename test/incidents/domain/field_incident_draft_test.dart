import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/field_incident_draft.dart';

void main() {
  test('a complete field incident has nothing missing', () {
    expect(
      FieldIncidentDraft.missing(
        hasIncidentType: true,
        hasPhotograph: true,
        hasLocation: true,
        hasCaptureTime: true,
        description: 'Wire snare found beside animal trail.',
        hasRanger: true,
        hasActivePatrol: true,
      ),
      isEmpty,
    );
  });

  test('each missing required item is named', () {
    expect(
      FieldIncidentDraft.missing(
        hasIncidentType: false,
        hasPhotograph: false,
        hasLocation: false,
        hasCaptureTime: false,
        description: '   ',
        hasRanger: false,
        hasActivePatrol: false,
      ),
      [
        'incident type',
        'photograph',
        'GPS location',
        'GPS capture time',
        'description',
        'authenticated ranger',
        'active patrol',
      ],
    );
  });

  test('the five incident types are the field labels', () {
    expect(FieldIncidentDraft.incidentTypeLabels, [
      'Snare',
      'Carcass',
      'Illegal campsite',
      'Suspicious footprints',
      'Other',
    ]);
  });
}
