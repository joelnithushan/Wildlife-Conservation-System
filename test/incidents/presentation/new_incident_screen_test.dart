import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';

import '../helpers.dart';

void main() {
  testWidgets('start screen shows patrol context and incident examples',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    expect(find.text('New Field Incident'), findsOneWidget);
    expect(find.text('Report Field Incident'), findsOneWidget);
    expect(find.text('Snare'), findsOneWidget);
    expect(find.text('Carcass'), findsOneWidget);
    expect(find.text('Illegal Campsite'), findsOneWidget);
    expect(find.text('Footprints'), findsOneWidget);
    expect(find.text('Start Report'), findsOneWidget);
  });

  testWidgets('Start Report opens incident type selection', (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    await tester.tap(find.text('Start Report'));
    await tester.pumpAndSettle();

    expect(find.text('What did you find?'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('Continue without a type shows the validation message',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.incidentType);

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(find.text('Select a category to continue.'), findsOneWidget);
    expect(find.text('Incident Photo'), findsNothing);
  });

  testWidgets('selecting a type stores it and Continue opens the photo step',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.incidentType);

    await tester.tap(find.text('Carcass'));
    await tester.pump();
    expect(
      container.read(incidentFormControllerProvider).category,
      IncidentReportCategory.carcass,
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Incident Photo'), findsOneWidget);
    expect(find.text('Capture Photo'), findsOneWidget);
  });

  testWidgets('re-selecting replaces the previous type', (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.incidentType);

    await tester.tap(find.text('Snare'));
    await tester.pump();
    await tester.tap(find.text('Other'));
    await tester.pump();

    expect(container.read(incidentFormControllerProvider).category,
        IncidentReportCategory.other);
  });
}
