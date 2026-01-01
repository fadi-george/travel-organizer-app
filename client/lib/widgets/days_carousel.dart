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
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
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
    final days = _tripDays;
    if (days.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month/Year header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _monthYear(selectedDate),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Days carousel
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              final isSelected = _isSameDay(day, selectedDate);
              final eventCount = _getEventCount(day);
              final isToday = _isSameDay(day, DateTime.now());

              return GestureDetector(
                onTap: () => onDateSelected(day),
                child: Container(
                  width: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Day name (MON, TUE, etc.)
                      Text(
                        _dayName(day),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFFF7043)
                              : Colors.grey.shade500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Day number with selection indicator
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFFF7043).withValues(alpha: 0.15)
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: isToday && !isSelected
                              ? Border.all(
                                  color: const Color(0xFFFF7043),
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${day.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? const Color(0xFFFF7043)
                                  : Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Event indicators
                      SizedBox(
                        height: 6,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            eventCount.clamp(0, 3),
                            (i) => Container(
                              width: 5,
                              height: 5,
                              margin: EdgeInsets.only(left: i > 0 ? 3 : 0),
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
            },
          ),
        ),
      ],
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

