import 'package:cached_network_image/cached_network_image.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/convex_service.dart';
import '../utils/places_images.dart';
import '../widgets/days_carousel.dart';
import '../widgets/hotel_card.dart';
import '../widgets/save_activity_sheet.dart';
import '../widgets/save_flight_sheet.dart';
import '../widgets/save_hotel_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/save_trip_sheet.dart';
import '../widgets/timeline_item.dart';
import 'trip_map_screen.dart';

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  final String? primaryPlace;

  const TripDetailScreen({super.key, required this.trip, this.primaryPlace});

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
            final datesChanged =
                updatedTrip.startDate != _trip.startDate ||
                updatedTrip.endDate != _trip.endDate;
            setState(() {
              _trip = updatedTrip;
              if (datesChanged) {
                _updateDates();
              }
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

  void _updateDates() {
    final newStart = DateTime.parse(trip.startDate);
    final newEnd = DateTime.parse(trip.endDate);

    // Check if current selected date is still valid in the new range
    final selectedStillValid =
        !_selectedDate.isBefore(newStart) && !_selectedDate.isAfter(newEnd);

    _startDate = newStart;
    _endDate = newEnd;

    if (!selectedStillValid) {
      _selectedDate = DaysCarousel.getDefaultSelectedDate(_startDate, _endDate);
    }
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

  void _onEditAccommodation(Map<String, dynamic> hotelData) {
    HotelOptionsSheet.showEditHotel(
      context,
      tripId: trip.id,
      hotelData: hotelData,
    );
  }

  void _onEditActivity(Map<String, dynamic> activityData) {
    ActivityOptionsSheet.showEditActivity(
      context,
      tripId: trip.id,
      activityData: activityData,
    );
  }

  void _onAddActivity() {
    ActivityOptionsSheet.show(context, tripId: trip.id);
  }

  Future<void> _onDeleteActivity(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Activity'),
        content: const Text('Are you sure you want to delete this activity?'),
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

    if (confirm == true) {
      try {
        final convexService = await ConvexService.getInstance();
        await convexService.deleteActivity(id);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Activity deleted'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting activity: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  VoidCallback? _getEditHandler(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'flight':
        return () => _onEditFlight(data);
      case 'accommodation':
        return () => _onEditAccommodation(data);
      case 'activity':
        return () => _onEditActivity(data);
      default:
        return null;
    }
  }

  VoidCallback? _getDeleteHandler(String type, Map<String, dynamic> data) {
    final id = data['_id'] as String?;
    if (id == null) return null;

    switch (type) {
      case 'flight':
        return () => _onDeleteFlight(id);
      case 'accommodation':
        return () => _onDeleteAccommodation(id);
      case 'activity':
        return () => _onDeleteActivity(id);
      default:
        return null;
    }
  }

  Future<void> _onDeleteAccommodation(String accommodationId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hotel'),
        content: const Text('Are you sure you want to delete this hotel?'),
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
        await convexService.deleteAccommodation(accommodationId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hotel deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting hotel: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String get _imageUrl {
    if (trip.imageUrl != null) return trip.imageUrl!;
    debugPrint('Primary place: ${widget.primaryPlace}');
    return PlacesImages.getImageUrl(widget.primaryPlace);
  }

  void _onEditTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTripSheet(existingTrip: _trip),
    );
  }

  Future<void> _onDeleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text(
          'Are you sure you want to delete "${_trip.name}"? This will also delete all flights, hotels, and activities associated with this trip.',
        ),
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
        await convexService.deleteTrip(_trip.id);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting trip: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

    // Count accommodations (check-in and check-out dates)
    if (trip.accommodations != null) {
      for (final acc in trip.accommodations!) {
        final accData = acc as Map<String, dynamic>;
        final checkIn = accData['checkIn'] as String?;
        final checkOut = accData['checkOut'] as String?;

        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }

        if (checkOut != null) {
          final date = DateTime.tryParse(checkOut);
          final checkInDate = checkIn != null
              ? DateTime.tryParse(checkIn)
              : null;
          // Only count if check-out is on a different day than check-in
          if (date != null &&
              (checkInDate == null ||
                  date.year != checkInDate.year ||
                  date.month != checkInDate.month ||
                  date.day != checkInDate.day)) {
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

    // Add accommodations for selected date (check-in and check-out)
    if (trip.accommodations != null) {
      for (final acc in trip.accommodations!) {
        final accData = acc as Map<String, dynamic>;
        final checkIn = accData['checkIn'] as String?;
        final checkOut = accData['checkOut'] as String?;

        // Check-in
        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null && _isSameDay(date, _selectedDate)) {
            allItems.add({
              'type': 'accommodation',
              'accommodationType': 'checkIn',
              'data': accData,
              'sortTime': date,
            });
          }
        }

        // Check-out (only if different from check-in)
        if (checkOut != null) {
          final date = DateTime.tryParse(checkOut);
          if (date != null &&
              _isSameDay(date, _selectedDate) &&
              (checkIn == null ||
                  !_isSameDay(date, DateTime.tryParse(checkIn)!))) {
            allItems.add({
              'type': 'accommodation',
              'accommodationType': 'checkOut',
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
        final timeStr = activityData['time'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _isSameDay(date, _selectedDate)) {
            // Combine date and time for sorting
            DateTime sortTime = date;
            if (timeStr != null) {
              final timeParts = timeStr.split(':');
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
              'type': 'activity',
              'data': activityData,
              'sortTime': sortTime,
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

  void _openMapScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TripMapScreen(trip: _trip, initialDate: _selectedDate),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: AppFab.map(onPressed: _openMapScreen),
      body: CustomScrollView(
        slivers: [
          // Hero header with image
          SliverAppBar(
            expandedHeight: 210,
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
            actions: [
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.more_horiz,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _onEditTrip();
                    case 'delete':
                      _onDeleteTrip();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 12),
                        Text('Edit Trip'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Delete Trip',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
            ],
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
                  // Gradient overlay - dark at bottom fading to transparent at top
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.4, 0.8],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 16,
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
                        const SizedBox(height: 12),
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
                            const SizedBox(width: 8),
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
                            const SizedBox(width: 8),
                            Expanded(
                              child: _HeaderActionButton(
                                icon: Icons.local_activity,
                                label: 'Activities',
                                onTap: _onAddActivity,
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

          // Days Carousel with Hero transition
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Hero(
                  tag: 'days-carousel-${_trip.id}',
                  flightShuttleBuilder:
                      (
                        flightContext,
                        animation,
                        flightDirection,
                        fromHeroContext,
                        toHeroContext,
                      ) {
                        return Material(
                          color: Colors.transparent,
                          child: toHeroContext.widget,
                        );
                      },
                  child: DaysCarousel(
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
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Filtered activities list
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final activities = _filteredActivities;
                if (activities.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _EmptyDaySection(onAddActivity: _onAddActivity),
                  );
                }
                if (index >= activities.length) return null;

                final item = activities[index];
                final type = item['type'] as String;
                final data = item['data'] as Map<String, dynamic>;
                final accommodationType = item['accommodationType'] as String?;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TimelineItem(
                    type: type,
                    data: data,
                    isLast: index == activities.length - 1,
                    onEdit: _getEditHandler(type, data),
                    onDelete: _getDeleteHandler(type, data),
                    hotelCardType: accommodationType == 'checkOut'
                        ? HotelCardType.checkOut
                        : HotelCardType.checkIn,
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
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        trip.notes!,
                        style: TextStyle(
                          fontSize: 15,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.7),
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: isDark ? 0.2 : 0.1),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No activities planned for this day',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add flights, hotels, or activities',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
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
