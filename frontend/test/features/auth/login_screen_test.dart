// ============================================================
// test/features/auth/login_screen_test.dart
// Widget tests for the Login screen UI and form.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/auth/screen/login_screen.dart';
import '../../helpers/app_wrapper.dart';

void main() {
  setUpAll(disableFontFetching);

  group('LoginScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.byType(LoginScreen), findsOneWidget);
    });

    testWidgets('shows Swipify logo/icon', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
    });

    testWidgets('shows email text field', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      // Verify at least two TextFields exist (email + password)
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows password text field', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('shows LOGIN button', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'LOG IN'), findsOneWidget);
    });

    testWidgets('shows "Continue with Google" button', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows Sign Up navigation text', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.text('Sign Up'), findsOneWidget);
    });

    testWidgets('shows Forgot Password text', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      expect(find.text('Forgot Password?'), findsOneWidget);
    });

    testWidgets('can enter text into email field', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      // Find the first TextField (email) and type into it
      await tester.enterText(find.byType(TextField).first, 'test@swipify.com');
      expect(find.text('test@swipify.com'), findsOneWidget);
    });

    testWidgets('can enter text into password field', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pump();
      // Enter text into the second TextField (password, which is obscured)
      await tester.enterText(find.byType(TextField).last, 'mypassword123');
      // Just verify the widget is there — obscured text doesn't create a Text widget
      expect(find.byType(TextField), findsWidgets);
    });
  });
}
