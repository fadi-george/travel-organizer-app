import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/convex_service.dart';
import '../utils/dialogs.dart';
import '../utils/places_images.dart';
import '../utils/time_format.dart';
import '../widgets/days_carousel.dart';
import '../widgets/hotel_card.dart';
import '../widgets/save_activity_sheet.dart';
import '../widgets/save_flight_sheet.dart';
import '../widgets/save_hotel_sheet.dart';
import '../theme/app_theme.dart';
import '../widgets/weather_widget.dart';
import '../widgets/save_trip_sheet.dart';
import '../widgets/timeline_item.dart';
import '../widgets/checklist_sheet.dart';
import 'trip_map_screen.dart';

const double _kAppBarIconSize = 20;

class TripDetailScreen extends StatefulWidget {
  final Trip trip;
  final List<String>? primaryPlace;

  const TripDetailScreen({super.key, required this.trip, this.primaryPlace});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen>
    with TickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _startDate;
  late DateTime _endDate;
  late Trip _trip;
  SubscriptionHandle? _subscription;
  SubscriptionHandle? _checklistSubscription;
  List<Map<String, dynamic>> _checklistSections = [];
  final Set<String> _refreshingFlights = {};
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;

  Trip get trip => _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _initializeDates();
    _subscribeToTrips();
    _subscribeToChecklist();

