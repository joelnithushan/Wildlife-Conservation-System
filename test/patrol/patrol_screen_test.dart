import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/features/patrol/presentation/screens/patrol_screen.dart';

void main() {
  testWidgets('PatrolScreen renders title and FAB', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: PatrolScreen(),
        ),
      ),
    );

    expect(find.text('Patrol Operations'), findsOneWidget);
    expect(find.text('Start Patrol'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });
}
