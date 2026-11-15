import 'package:birth_picker/birth_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:informatik_projekt/models/calendar_entry.dart';
import 'package:informatik_projekt/screens/calendar/calendar.dart';
import 'package:informatik_projekt/services/api_service.dart';

void main() {
  final today = DateTime(2026, 11, 6);

  setUpAll(() => initializeDateFormatting('de_DE'));

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows German month, weekdays without dot and all days', (
    tester,
  ) async {
    await pump(tester, Calendar(today: today));

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('Mo'), findsOneWidget);
    expect(find.text('So'), findsOneWidget);
    // 30 also exists in the previous month, 31 only there.
    expect(find.text('30'), findsNWidgets(2));
    expect(find.text('31'), findsOneWidget);
  });

  testWidgets('shows days of other months in a lighter color', (tester) async {
    await pump(tester, Calendar(today: today));

    // 31 is from October, 15 from November.
    final outside = tester.widget<Text>(find.text('31')).style!.color!;
    final inside = tester.widget<Text>(find.text('15')).style!.color!;

    expect(outside.a, lessThan(inside.a));
  });

  testWidgets('shows one dot for a birthday, none otherwise', (tester) async {
    const dot = ValueKey('event-dot');

    await pump(tester, Calendar(today: today));
    expect(find.byKey(dot), findsNothing);

    await pump(
      tester,
      Calendar(today: today, entries: [birthday('Lena', 2010, 11, 12)]),
    );
    expect(find.byKey(dot), findsOneWidget);
  });

  testWidgets('always shows six rows, even in the shortest month', (
    tester,
  ) async {
    final cell = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DayCell',
    );

    // February 2027 starts on a Monday and would only need four rows.
    await pump(tester, Calendar(today: DateTime(2027, 2, 1)));

    expect(cell, findsNWidgets(6 * 7));
  });

  testWidgets('leaves space at the sides of a wide window', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(2000, 900);

    await pump(tester, Calendar(today: today));

    expect(tester.getSize(find.byType(Card)).width, lessThanOrEqualTo(1280));
  });

  testWidgets('switches month with the arrow', (tester) async {
    await pump(tester, Calendar(today: today));

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    expect(find.text('Dezember 2026'), findsOneWidget);
  });

  testWidgets('tapping a day with a birthday shows its name', (tester) async {
    await pump(
      tester,
      Calendar(today: today, entries: [birthday('Lena', 2010, 11, 12)]),
    );
    expect(find.text('Geburtstag Lena'), findsNothing);

    await tester.tap(find.text('12'));
    await tester.pumpAndSettle();

    expect(find.text('Geburtstag Lena'), findsOneWidget);
  });

  testWidgets('tapping a day without a birthday shows nothing', (tester) async {
    await pump(
      tester,
      Calendar(today: today, entries: [birthday('Lena', 2010, 11, 12)]),
    );

    await tester.tap(find.text('13'));
    await tester.pumpAndSettle();

    expect(find.text('Geburtstag Lena'), findsNothing);
  });

  testWidgets('has no plus button anymore', (tester) async {
    await pump(tester, Calendar(today: today));

    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('shows a dot for birthdays from the backend', (tester) async {
    await pump(
      tester,
      Calendar(
        today: today,
        familyId: 'family-1',
        apiService: _FakeApiService([birthday('Lena', 2010, 11, 12)]),
      ),
    );

    expect(find.byKey(const ValueKey('event-dot')), findsOneWidget);
  });

  testWidgets('stays usable if loading fails', (tester) async {
    await pump(
      tester,
      Calendar(
        today: today,
        familyId: 'family-1',
        apiService: _FakeApiService(null),
      ),
    );

    expect(find.text('November 2026'), findsOneWidget);
    expect(
      find.text('Geburtstage konnten nicht geladen werden.'),
      findsOneWidget,
    );
  });
}

CalendarEntry birthday(String name, int year, int month, int day) {
  return CalendarEntry(
    date: DateTime(year, month, day),
    title: 'Geburtstag $name',
  );
}

class _FakeApiService extends ApiService {
  _FakeApiService(this.entries);

  /// Null lets loading fail.
  final List<CalendarEntry>? entries;

  @override
  Future<List<CalendarEntry>> getCalendarEntries(String familyId) async {
    final result = entries;
    if (result == null) throw Exception('No backend');
    return result;
  }
}
