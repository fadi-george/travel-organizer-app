import 'package:flutter/material.dart';

class DaysCarousel extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, int> eventCounts;

  const DaysCarousel({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.selectedDate,
    required this.onDateSelected,
    this.eventCounts = const {},
  });

  List<DateTime> get _tripDays {
    final days = <DateTime>[];
    var current = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    while (!current.isAfter(end)) {
      days.add(current);
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  String _dayName(DateTime date) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[date.weekday - 1];
  }

  String _monthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _getEventCount(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return eventCounts[normalized] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final days = _tripDays;
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Month/Year header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            _monthYear(selectedDate),
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Days carousel - pad to 7 days minimum
        SizedBox(
          height: 64,
          child: Builder(
            builder: (context) {
              // Calculate padding days to fill to 7 (only after, not before startDate)
              const minDays = 7;
              final paddingAfter = (minDays - days.length).clamp(0, minDays);
              final totalItems = days.length + paddingAfter;

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 0),
                itemCount: totalItems,
                itemBuilder: (context, index) {
                  // Determine if this is a padding day (only after real days)
                  final isPaddingDay = index >= days.length;

                  if (isPaddingDay) {
                    // Fake day - calculate the date after the trip
                    final fakeDay = days.last.add(
                      Duration(days: index - days.length + 1),
                    );
                    return _buildDayItem(
                      context,
                      fakeDay,
                      isSelected: false,
                      isToday: false,
                      eventCount: 0,
                      isDisabled: true,
                      colorScheme: colorScheme,
                    );
                  }

                  final day = days[index];
                  final isSelected = _isSameDay(day, selectedDate);
                  final eventCount = _getEventCount(day);
                  final isToday = _isSameDay(day, DateTime.now());

                  return GestureDetector(
                    onTap: () => onDateSelected(day),
                    child: _buildDayItem(
                      context,
                      day,
                      isSelected: isSelected,
                      isToday: isToday,
                      eventCount: eventCount,
                      isDisabled: false,
                      colorScheme: colorScheme,
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDayItem(
    BuildContext context,
    DateTime day, {
    required bool isSelected,
    required bool isToday,
    required int eventCount,
    required bool isDisabled,
    required ColorScheme colorScheme,
  }) {
    final opacity = isDisabled ? 0.3 : 1.0;

    return Container(
      width: 46,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      child: Opacity(
        opacity: opacity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day name (MON, TUE, etc.)
            Text(
              _dayName(day),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFFFF7043)
                    : colorScheme.onSurface.withValues(
                        alpha: isDisabled ? 0.8 : 0.5,
                      ),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            // Day number with selection indicator
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF7043).withValues(alpha: 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: isToday && !isSelected
                    ? Border.all(color: const Color(0xFFFF7043), width: 1.5)
                    : null,
              ),
              child: Center(
                child: Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? const Color(0xFFFF7043)
                        : colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Event indicators
            SizedBox(
              height: 5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  eventCount.clamp(0, 3),
                  (i) => Container(
                    width: 4,
                    height: 4,
                    margin: EdgeInsets.only(left: i > 0 ? 2 : 0),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7043)
                          : Colors.blue.shade400,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper to calculate the default selected date
  static DateTime getDefaultSelectedDate(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);

    // If today is within the trip range, select today
    if (!today.isBefore(start) && !today.isAfter(end)) {
      return today;
    }
    // Otherwise, select the first day of the trip
    return start;
  }
}
