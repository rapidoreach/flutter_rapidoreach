import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rapidoreach_example/main.dart';

void main() {
  testWidgets('renders the RapidoReach Flutter SDK smoke test dashboard',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('RapidoReach SDK Smoke Test (Flutter)'), findsOneWidget);
    expect(find.text('Initialize'), findsOneWidget);
    expect(find.text('Open Offerwall'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard), findsOneWidget);
  });
}
