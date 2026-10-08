import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  // UC02 Screen 2 – Evidence (photo OR omission reason).
  ProviderContainer container() => ProviderContainer(overrides: [
        appDatabaseProvider.overrideWith((ref) => createIncidentTestDatabase()),
      ]);

  testWidgets('photo accepted: reason field disappears once a photo exists',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);
    c.read(incidentFormControllerProvider.notifier).setEvidence(
          CapturedEvidence(
            localPath: 'C:/nonexistent/photo.jpg',
            filename: 'photo.jpg',
            bytes: Uint8List.fromList(const [
              0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00,
              0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00,
              0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
              0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63,
              0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4,
              0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60,
              0x82,
            ]),
          ),
        );

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    // The photo slot renders with a retake action (the file itself does not
    // exist in the test environment, so the image shows its error frame).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(find.byKey(const Key('omission-reason-field')), findsNothing);
    expect(find.text("Can't take a photo safely?"), findsNothing);
  });

  testWidgets('no photo: omission reason field is offered', (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    expect(find.text("Can't take a photo safely?"), findsOneWidget);
    expect(find.byKey(const Key('omission-reason-field')), findsOneWidget);
  });

  testWidgets('neither photo nor reason: Next shows validation snackbar',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Add a photo or a reason for taking none to continue.'),
        findsOneWidget);
    expect(find.text('Location & Description'), findsNothing);
  });

  testWidgets('omission reason alone unblocks Next (no photo required)',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    await tester.enterText(
        find.byKey(const Key('omission-reason-field')),
        'Unsafe to approach the snare location.');
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text('Location & Description'), findsOneWidget);
    expect(
      c.read(incidentFormControllerProvider).evidence.omissionReason,
      'Unsafe to approach the snare location.',
    );
  });

  testWidgets('blank omission reason does not count as a reason',
      (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    await tester.enterText(
        find.byKey(const Key('omission-reason-field')), '   ');
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Add a photo or a reason for taking none to continue.'),
        findsOneWidget);
  });

  testWidgets('camera and gallery actions are offered', (tester) async {
    final c = container();
    addTearDown(c.dispose);

    await pumpUc02Screen(tester, const SizedBox.shrink(), container: c,
        initialLocation: AppRoutes.incidentEvidence);

    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Gallery'), findsOneWidget);
  });
}
