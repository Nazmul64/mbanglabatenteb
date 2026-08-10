import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mbanglabatenteb/main.dart';

void main() {
  testWidgets('App basic initialization smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the title of the app is rendered somewhere or that it successfully pumps the main dashboard
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
