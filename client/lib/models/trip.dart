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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Trip) return false;
    return id == other.id &&
        name == other.name &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        notes == other.notes &&
        imageUrl == other.imageUrl &&
        _listEquals(accommodations, other.accommodations) &&
        _listEquals(flights, other.flights) &&
        _listEquals(activities, other.activities);
  }

  @override
  int get hashCode => Object.hash(
        id,
        name,
        startDate,
        endDate,
        notes,
        imageUrl,
        accommodations?.length,
        flights?.length,
        activities?.length,
      );

  static bool _listEquals(List<dynamic>? a, List<dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] is Map && b[i] is Map) {
        if (!_mapEquals(a[i] as Map, b[i] as Map)) return false;
      } else if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  static bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
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
  /// Returns a list of location parts (e.g. ['San Diego', 'CA', 'USA']) for hierarchical matching.
  /// If [selectedDay] is provided, returns the last location on that day.
  /// Otherwise returns the first location in the trip.
  List<String>? primaryPlace([DateTime? selectedDay]) {
    List<String>? extractLocationParts(String? address) {
      if (address == null || address.isEmpty) return null;
      final parts = address
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      // Take last 3 parts (e.g. "San Diego, CA, USA")
      final start = parts.length > 3 ? parts.length - 3 : 0;
      return parts.sublist(start);
    }

    // Build unified list of entries with dateTime and location parts
    final entries = <({DateTime dateTime, List<String> locationParts})>[];

    // Add accommodations as two entries (checkIn and checkOut)
    if (accommodations != null) {
      for (final a in accommodations!) {
        final acc = a as Map<String, dynamic>;
        final locationParts = extractLocationParts(acc['address'] as String?);
        if (locationParts == null) continue;

        final checkIn = DateTime.tryParse(acc['checkIn'] as String? ?? '');
        if (checkIn != null) {
          entries.add((dateTime: checkIn, locationParts: locationParts));
        }

        final checkOut = DateTime.tryParse(acc['checkOut'] as String? ?? '');
        if (checkOut != null) {
          entries.add((dateTime: checkOut, locationParts: locationParts));
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
          entries.add((dateTime: arrivalTime, locationParts: [arrivalCity]));
        }
      }
    }

    // Add activities
    if (activities != null) {
      for (final a in activities!) {
        final activity = a as Map<String, dynamic>;
        final locationParts = extractLocationParts(
          activity['location'] as String?,
        );
        if (locationParts == null) continue;

        final date = DateTime.tryParse(activity['date'] as String? ?? '');
        if (date != null) {
          entries.add((dateTime: date, locationParts: locationParts));
        }
      }
    }

    if (entries.isEmpty) return null;

    // Sort all entries by dateTime
    entries.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    if (selectedDay == null) {
      // Return first entry's location parts
      return entries.first.locationParts;
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
      return onDay.last.locationParts;
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
      return before.last.locationParts;
    }

    return entries.first.locationParts;
  }
}
