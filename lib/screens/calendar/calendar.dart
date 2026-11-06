import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../models/calendar_entry.dart';
import '../../services/api_service.dart';

class Calendar extends StatefulWidget {
  const Calendar({
    super.key,
    this.familyId,
    this.entries = const [],
    this.today,
    this.apiService,
  });

  /// Without a family id, nothing is loaded from the backend.
  final String? familyId;

  /// Entries that are shown in addition to the loaded ones.
  final List<CalendarEntry> entries;

  final DateTime? today;

  /// Replaced in tests, so they don't need a backend.
  final ApiService? apiService;

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  // intl would render "Mo." in German, the design has no dot.
  static const _weekdayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

  DateTime? _focusedDay;
  DateTime? _selectedDay;
  List<CalendarEntry> _loadedEntries = [];

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final familyId = widget.familyId;
    if (familyId == null) return;

    try {
      final apiService = widget.apiService ?? ApiService();
      final entries = await apiService.getCalendarEntries(familyId);
      if (!mounted) return;
      setState(() {
        _loadedEntries = entries;
      });
    } catch (error) {
      // The calendar stays usable, it just has no entries.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Geburtstage konnten nicht geladen werden.'),
        ),
      );
    }
  }

  List<CalendarEntry> _entriesOn(DateTime day) {
    return [
      ...widget.entries,
      ..._loadedEntries,
    ].where((entry) => entry.occursOn(day)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDay;
    final selectedEntries = selectedDay == null
        ? <CalendarEntry>[]
        : _entriesOn(selectedDay);

    // Space at the sides, and a limit for very wide windows.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCalendar(context),
                for (final entry in selectedEntries)
                  ListTile(
                    leading: const Icon(Icons.cake_outlined),
                    title: Text(entry.title),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final today = widget.today ?? DateTime.now();

    return TableCalendar<void>(
      locale: 'de_DE',
      firstDay: DateTime.utc(2020),
      lastDay: DateTime.utc(2100),
      focusedDay: _focusedDay ?? today,
      currentDay: today,
      startingDayOfWeek: StartingDayOfWeek.monday,
      // Six rows fit every month, so the height never jumps.
      sixWeekMonthsEnforced: true,
      rowHeight: 60,
      daysOfWeekHeight: 32,
      availableGestures: AvailableGestures.horizontalSwipe,
      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      headerStyle: HeaderStyle(
        titleCentered: true,
        formatButtonVisible: false,
        titleTextStyle: (textTheme.titleMedium ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, _) => _weekdayNames[date.weekday - 1],
        weekdayStyle: const TextStyle(fontWeight: FontWeight.w700),
        weekendStyle: const TextStyle(fontWeight: FontWeight.w700),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
      ),
      calendarBuilders: CalendarBuilders(
        // Replaces every cell type of the package (today, outside days, ...).
        prioritizedBuilder: (context, day, focusedDay) => _DayCell(
          day: day,
          isOutside: day.month != focusedDay.month,
          isToday: isSameDay(day, today),
          isSelected: isSameDay(day, _selectedDay),
          hasEvent: _entriesOn(day).isNotEmpty,
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isOutside,
    required this.isToday,
    required this.isSelected,
    required this.hasEvent,
  });

  final DateTime day;
  final bool isOutside;
  final bool isToday;
  final bool isSelected;
  final bool hasEvent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = BorderSide(color: colors.outlineVariant);

    return Container(
      constraints: const BoxConstraints.expand(),
      decoration: BoxDecoration(
        // Days of other months get a grey cell and lighter text.
        color: isSelected
            ? colors.secondaryContainer
            : isOutside
            ? colors.surfaceContainerLow
            : null,
        border: Border(right: border, bottom: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: isToday && !isOutside
                ? BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.onSurface, width: 1.5),
                  )
                : null,
            child: Text(
              '${day.day}',
              style: TextStyle(
                color: isOutside
                    ? colors.onSurface.withValues(alpha: 0.4)
                    : colors.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Reserves the space, so numbers don't shift with a dot.
          Container(
            key: hasEvent ? const ValueKey('event-dot') : null,
            width: 6,
            height: 6,
            decoration: hasEvent
                ? BoxDecoration(shape: BoxShape.circle, color: colors.error)
                : null,
          ),
        ],
      ),
    );
  }
}
