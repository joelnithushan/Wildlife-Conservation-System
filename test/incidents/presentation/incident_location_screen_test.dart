import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:wildlife_conservation_system/features/incidents/presentation/widgets/cached_park_map.dart';
import 'package:wildlife_conservation_system/shared/services/location_service.dart';

import '../helpers.dart';

class _MockLocationService extends Mock implements LocationService {}

void main() {
  // UC02 Screen 3 – Location & Description.
  late _MockLocationService location;

  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
        locationServiceProvider.overrideWithValue(location),
      ]);

  setUp(() {
    location = _MockLocationService();
  });

  Future<void> pump(WidgetTester tester, ProviderContainer c) =>
      pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
          initialLocation: AppRoutes.incidentLocation);

  testWidgets('GPS fix is shown with the GPS source label', (tester) async {
    when(() => location.getCurrentPosition())
        .thenAnswer((_) async => (latitude: 8.031, longitude: 80.897));
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);

    await tester.tap(find.text('Use current GPS location'));
    await tester.pumpAndSettle();

    expect(find.text('GPS location'), findsOneWidget);
    expect(find.textContaining('8.03100'), findsOneWidget);
    expect(c.read(incidentFormControllerProvider).locationSource,
        LocationSource.gps);
  });

  testWidgets('GPS failure surfaces the retry/manual card, never coordinates',
      (tester) async {
    when(() => location.getCurrentPosition()).thenThrow(Exception('no fix'));
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);

    await tester.tap(find.text('Use current GPS location'));
    await tester.pumpAndSettle();

    expect(find.text('No location set yet.'), findsOneWidget);
    expect(find.text('Retry GPS'), findsOneWidget);
    expect(find.text('Set manually'), findsOneWidget);
    final form = c.read(incidentFormControllerProvider);
    expect(form.hasLocation, isFalse); // never fabricated
    expect(form.gpsError, isNotNull);
  });

  testWidgets('manual entry stores the location with source = manual',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);

    await tester.tap(find.text('Set location manually'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, 'Latitude').last, '8.05');
    await tester.enterText(
        find.widgetWithText(TextField, 'Longitude').last, '80.91');
    await tester.pump();

    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    expect(find.text('Manual location'), findsOneWidget);
    final form = c.read(incidentFormControllerProvider);
    expect(form.locationSource, LocationSource.manual);
    expect(form.latitude, 8.05);
    expect(form.longitude, 80.91);
  });

  testWidgets('tapping the cached map stores a manual pin', (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);
    await tester.tap(find.text('Set location manually'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CachedParkMap));
    await tester.pump();
    await tester.tap(find.text('Confirm location'));
    await tester.pumpAndSettle();

    final form = c.read(incidentFormControllerProvider);
    expect(form.locationSource, LocationSource.manual);
    expect(form.hasLocation, isTrue);
    expect(form.latitude, isNotNull);
    expect(
      (form.latitude! - CachedParkMap.centerLatitude).abs(),
      lessThan(CachedParkMap.span),
    );
  });

  testWidgets('description is required: Review without it keeps you here',
      (tester) async {
    when(() => location.getCurrentPosition())
        .thenAnswer((_) async => (latitude: 8.031, longitude: 80.897));
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);

    await tester.tap(find.text('Use current GPS location'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Review report'));
    await tester.pump();

    expect(find.text('A description is required to continue.'), findsOneWidget);
    expect(find.text('Review Report'), findsNothing); // never navigated
  });

  testWidgets('description + location unlocks Review report', (tester) async {
    when(() => location.getCurrentPosition())
        .thenAnswer((_) async => (latitude: 8.031, longitude: 80.897));
    final c = container();
    addTearDown(c.dispose);

    await pump(tester, c);

    await tester.tap(find.text('Use current GPS location'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('description-field')), 'Wire snare found');
    await tester.pump();

    await tester.tap(find.text('Review report'));
    await tester.pumpAndSettle();

    expect(find.text('Review Report'), findsOneWidget);
    expect(find.text('Wire snare found'), findsOneWidget);
  });
}
