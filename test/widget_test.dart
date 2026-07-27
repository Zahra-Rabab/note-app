// Basic smoke test: the app launches and shows the lists screen.
//
// Note: this app talks to a local backend and sqflite (native database) for
// real functionality, so this test intentionally only checks that the UI
// builds without crashing — it doesn't exercise networking or the database,
// which need platform bindings that plain `flutter test` doesn't provide.
// Treat this as a starting point, not full coverage.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:grocery_price_app/providers/lists_provider.dart';
import 'package:grocery_price_app/screens/lists_screen.dart';

void main() {
  testWidgets('Shows the lists screen and add button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ListsProvider(),
        child: const MaterialApp(home: ListsScreen()),
      ),
    );

    expect(find.text('My Lists'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
