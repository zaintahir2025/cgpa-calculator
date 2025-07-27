import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cgpa_calculator/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isDarkMode: false));
    expect(find.text('CGPA Calculator'), findsOneWidget);
  });

  testWidgets('Add semester button works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isDarkMode: false));

    // Verify initial state
    expect(find.text('Semester 1'), findsOneWidget);
    expect(find.text('Semester 2'), findsNothing);

    // Tap the add semester button
    await tester.tap(find.text('Add Semester'));
    await tester.pump();

    // Verify new semester was added
    expect(find.text('Semester 1'), findsOneWidget);
    expect(find.text('Semester 2'), findsOneWidget);
  });

  testWidgets('Theme switching works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isDarkMode: false));

    // Verify initial theme
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, isNot(Colors.grey[900]));

    // Tap the theme toggle button
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pump();

    // Verify theme changed
    final updatedAppBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(
        updatedAppBar.backgroundColor, isNot(equals(appBar.backgroundColor)));
  });
}
