import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wildlife_conservation_system/app.dart';

void main() {
  testWidgets('WildlifeApp renders without crashing', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: WildlifeApp(),
      ),
    );
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
