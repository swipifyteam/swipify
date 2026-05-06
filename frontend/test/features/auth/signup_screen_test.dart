// ============================================================
// test/features/auth/signup_screen_test.dart
// Widget tests for the Signup screen UI and form.
// ============================================================
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/features/auth/screen/signup_screen.dart';
import '../../helpers/app_wrapper.dart';

void main() {
  setUpAll(disableFontFetching);

  group('SignupScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      expect(find.byType(SignupScreen), findsOneWidget);
    });

    testWidgets('shows Swipify logo/icon', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
    });

    testWidgets('shows four TextFormFields (name, email, password, confirm)', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      expect(find.byType(TextFormField), findsNWidgets(4));
    });

    testWidgets('shows CREATE ACCOUNT button', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      expect(find.widgetWithText(ElevatedButton, 'CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('shows Log In navigation text', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      expect(find.text('Log In'), findsOneWidget);
    });

    testWidgets('can enter text into name field', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(0), 'John Doe');
      expect(find.text('John Doe'), findsOneWidget);
    });

    testWidgets('can enter text into email field', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).at(1), 'john@example.com');
      expect(find.text('john@example.com'), findsOneWidget);
    });

    testWidgets('passwords fields are obscured', (tester) async {
      await tester.pumpWidget(testApp(const SignupScreen()));
      await tester.pump();
      
      final passwordField = tester.widget<TextField>(find.byType(TextField).at(2));
      final confirmField = tester.widget<TextField>(find.byType(TextField).at(3));
      
      expect(passwordField.obscureText, isTrue);
      expect(confirmField.obscureText, isTrue);
    });
  });
}
