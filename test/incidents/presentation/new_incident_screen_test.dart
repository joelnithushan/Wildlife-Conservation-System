import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';

import '../helpers.dart';

void main() {
  // UC02 Screen 1 – New Incident Report (category selection).
  testWidgets('shows all five incident categories', (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    expect(find.text('New Incident Report'), findsOneWidget);
    for (final category in IncidentReportCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }
    expect(find.text('Snare'), findsOneWidget);
    expect(find.text('Carcass'), findsOneWidget);
    expect(find.text('Illegal campsite'), findsOneWidget);
    expect(find.text('Suspicious footprints'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);
  });

  testWidgets('Next without a category shows the validation message',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Select a category to continue.'), findsOneWidget);
    expect(find.text('Evidence'), findsNothing); // never navigated
  });

  testWidgets('selecting a category stores it and Next advances to Evidence',
      (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    await tester.tap(find.text('Carcass'));
    await tester.pump();
    expect(
      container.read(incidentFormControllerProvider).category,
      IncidentReportCategory.carcass,
    );

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Evidence'), findsOneWidget); // screen 2 reached
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
  });

  testWidgets('re-selecting replaces the previous category', (tester) async {
    final container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
    ]);
    addTearDown(container.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: container,
        initialLocation: AppRoutes.newIncident);

    await tester.tap(find.text('Snare'));
    await tester.pump();
    await tester.tap(find.text('Other'));
    await tester.pump();

    expect(container.read(incidentFormControllerProvider).category,
        IncidentReportCategory.other);
  });
}
