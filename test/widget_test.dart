import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_app/main.dart';

void main() {
  testWidgets('Prospera app starts and shows splash or lock/home screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProsperaApp());
    await tester.pump();

    // App should build without throwing and show a MaterialApp.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