    // Initialize FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.elasticOut,
      ),
    );

    // Auto-refresh upcoming flights on initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoRefreshUpcomingFlights();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Delay FAB animation until after screen transition ends (approximately 400-500ms)
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _fabAnimationController.forward();
      }
    });
  }

  /// Auto-refresh status for flights departing within 24 hours
  Future<void> _autoRefreshUpcomingFlights() async {
    if (_trip.flights == null || _trip.flights!.isEmpty) return;

    final convexService = await ConvexService.getInstance();

    for (final flight in _trip.flights!) {
      final flightData = flight as Map<String, dynamic>;
      final flightId = flightData['_id'] as String?;

      if (flightId == null) continue;
      if (_refreshingFlights.contains(flightId)) continue;

      // Check if this flight should be auto-refreshed
      if (ConvexService.shouldAutoRefreshFlight(flightData)) {
        _refreshingFlights.add(flightId);

        // Fire and forget - the subscription will update the UI
        convexService
            .refreshFlightStatus(flightId: flightId)
            .then((_) {
              _refreshingFlights.remove(flightId);
            })
            .catchError((e) {
              debugPrint('Auto-refresh error for flight $flightId: $e');
              _refreshingFlights.remove(flightId);
            });
      }
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _checklistSubscription?.cancel();
    _fabAnimationController.dispose();
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
            // Auto-refresh upcoming flights when trip data updates
            _autoRefreshUpcomingFlights();
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

  Future<void> _subscribeToChecklist() async {
    try {
      final convexService = await ConvexService.getInstance();
      _checklistSubscription = await convexService.subscribeToChecklist(
        tripId: _trip.id,
        onUpdate: (sections) {
          if (!mounted) return;
          setState(() => _checklistSections = sections);
        },
        onError: (message, value) {
          debugPrint('Checklist subscription error: $message $value');
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to checklist: $e');
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

    final selectedStillValid =
        !_selectedDate.isBefore(newStart) && !_selectedDate.isAfter(newEnd);

    _startDate = newStart;
    _endDate = newEnd;

    if (!selectedStillValid) {
      _selectedDate = DaysCarousel.getDefaultSelectedDate(_startDate, _endDate);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: isError);
  }

  Future<void> _onDeleteFlight(String flightId) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Delete Flight',
      message: 'Are you sure you want to delete this flight?',
    );
    if (!confirmed) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteFlight(flightId);
      _showSnackBar('Flight deleted');
    } catch (e) {
      _showSnackBar('Error deleting flight: $e', isError: true);
    }
  }

  void _onEditFlight(Map<String, dynamic> flightData) {
    FlightOptionsSheet.showEditFlight(
      context,
      tripId: trip.id,
      flightData: flightData,
      tripStartDate: _startDate,
      tripEndDate: _endDate,
    );
  }

  void _onEditAccommodation(Map<String, dynamic> hotelData) {
    HotelOptionsSheet.showEditHotel(
      context,
      tripId: trip.id,
      hotelData: hotelData,
      tripStartDate: _startDate,
      tripEndDate: _endDate,
    );
  }

  void _onEditActivity(Map<String, dynamic> activityData) {
    ActivityOptionsSheet.showEditActivity(
      context,
      tripId: trip.id,
      activityData: activityData,
      tripStartDate: _startDate,
      tripEndDate: _endDate,
    );
  }

  void _onAddActivity() {
    ActivityOptionsSheet.show(
      context,
      tripId: trip.id,
      tripStartDate: _startDate,
      tripEndDate: _endDate,
    );
  }

  Future<void> _onDeleteActivity(String id) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Delete Activity',
      message: 'Are you sure you want to delete this activity?',
    );
    if (!confirmed) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteActivity(id);
      _showSnackBar('Activity deleted');
    } catch (e) {
      _showSnackBar('Error deleting activity: $e', isError: true);
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
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Delete Hotel',
      message: 'Are you sure you want to delete this hotel?',
    );
    if (!confirmed) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteAccommodation(accommodationId);
      _showSnackBar('Hotel deleted');
    } catch (e) {
      _showSnackBar('Error deleting hotel: $e', isError: true);
    }
  }

  String get _imageUrl {
    if (trip.imageUrl != null) return trip.imageUrl!;
    final primaryPlace = _trip.primaryPlace(_selectedDate);
    debugPrint('primaryPlace: $primaryPlace');
    return PlacesImages.getImageUrl(primaryPlace);
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
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Delete Trip',
      message:
          'Are you sure you want to delete "${_trip.name}"? This will also delete all flights, hotels, and activities associated with this trip.',
    );
    if (!confirmed) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteTrip(_trip.id);
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar('Trip deleted');
      }
    } catch (e) {
      _showSnackBar('Error deleting trip: $e', isError: true);
    }
  }

  bool _isSameDay(DateTime a, DateTime b) => DateUtils.isSameDay(a, b);

  void _incrementCount(Map<DateTime, int> counts, String? dateStr) {
    if (dateStr == null) return;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return;
    final normalized = DateUtils.dateOnly(date);
    counts[normalized] = (counts[normalized] ?? 0) + 1;
  }

  Map<DateTime, int> get _eventCountsPerDay {
    final counts = <DateTime, int>{};

    for (final flight in trip.flights ?? []) {
      final flightData = flight as Map<String, dynamic>;
      _incrementCount(counts, flightData['departureDate'] as String?);
    }

    for (final acc in trip.accommodations ?? []) {
      final accData = acc as Map<String, dynamic>;
      final checkIn = accData['checkIn'] as String?;
      final checkOut = accData['checkOut'] as String?;

      _incrementCount(counts, checkIn);

      // Only count check-out if on a different day than check-in
      if (checkOut != null) {
        final checkOutDate = DateTime.tryParse(checkOut);
        final checkInDate = checkIn != null ? DateTime.tryParse(checkIn) : null;
        if (checkOutDate != null &&
            (checkInDate == null || !_isSameDay(checkOutDate, checkInDate))) {
          _incrementCount(counts, checkOut);
        }
      }
    }

    for (final activity in trip.activities ?? []) {
      final activityData = activity as Map<String, dynamic>;
      _incrementCount(counts, activityData['date'] as String?);
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
            final parsed = parseTime(departureTime);
            if (parsed != null) {
              sortTime = DateTime(
                date.year,
                date.month,
                date.day,
                parsed.$1,
                parsed.$2,
              );
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

        // Check-in - sort to 3:00 PM (typical check-in time, after flights arrive)
        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null && _isSameDay(date, _selectedDate)) {
            allItems.add({
              'type': 'accommodation',
              'accommodationType': 'checkIn',
              'data': accData,
              'sortTime': DateTime(date.year, date.month, date.day, 15, 0),
            });
          }
        }

        // Check-out - sort to 11:00 AM (typical check-out time, before flights depart)
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
              'sortTime': DateTime(date.year, date.month, date.day, 11, 0),
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
            final parsed = parseTime(timeStr);
            if (parsed != null) {
              sortTime = DateTime(
                date.year,
                date.month,
                date.day,
                parsed.$1,
                parsed.$2,
              );
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

  void _openChecklistSheet() {
    ChecklistSheet.show(
      context,
      tripId: _trip.id,
      initialSections: _checklistSections,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _fabScaleAnimation,
            child: FloatingActionButton(
              heroTag: 'checklist_fab',
              onPressed: _openChecklistSheet,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              child: const Icon(Icons.checklist, size: 24),
            ),
          ),
          const SizedBox(height: 12),
          AppFab.map(onPressed: _openMapScreen),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Hero header with image
          SliverAppBar(
            expandedHeight: 170,
            pinned: true,
            stretch: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: _kAppBarIconSize,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.more_horiz,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: _kAppBarIconSize,
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
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: .5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              trip.formattedDateRange,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withValues(alpha: .4),
                                    blurRadius: 12,
                                  ),
                                ],
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
                                    ? const Color(
                                        0xFFFF7043,
                                      ).withValues(alpha: 0.85)
                                    : Colors.grey.shade600.withValues(
                                        alpha: 0.7,
                                      ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trip.daysUntilTrip,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                  tripStartDate: _startDate,
                                  tripEndDate: _endDate,
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
                                  tripStartDate: _startDate,
                                  tripEndDate: _endDate,
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
                Hero(
                  tag: 'weather-widget-${_trip.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: WeatherWidget(
                      trip: _trip,
                      selectedDate: _selectedDate,
                    ),
                  ),
                ),
                // For debugging weather icons
                // const WeatherIconsDebug(),
                const Divider(height: 1),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 10)),

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isDark ? 3 : 3,
            sigmaY: isDark ? 3 : 3,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white.withValues(alpha: 0.175),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: .25)
                    : Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 1), size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 1),
                  ),
                ),
              ],
            ),
          ),
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
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
