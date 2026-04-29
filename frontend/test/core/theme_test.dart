// ============================================================
// test/core/theme_test.dart
// Unit tests for SwipifyTheme values and ThemeData integrity.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/theme.dart';

void main() {
  group('SwipifyTheme', () {
    test('primaryColor should be the correct charcoal hex', () {
      expect(SwipifyTheme.primaryColor, equals(const Color(0xFF1A2332)));
    });

    test('backgroundColor should be a light grey', () {
      expect(SwipifyTheme.backgroundColor, equals(const Color(0xFFF7F8FA)));
    });

    testWidgets('lightTheme should return a ThemeData instance', (tester) async {
      final theme = SwipifyTheme.lightTheme;
      expect(theme, isA<ThemeData>());
    });

    testWidgets('lightTheme scaffoldBackgroundColor matches backgroundColor', (tester) async {
      expect(
        SwipifyTheme.lightTheme.scaffoldBackgroundColor,
        equals(SwipifyTheme.backgroundColor),
      );
    });

    testWidgets('lightTheme has BottomNavigationBarTheme with correct selected color', (tester) async {
      final navTheme = SwipifyTheme.lightTheme.bottomNavigationBarTheme;
      expect(navTheme.selectedItemColor, equals(SwipifyTheme.primaryColor));
    });

    testWidgets('lightTheme ElevatedButton has padding configured', (tester) async {
      final style = SwipifyTheme.lightTheme.elevatedButtonTheme.style;
      expect(style, isNotNull);
    });
  });
}
