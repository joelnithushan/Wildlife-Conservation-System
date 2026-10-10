import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';
import 'package:wildlife_conservation_system/features/analytics/data/category_labels.dart';
import 'package:wildlife_conservation_system/features/analytics/domain/report_access_policy.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/app_user.dart';

void main() {
  group('ReportAccessPolicy.canGenerate', () {
    test('allows park managers and conservation researchers', () {
      expect(ReportAccessPolicy.canGenerate(UserRole.parkManager), isTrue);
      expect(
          ReportAccessPolicy.canGenerate(UserRole.conservationResearcher), isTrue);
    });

    test('denies rangers, liaison officers and admins', () {
      expect(ReportAccessPolicy.canGenerate(UserRole.ranger), isFalse);
      expect(
          ReportAccessPolicy.canGenerate(UserRole.communityLiaisonOfficer),
          isFalse);
      expect(ReportAccessPolicy.canGenerate(UserRole.admin), isFalse);
    });
  });

  group('ReportAccessPolicy.permittedParks & allows', () {
    test('a manager in the demo park may read exactly that park', () {
      final parks = ReportAccessPolicy.permittedParks(DemoData.parkManager);
      expect(parks.map((p) => p.id), [DemoData.park.id]);
      expect(ReportAccessPolicy.allows(DemoData.parkManager, DemoData.park.id),
          isTrue);
      expect(ReportAccessPolicy.allows(DemoData.parkManager, 'SOME-OTHER-PARK'),
          isFalse);
    });

    test('a permitted user in a non-demo park reads only their own park', () {
      const researcher = AppUser(
        id: 'CR-X',
        name: 'Researcher X',
        email: 'x@wildguard.lk',
        role: UserRole.conservationResearcher,
        parkId: 'PARK-OTHER',
      );
      final parks = ReportAccessPolicy.permittedParks(researcher);
      expect(parks.map((p) => p.id), ['PARK-OTHER']);
      expect(ReportAccessPolicy.allows(researcher, 'PARK-OTHER'), isTrue);
    });

    test('a ranger (not permitted) gets no parks', () {
      expect(ReportAccessPolicy.permittedParks(DemoData.rangerPerera), isEmpty);
      expect(ReportAccessPolicy.allows(DemoData.rangerPerera, DemoData.park.id),
          isFalse);
    });

    test('a permitted user with a blank park gets no parks', () {
      const u = AppUser(
        id: 'PM-X',
        name: 'Manager X',
        email: 'pm@wildguard.lk',
        role: UserRole.parkManager,
        parkId: '  ',
      );
      expect(ReportAccessPolicy.permittedParks(u), isEmpty);
    });
  });

  // Step 3 cross-check: UC04 analytics must label the *same* IncidentCategory
  // enum values UC02 records against — no divergent copy of the enum.
  group('UC04 category labels stay in sync with the UC02 IncidentCategory enum',
      () {
    test('every IncidentCategory value has a distinct, non-empty label', () {
      final labels =
          IncidentCategory.values.map(incidentCategoryLabel).toList();
      expect(labels.every((l) => l.trim().isNotEmpty), isTrue);
      expect(labels.toSet().length, IncidentCategory.values.length);
    });

    test('labels cover the exact UC02 enum set (design-report categories)', () {
      // Will fail to compile/throw if a new enum value is added without a label,
      // because the switch in incidentCategoryLabel is exhaustive.
      expect(
        IncidentCategory.values.map(incidentCategoryLabel),
        containsAll(<String>[
          'Snare',
          'Carcass',
          'Illegal campsite',
          'Suspicious footprints',
          'Other',
        ]),
      );
    });

    test('UC02 field labels and UC04 analytics labels are identical', () {
      // Each IncidentReportCategory (UC02 field picker) must render the same text
      // UC04 uses for its shared IncidentCategory.
      for (final c in IncidentReportCategory.values) {
        expect(c.label, incidentCategoryLabel(c.shared),
            reason: 'UC02/UC04 label mismatch for ${c.name}');
      }
    });
  });
}
