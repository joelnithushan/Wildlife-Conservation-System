import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/incidents/domain/incident_categories.dart';

import '../helpers.dart';

void main() {
  // UC02 Screen 4 – Review report before submission.
  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
      ]);

  void fillForm(ProviderContainer c) {
    final controller = c.read(incidentFormControllerProvider.notifier);
    controller.selectCategory(IncidentReportCategory.snare);
    controller.setOmissionReason('Unsafe to approach the snare location.');
    controller.setManualLocation(8.03, 80.89);
    controller.setDescription('Wire snare near the river crossing');
    controller.bindPatrol('patrol-active');
  }

  testWidgets('shows every captured detail and enables Submit when complete',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);
    fillForm(c);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentReview);

    expect(find.text('Review Report'), findsOneWidget);
    expect(find.text('Snare'), findsOneWidget);
    expect(
        find.text('Unsafe to approach the snare location.'), findsOneWidget);
    expect(find.textContaining('8.03000'), findsOneWidget);
    expect(find.textContaining('Manual'), findsOneWidget);
    expect(find.text('Wire snare near the river crossing'), findsOneWidget);
    expect(find.text('Missing:'), findsNothing);

    final submitFinder = find.widgetWithText(FilledButton, 'Submit Report');
    expect(submitFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNotNull);
  });

  testWidgets('missing data is highlighted and Submit is disabled',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);
    final controller = c.read(incidentFormControllerProvider.notifier);
    controller.selectCategory(IncidentReportCategory.snare);
    // No evidence, no location, no description.

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentReview);

    expect(find.textContaining('Missing: photo or omission reason, location, '
        'description'), findsOneWidget);
    expect(find.text('Missing – tap edit to fix'), findsNWidgets(3));

    final submitFinder = find.widgetWithText(FilledButton, 'Submit Report');
    expect(tester.widget<FilledButton>(submitFinder).onPressed, isNull);
  });

  testWidgets('submitting navigates to the result screen (offline path)',
      (tester) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
      connectivityServiceProvider
          .overrideWithValue(FakeConnectivityService(online: false)),
    ]);
    addTearDown(c.dispose);
    c.read(currentUserProvider.notifier).signIn(DemoData.rangerPerera);
    fillForm(c);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentReview);

    await tester.tap(find.text('Submit Report'));
    await tester.pumpAndSettle();

    // Submission succeeded locally: the result screen shows the offline state.
    expect(find.text('Report submitted'), findsOneWidget);
    expect(find.text('Offline – saved on this device. It will synchronize '
        'automatically when the signal returns.'), findsOneWidget);
    expect(find.textContaining('Reference: IR-'), findsOneWidget);
    expect(find.text('Retry sync now'), findsOneWidget);
  });
}
