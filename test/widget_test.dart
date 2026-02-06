import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cgpa_calculator/main.dart'; // Ensure 'cgpa_calculator' matches your pubspec.yaml name

void main() {
  testWidgets('App loads and displays title', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp(isDarkMode: false));

    // Verify that the AppBar title "GPA Calculator" is present.
    expect(find.text('GPA Calculator'), findsOneWidget);

    // Verify that the empty state text is present initially.
    expect(find.text('No Records Found'), findsOneWidget);

    // Verify that the floating action button exists.
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });
}
