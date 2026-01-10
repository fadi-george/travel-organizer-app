class Trip {
  final String id;
  final String name;
  final String startDate;
  final String endDate;
  final String? notes;
  final String? imageUrl;
  final List<dynamic>? accommodations;
  final List<dynamic>? flights;
  final List<dynamic>? activities;

  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.notes,
    this.imageUrl,
    this.accommodations,
    this.flights,
    this.activities,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['_id'] as String,
      name: json['name'] as String,
      startDate: json['startDate'] as String,
      endDate: json['endDate'] as String,
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      accommodations: json['accommodations'] as List<dynamic>?,
      flights: json['flights'] as List<dynamic>?,
      activities: json['activities'] as List<dynamic>?,
    );
  }

  String get formattedDateRange {
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final startStr = '${months[start.month - 1]} ${start.day}';
    final endStr = '${months[end.month - 1]} ${end.day}';
    return '$startStr → $endStr';
  }

  String get daysUntilTrip {
    final start = DateTime.parse(startDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tripDate = DateTime(start.year, start.month, start.day);
    final difference = tripDate.difference(today).inDays;

    if (difference < 0) {
      return '${-difference} days ago';
    } else if (difference == 0) {
      return 'Today!';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return 'In $difference days';
    }
  }

  bool get isActive {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.parse(startDate);
    final end = DateTime.parse(endDate);
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    return !startDay.isAfter(today) && !endDay.isBefore(today);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime.parse(startDate);
    final startDay = DateTime(start.year, start.month, start.day);
    return startDay.isAfter(today);
  }

  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime.parse(endDate);
    final endDay = DateTime(end.year, end.month, end.day);
    return endDay.isBefore(today);
  }

  /// Get the primary location from combined accommodations, flights, and activities
  /// If [selectedDay] is provided, returns the last location on that day
  /// Otherwise returns the first location in the trip
  String? primaryPlace([DateTime? selectedDay]) {
    String? extractLocation(String? address) {
      if (address == null || address.isEmpty) return null;
      final parts = address.split(',').map((p) => p.trim()).toList();
      final location = parts.last;
      return location.isNotEmpty ? location : null;
    }

    // Build unified list of entries with dateTime and location
    final entries = <({DateTime dateTime, String location})>[];

    // Add accommodations as two entries (checkIn and checkOut)
    if (accommodations != null) {
      for (final a in accommodations!) {
        final acc = a as Map<String, dynamic>;
        final location = extractLocation(acc['address'] as String?);
        if (location == null) continue;

        final checkIn = DateTime.tryParse(acc['checkIn'] as String? ?? '');
        if (checkIn != null) {
          entries.add((dateTime: checkIn, location: location));
        }

        final checkOut = DateTime.tryParse(acc['checkOut'] as String? ?? '');
        if (checkOut != null) {
          entries.add((dateTime: checkOut, location: location));
        }
      }
    }

    // Add flights using arrival time
    if (flights != null) {
      for (final f in flights!) {
        final flight = f as Map<String, dynamic>;
        final arrivalCity = flight['arrivalCity'] as String?;
        if (arrivalCity == null || arrivalCity.isEmpty) continue;

        final arrivalTime = DateTime.tryParse(
          flight['arrivalTime'] as String? ?? '',
        );
        if (arrivalTime != null) {
          entries.add((dateTime: arrivalTime, location: arrivalCity));
        }
      }
    }

    // Add activities
    if (activities != null) {
      for (final a in activities!) {
        final activity = a as Map<String, dynamic>;
        final location = extractLocation(activity['location'] as String?);
        if (location == null) continue;

        final date = DateTime.tryParse(activity['date'] as String? ?? '');
        if (date != null) {
          entries.add((dateTime: date, location: location));
        }
      }
    }

    if (entries.isEmpty) return null;

    // Sort all entries by dateTime
    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (selectedDay == null) {
      // Return first entry's location
      return entries.first.location;
    }

    // Filter entries to those on selectedDay, return last one's location
    final selectedDayOnly = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final onDay = entries.where((e) {
      final entryDay = DateTime(
        e.dateTime.year,
        e.dateTime.month,
        e.dateTime.day,
      );
      return entryDay == selectedDayOnly;
    }).toList();

    if (onDay.isNotEmpty) {
      return onDay.last.location;
    }

    // Fallback: get last entry before selectedDay
    final before = entries.where((e) {
      final entryDay = DateTime(
        e.dateTime.year,
        e.dateTime.month,
        e.dateTime.day,
      );
      return entryDay.isBefore(selectedDayOnly);
    }).toList();

    if (before.isNotEmpty) {
      return before.last.location;
    }

    return entries.first.location;
  }
}
