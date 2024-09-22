import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smsgalaxy/main.dart';

void main() {
  testWidgets('SMS Panel form test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SmsPanelApp());

    // Verify that the app displays the required form fields.
    expect(find.text('Enter Verification Code'), findsOneWidget);
    expect(find.text('Enter Phone Number to forward SMS'), findsOneWidget);

    // Verify that the dropdown for SIM selection is available.
    expect(find.text('Select SIM Card'), findsOneWidget);

    // Enter a verification code and phone number.
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.enterText(find.byType(TextField).last, '09120000000');

    // Tap the 'Start' button and trigger a frame.
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Verify that the 'Start' button is disabled after starting.
    expect(find.text('Running...'), findsOneWidget);
  });
}
