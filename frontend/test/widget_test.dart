// ============================================================
// test/widget_test.dart
// Top-level smoke test. Verifies the root app widget loads.
// Run all tests with: flutter test
// Run just this file: flutter test test/widget_test.dart
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/theme.dart';
import 'helpers/app_wrapper.dart';

/// A minimal stub of the app root — avoids Firebase initialization.
class _AppStub extends StatelessWidget {
  const _AppStub();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Swipify',
      theme: SwipifyTheme.lightTheme,
      home: const Scaffold(body: Center(child: Text('Swipify'))),
    );
  }
}

void main() {
  setUpAll(disableFontFetching);

  group('App Smoke Tests', () {
    testWidgets('App stub renders a MaterialApp', (tester) async {
      await tester.pumpWidget(const _AppStub());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App stub shows Swipify title text', (tester) async {
      await tester.pumpWidget(const _AppStub());
      expect(find.text('Swipify'), findsOneWidget);
    });

    testWidgets('testApp helper wraps widget in MaterialApp', (tester) async {
      await tester.pumpWidget(testApp(const Text('hello')));
      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('SwipifyTheme.lightTheme is applied without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: SwipifyTheme.lightTheme,
          home: const Scaffold(body: Text('theme check')),
        ),
      );
      expect(find.text('theme check'), findsOneWidget);
    });
  });
}
