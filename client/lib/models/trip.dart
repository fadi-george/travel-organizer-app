class Trip {
  final String id;
  final String name;
  final String? startDate;
  final String? endDate;
  final String? notes;
  final String? imageUrl;
  final List<dynamic>? destinations;

  const Trip({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.notes,
    this.imageUrl,
    this.destinations,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['_id'] as String,
      name: json['name'] as String,
      startDate: json['startDate'] as String?,
      endDate: json['endDate'] as String?,
      notes: json['notes'] as String?,
      imageUrl: json['imageUrl'] as String?,
      destinations: json['destinations'] as List<dynamic>?,
    );
  }

  String get formattedDateRange {
    if (startDate == null) return 'No dates set';
    final start = DateTime.tryParse(startDate!);
    final end = endDate != null ? DateTime.tryParse(endDate!) : null;

    if (start == null) return 'No dates set';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    final startStr = '${months[start.month - 1]} ${start.day}';
    if (end == null) return startStr;

    final endStr = '${months[end.month - 1]} ${end.day}';
    return '$startStr → $endStr';
  }

  String? get daysUntilTrip {
    if (startDate == null) return null;
    final start = DateTime.tryParse(startDate!);
    if (start == null) return null;

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
    if (startDate == null) return false;
    final start = DateTime.tryParse(startDate!);
    if (start == null) return false;
    return start.isAfter(DateTime.now());
  }

  bool get isPast {
    if (endDate == null) return false;
    final end = DateTime.tryParse(endDate!);
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  /// Get the first destination's country from embedded destinations
  String? get primaryCountry {
    if (destinations == null || destinations!.isEmpty) return null;
    final sorted = List<Map<String, dynamic>>.from(
      destinations!.map((d) => d as Map<String, dynamic>),
    )..sort((a, b) {
        final aDate = a['arrivalDate'] as String? ?? '';
        final bDate = b['arrivalDate'] as String? ?? '';
        return aDate.compareTo(bDate);
      });
    return sorted.first['country'] as String?;
  }
}
