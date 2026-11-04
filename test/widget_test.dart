import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:informatik_projekt/main.dart';

void main() {
  testWidgets('App builds and shows the join-family scan button', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // The main page renders the header and the prominent scan entry point.
    expect(find.text('Family App Hub'), findsOneWidget);
    expect(find.text('Families'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Scan QR Code to Join a Family'), findsOneWidget);
    expect(find.byIcon(Icons.qr_code_scanner), findsOneWidget);
  });
}
