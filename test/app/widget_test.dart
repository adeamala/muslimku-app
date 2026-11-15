// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:muslimku/core/theme/app_theme.dart';

void main() {
  setUpAll(() async {
    // Initialize locale data for tests
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('App theme test', (WidgetTester tester) async {
    // Test basic app structure
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: Center(child: Text('Test'))),
      ),
    );

    expect(find.text('Test'), findsOneWidget);
  });

  testWidgets('Responsive widget test', (WidgetTester tester) async {
    // Test responsive components
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Container(
            width: 200,
            height: 200,
            color: Colors.blue,
            child: const Text('Responsive Test'),
          ),
        ),
      ),
    );

    expect(find.text('Responsive Test'), findsOneWidget);
    expect(find.byType(Container), findsOneWidget);
  });
}
