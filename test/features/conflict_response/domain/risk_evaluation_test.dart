import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/conflict_response/domain/risk_evaluation.dart';
import 'package:wildlife_conservation_system/shared/demo/demo_data.dart';
import 'package:wildlife_conservation_system/shared/models/geo_coordinate.dart';
import 'package:wildlife_conservation_system/shared/models/risk_zone.dart';
import 'package:wildlife_conservation_system/core/enums/app_enums.dart';

void main() {
  final zones = DemoData.riskZones;

  test('point inside RZ-01 matches that zone', () {
    final zone = RiskEvaluator.firstMatchingZone(8.030, 80.900, zones);
    expect(zone, isNotNull);
    expect(zone!.id, 'RZ-01');
  });

  test('point far outside every zone matches nothing', () {
    final zone = RiskEvaluator.firstMatchingZone(8.200, 81.200, zones);
    expect(zone, isNull);
  });

  test('zone without a polygon never matches', () {
    const empty = RiskZone(
      id: 'RZ-EMPTY',
      parkId: 'PARK-MIN',
      name: 'No boundary',
      riskLevel: RiskLevel.low,
    );
    expect(RiskEvaluator.isInsideZone(8.03, 80.90, empty), isFalse);
  });

  test('degenerate polygon (2 points) never matches', () {
    const line = RiskZone(
      id: 'RZ-LINE',
      parkId: 'PARK-MIN',
      name: 'Line',
      riskLevel: RiskLevel.low,
      boundary: [
        GeoCoordinate(latitude: 8.0, longitude: 80.0),
        GeoCoordinate(latitude: 8.1, longitude: 80.1),
      ],
    );
    expect(RiskEvaluator.isInsideZone(8.05, 80.05, line), isFalse);
  });
}
