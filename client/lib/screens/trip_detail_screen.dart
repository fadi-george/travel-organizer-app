import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../utils/country_images.dart';
import '../widgets/days_carousel.dart';
import '../widgets/flight_options_sheet.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  final String? primaryCountry;

  const TripDetailScreen({super.key, required this.trip, this.primaryCountry});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late DateTime _selectedDate;
  late DateTime _startDate;
  late DateTime _endDate;

  Trip get trip => widget.trip;

  @override
  void initState() {
    super.initState();
    _initializeDates();
  }

  void _initializeDates() {
    _startDate = DateTime.parse(trip.startDate);
    _endDate = DateTime.parse(trip.endDate);
    _selectedDate = DaysCarousel.getDefaultSelectedDate(_startDate, _endDate);
  }

  String get _imageUrl {
    if (trip.imageUrl != null) return trip.imageUrl!;
    return CountryImages.getImageUrl(widget.primaryCountry);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get event counts per day for the carousel indicators
  Map<DateTime, int> get _eventCountsPerDay {
    final counts = <DateTime, int>{};

    // Count flights
    if (trip.flights != null) {
      for (final flight in trip.flights!) {
        final flightData = flight as Map<String, dynamic>;
        final departureTime = flightData['departureTime'] as String?;
        if (departureTime != null) {
          final date = DateTime.tryParse(departureTime);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }
    }

    // Count accommodations (check-in dates)
    if (trip.accommodations != null) {
      for (final acc in trip.accommodations!) {
        final accData = acc as Map<String, dynamic>;
        final checkIn = accData['checkIn'] as String?;
        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }
    }

    // Count activities
    if (trip.activities != null) {
      for (final activity in trip.activities!) {
        final activityData = activity as Map<String, dynamic>;
        final dateStr = activityData['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }
    }

    return counts;
  }

  /// Get activities filtered by selected date
  List<Map<String, dynamic>> get _filteredActivities {
    final allItems = <Map<String, dynamic>>[];

    // Add flights for selected date
    if (trip.flights != null) {
      for (final flight in trip.flights!) {
        final flightData = flight as Map<String, dynamic>;
        final departureTime = flightData['departureTime'] as String?;
        if (departureTime != null) {
          final date = DateTime.tryParse(departureTime);
          if (date != null && _isSameDay(date, _selectedDate)) {
            allItems.add({
              'type': 'flight',
              'data': flightData,
              'sortTime': date,
            });
          }
        }
      }
    }

    // Add accommodations check-in for selected date
    if (trip.accommodations != null) {
      for (final acc in trip.accommodations!) {
        final accData = acc as Map<String, dynamic>;
        final checkIn = accData['checkIn'] as String?;
        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null && _isSameDay(date, _selectedDate)) {
            allItems.add({
              'type': 'accommodation',
              'data': accData,
              'sortTime': date,
            });
          }
        }
      }
    }

    // Add activities for selected date
    if (trip.activities != null) {
      for (final activity in trip.activities!) {
        final activityData = activity as Map<String, dynamic>;
        final dateStr = activityData['date'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _isSameDay(date, _selectedDate)) {
            allItems.add({
              'type': 'activity',
              'data': activityData,
              'sortTime': date,
            });
          }
        }
      }
    }

    // Sort by time
    allItems.sort(
      (a, b) =>
          (a['sortTime'] as DateTime).compareTo(b['sortTime'] as DateTime),
    );

    return allItems;
  }

  String _getDayLabel(DateTime date) {
    final dayNumber = date.difference(_startDate).inDays + 1;

    if (dayNumber == 1) return '1st';
    if (dayNumber == 2) return '2nd';
    if (dayNumber == 3) return '3rd';
    return '${dayNumber}th';
  }

  String _formatDayHeader(DateTime date) {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Hero header with image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: const Color(0xFFFF7043),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.grey.shade300),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, size: 48),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.5, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: trip.isUpcoming
                                ? const Color(0xFFFF7043)
                                : Colors.grey.shade600,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            trip.daysUntilTrip,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          trip.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.formattedDateRange,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Days Carousel
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                DaysCarousel(
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedDate: _selectedDate,
                  eventCounts: _eventCountsPerDay,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                  },
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),

          // Day's activities timeline
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDayHeader(_selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _getDayLabel(_selectedDate),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Filtered activities list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final activities = _filteredActivities;
                if (activities.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptyDaySection(
                      onAddActivity: () {
                        // TODO: Add activity
                      },
                    ),
                  );
                }
                if (index >= activities.length) return null;

                final item = activities[index];
                final type = item['type'] as String;
                final data = item['data'] as Map<String, dynamic>;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _TimelineItem(
                    type: type,
                    data: data,
                    isLast: index == activities.length - 1,
                  ),
                );
              },
              childCount: _filteredActivities.isEmpty
                  ? 1
                  : _filteredActivities.length,
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),

                  // Quick actions
                  _SectionTitle(title: 'Plan Your Trip'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.flight,
                          label: 'Flights',
                          color: Colors.blue,
                          onTap: () =>
                              FlightOptionsSheet.show(context, tripId: trip.id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.hotel,
                          label: 'Hotels',
                          color: Colors.purple,
                          onTap: () {
                            // TODO: Navigate to hotels
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionCard(
                          icon: Icons.local_activity,
                          label: 'Activities',
                          color: Colors.orange,
                          onTap: () {
                            // TODO: Navigate to activities
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Notes section
                  if (trip.notes != null && trip.notes!.isNotEmpty) ...[
                    _SectionTitle(title: 'Notes'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        trip.notes!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDaySection extends StatelessWidget {
  final VoidCallback onAddActivity;

  const _EmptyDaySection({required this.onAddActivity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No activities planned for this day',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add flights, hotels, or activities',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onAddActivity,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Activity'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF7043),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String type;
  final Map<String, dynamic> data;
  final bool isLast;

  const _TimelineItem({
    required this.type,
    required this.data,
    this.isLast = false,
  });

  IconData get _icon {
    switch (type) {
      case 'flight':
        return Icons.flight;
      case 'accommodation':
        return Icons.hotel;
      case 'activity':
        return Icons.local_activity;
      default:
        return Icons.event;
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'flight':
        return Colors.blue;
      case 'accommodation':
        return Colors.purple;
      case 'activity':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get _title {
    switch (type) {
      case 'flight':
        final origin = data['origin'] as String? ?? '';
        final destination = data['destination'] as String? ?? '';
        return '$origin to $destination';
      case 'accommodation':
        return data['hotelName'] as String? ?? 'Hotel';
      case 'activity':
        return data['name'] as String? ?? 'Activity';
      default:
        return 'Event';
    }
  }

  String? get _subtitle {
    switch (type) {
      case 'flight':
        final airline = data['airline'] as String?;
        final flightNumber = data['flightNumber'] as String?;
        if (airline != null && flightNumber != null) {
          return '$airline $flightNumber';
        }
        return airline ?? flightNumber;
      case 'accommodation':
        return 'Check-in';
      case 'activity':
        return data['location'] as String?;
      default:
        return null;
    }
  }

  String? get _timeStr {
    switch (type) {
      case 'flight':
        final departure = data['departureTime'] as String?;
        if (departure != null) {
          final dt = DateTime.tryParse(departure);
          if (dt != null) {
            final hour = dt.hour > 12
                ? dt.hour - 12
                : (dt.hour == 0 ? 12 : dt.hour);
            final period = dt.hour >= 12 ? 'PM' : 'AM';
            final minute = dt.minute.toString().padLeft(2, '0');
            return '$hour:$minute $period';
          }
        }
        return null;
      case 'accommodation':
        return null;
      case 'activity':
        final time = data['time'] as String?;
        return time;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _iconColor, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _subtitle!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_timeStr != null)
                    Text(
                      _timeStr!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
