import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/core/widgets/app_map.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/widgets/route_preview.dart';
import 'package:wildlife_conservation_system/shared/models/geo_coordinate.dart';
import 'package:wildlife_conservation_system/shared/providers/providers.dart';

/// The shared map widgets are gated by [mapsEnabledProvider]: the running app
/// turns it on (real Google Maps) and headless tests leave it off (lightweight
/// canvas preview, since a GoogleMap platform view can't render in flutter test).
void main() {
  const path = [
    GeoCoordinate(latitude: 8.02, longitude: 80.89),
    GeoCoordinate(latitude: 8.04, longitude: 80.91),
  ];

  Widget host({bool mapsEnabled = false}) => ProviderScope(
        overrides: [
          if (mapsEnabled) mapsEnabledProvider.overrideWithValue(true),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RoutePreview(plannedPath: path)),
        ),
      );

  test('maps are disabled by default so tests fall back to the canvas', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(mapsEnabledProvider), isFalse);
  });

  testWidgets('RoutePreview shows the canvas preview when maps are disabled',
      (tester) async {
    await tester.pumpWidget(host());
    expect(find.byType(GoogleRouteMap), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets); // the canvas painter
  });

  testWidgets('RoutePreview renders the Google map when maps are enabled',
      (tester) async {
    await tester
        .pumpWidget(host(mapsEnabled: true));
    expect(find.byType(GoogleRouteMap), findsOneWidget);
  });
}
