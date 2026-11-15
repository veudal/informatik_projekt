/// One entry of the calendar. For now these are only birthdays.
class CalendarEntry {
  final DateTime date;
  final String title;

  CalendarEntry({required this.date, required this.title});

  factory CalendarEntry.fromMember(Map<String, dynamic> json) {
    return CalendarEntry(
      date: DateTime.parse(json['birthDate'].toString()),
      title: 'Geburtstag ${json['displayName']}',
    );
  }

  /// Birthdays repeat every year, so the year of [date] doesn't matter.
  bool occursOn(DateTime day) {
    // DateTime turns Feb 29 into Mar 1 if the year is no leap year.
    final isLeapYear = DateTime(day.year, 2, 29).month == 2;
    if (date.month == 2 && date.day == 29 && !isLeapYear) {
      return day.month == 2 && day.day == 28;
    }
    return date.month == day.month && date.day == day.day;
  }
}
