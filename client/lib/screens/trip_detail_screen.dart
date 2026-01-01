import 'package:cached_network_image/cached_network_image.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/convex_service.dart';
import '../utils/country_images.dart';
import '../widgets/days_carousel.dart';
import '../widgets/save_flight_sheet.dart';
import '../widgets/save_hotel_sheet.dart';
import '../widgets/timeline_item.dart';

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
  late Trip _trip;
  SubscriptionHandle? _subscription;

  Trip get trip => _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _initializeDates();
    _subscribeToTrips();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToTrips() async {
    try {
      final convexService = await ConvexService.getInstance();
      _subscription = await convexService.subscribeToTrips(
        onUpdate: (tripsData) {
          if (!mounted) return;
          // Find our trip in the updated list
          final updatedTrip = tripsData
              .map((json) => Trip.fromJson(json))
              .where((t) => t.id == widget.trip.id)
              .firstOrNull;
          if (updatedTrip != null) {
            setState(() {
              _trip = updatedTrip;
            });
          }
        },
        onError: (message, value) {
          debugPrint('Trip subscription error: $message $value');
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to trips: $e');
    }
  }

  void _initializeDates() {
    _startDate = DateTime.parse(trip.startDate);
    _endDate = DateTime.parse(trip.endDate);
    _selectedDate = DaysCarousel.getDefaultSelectedDate(_startDate, _endDate);
  }

  Future<void> _onDeleteFlight(String flightId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flight'),
        content: const Text('Are you sure you want to delete this flight?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final convexService = await ConvexService.getInstance();
        await convexService.deleteFlight(flightId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Flight deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting flight: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _onEditFlight(Map<String, dynamic> flightData) {
    FlightOptionsSheet.showEditFlight(
      context,
      tripId: trip.id,
      flightData: flightData,
    );
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
        final departureDate = flightData['departureDate'] as String?;
        if (departureDate != null) {
          final date = DateTime.tryParse(departureDate);
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
        final departureDate = flightData['departureDate'] as String?;
        final departureTime = flightData['departureTime'] as String?;
        if (departureDate != null) {
          final date = DateTime.tryParse(departureDate);
          if (date != null && _isSameDay(date, _selectedDate)) {
            // Combine date and time for sorting
            DateTime sortTime = date;
            if (departureTime != null) {
              final timeParts = departureTime.split(':');
              if (timeParts.length >= 2) {
                sortTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  int.tryParse(timeParts[0]) ?? 0,
                  int.tryParse(timeParts[1]) ?? 0,
                );
              }
            }
            allItems.add({
              'type': 'flight',
              'data': flightData,
              'sortTime': sortTime,
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
            expandedHeight: 240,
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
                        Row(
                          children: [
                            Text(
                              trip.formattedDateRange,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: trip.isUpcoming
                                    ? const Color(0xFFFF7043)
                                    : Colors.grey.shade600,
                                borderRadius: BorderRadius.circular(12),
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
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Quick actions
                        Row(
                          children: [
                            Expanded(
                              child: _HeaderActionButton(
                                icon: Icons.flight,
                                label: 'Flights',
                                onTap: () => FlightOptionsSheet.show(
                                  context,
                                  tripId: trip.id,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _HeaderActionButton(
                                icon: Icons.hotel,
                                label: 'Hotels',
                                onTap: () => HotelOptionsSheet.show(
                                  context,
                                  tripId: trip.id,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _HeaderActionButton(
                                icon: Icons.local_activity,
                                label: 'Activities',
                                onTap: () {
                                  // TODO: Navigate to activities
                                },
                              ),
                            ),
                          ],
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
                  child: TimelineItem(
                    type: type,
                    data: data,
                    isLast: index == activities.length - 1,
                    onEdit: type == 'flight' ? () => _onEditFlight(data) : null,
                    onDelete: type == 'flight'
                        ? () => _onDeleteFlight(data['_id'] as String)
                        : null,
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

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
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
