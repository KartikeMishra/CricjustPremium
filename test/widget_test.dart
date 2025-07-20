import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/main.dart';

void main() {
  testWidgets('App launches and renders MaterialApp', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    // Verify MaterialApp is present
    expect(find.byType(MaterialApp), findsOneWidget);

    // Optional: Check if SplashScreen is the first screen
    expect(find.text('Welcome to Cricjust'), findsOneWidget);
  });
}
