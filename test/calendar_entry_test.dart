import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:informatik_projekt/models/calendar_entry.dart';
import 'package:informatik_projekt/services/api_service.dart';

void main() {
  group('occursOn', () {
    final birthday = CalendarEntry(date: DateTime(2010, 5, 3), title: 'Lena');
    final leapBirthday = CalendarEntry(
      date: DateTime(2008, 2, 29),
      title: 'Tom',
    );

    test('repeats every year', () {
      expect(birthday.occursOn(DateTime(2026, 5, 3)), isTrue);
      expect(birthday.occursOn(DateTime(2031, 5, 3)), isTrue);
    });

    test('does not match other days', () {
      expect(birthday.occursOn(DateTime(2026, 5, 4)), isFalse);
      expect(birthday.occursOn(DateTime(2026, 6, 3)), isFalse);
    });

    test('Feb 29 stays on Feb 29 in leap years', () {
      expect(leapBirthday.occursOn(DateTime(2028, 2, 29)), isTrue);
      expect(leapBirthday.occursOn(DateTime(2028, 2, 28)), isFalse);
    });

    test('Feb 29 moves to Feb 28 in other years', () {
      expect(leapBirthday.occursOn(DateTime(2027, 2, 28)), isTrue);
      expect(leapBirthday.occursOn(DateTime(2027, 3, 1)), isFalse);
    });
  });

  group('getCalendarEntries', () {
    Future<List<CalendarEntry>> load(http.Client client) {
      return http.runWithClient(
        () => ApiService().getCalendarEntries('family-1'),
        () => client,
      );
    }

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      FlutterSecureStorage.setMockInitialValues({'token': 'test-token'});
    });

    test('loads the members of the family and skips missing dates', () async {
      late http.Request request;
      final entries = await load(
        MockClient((incoming) async {
          request = incoming;
          return http.Response(
            jsonEncode([
              {'displayName': 'Lena', 'birthDate': '2010-05-03'},
              {'displayName': 'Tom', 'birthDate': null},
            ]),
            200,
          );
        }),
      );

      expect(request.url.path, endsWith('/users/family/family-1'));
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(entries, hasLength(1));
      expect(entries.single.title, 'Geburtstag Lena');
      expect(entries.single.date, DateTime(2010, 5, 3));
    });

    test('throws if the backend answers with an error', () {
      expect(
        load(MockClient((_) async => http.Response('', 404))),
        throwsException,
      );
    });
  });
}
