// ============================================================
// test/features/categories_screen_test.dart
// Widget tests for CategoriesScreen layout.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/navigation/categories_screen.dart';
import '../helpers/app_wrapper.dart';

void main() {
  setUpAll(disableFontFetching);

  group('CategoriesScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const CategoriesScreen()));
      await tester.pump();
      expect(find.byType(CategoriesScreen), findsOneWidget);
    });

    testWidgets('shows app bar with title', (tester) async {
      await tester.pumpWidget(testApp(const CategoriesScreen()));
      await tester.pump();
      expect(find.text('Shop by Category'), findsOneWidget);
    });

    testWidgets('renders a Scaffold', (tester) async {
      await tester.pumpWidget(testApp(const CategoriesScreen()));
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows loading indicator initially', (tester) async {
      await tester.pumpWidget(testApp(const CategoriesScreen()));
      // Before data loads, a progress indicator should be shown
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows text widgets after pump', (tester) async {
      await tester.pumpWidget(testApp(const CategoriesScreen()));
      await tester.pump();
      expect(find.byType(Text), findsWidgets);
    });
  });
}
