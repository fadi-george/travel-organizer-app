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

  bool get isUpcoming {
    final start = DateTime.parse(startDate);
    return start.isAfter(DateTime.now());
  }

  bool get isPast {
    final end = DateTime.parse(endDate);
    return end.isBefore(DateTime.now());
  }

  /// Get the first accommodation's country
  String? get primaryCountry {
    if (accommodations == null || accommodations!.isEmpty) return null;
    final sorted =
        List<Map<String, dynamic>>.from(
          accommodations!.map((a) => a as Map<String, dynamic>),
        )..sort((a, b) {
          final aDate = a['checkIn'] as String? ?? '';
          final bDate = b['checkIn'] as String? ?? '';
          return aDate.compareTo(bDate);
        });
    return sorted.first['country'] as String?;
  }
}
