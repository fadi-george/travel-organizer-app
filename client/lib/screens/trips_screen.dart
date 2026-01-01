import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/convex_service.dart';
import '../widgets/save_trip_sheet.dart';
import '../widgets/trip_card.dart';
import 'trip_detail_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> _trips = [];
  bool _isLoading = true;
  String? _error;
  SubscriptionHandle? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeConvex();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeConvex() async {
    try {
      final convexService = await ConvexService.getInstance();

      // Subscribe to real-time updates
      _subscription = await convexService.subscribeToTrips(
        onUpdate: (tripsData) {
          if (!mounted) return;
          setState(() {
            _trips = tripsData.map((json) => Trip.fromJson(json)).toList();
            _isLoading = false;
            _error = null;
          });
        },
        onError: (message, value) {
          if (!mounted) return;
          setState(() {
            _error = message;
            _isLoading = false;
          });
          debugPrint('Convex subscription error: $message $value');
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
      debugPrint('Error initializing Convex: $e');
    }
  }

  List<Trip> get _upcomingTrips =>
      _trips.where((t) => t.isUpcoming).toList()
        ..sort((a, b) => (a.startDate ?? '').compareTo(b.startDate ?? ''));

  List<Trip> get _pastTrips =>
      _trips.where((t) => t.isPast).toList()
        ..sort((a, b) => (b.startDate ?? '').compareTo(a.startDate ?? ''));

  String get _tripsSummary {
    final upcoming = _upcomingTrips.length;
    final past = _pastTrips.length;

    if (upcoming > 0 && past > 0) {
      return '$upcoming upcoming · $past past';
    } else if (upcoming > 0) {
      return '$upcoming upcoming';
    } else if (past > 0) {
      return '$past past ${past == 1 ? 'trip' : 'trips'}';
    }
    return 'No trips yet';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? _buildErrorState()
            : CustomScrollView(
                slivers: [
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'My Trips',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _tripsSummary,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Upcoming section
                  if (_upcomingTrips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: _SectionHeader(
                          title: 'Upcoming',
                          count: _upcomingTrips.length,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final trip = _upcomingTrips[index];
                          return TripCard(
                            trip: trip,
                            primaryCountry: trip.primaryCountry,
                            index: index,
                            onTap: () => _onTripTapped(trip),
                            onEdit: () => _onEditTrip(trip),
                            onDelete: () => _onDeleteTrip(trip),
                          );
                        }, childCount: _upcomingTrips.length),
                      ),
                    ),
                  ],

                  // Past trips section
                  if (_pastTrips.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                        child: _SectionHeader(
                          title: 'Past Trips',
                          count: _pastTrips.length,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final trip = _pastTrips[index];
                          return TripCard(
                            trip: trip,
                            primaryCountry: trip.primaryCountry,
                            index: index,
                            isCompact: true,
                            onTap: () => _onTripTapped(trip),
                            onEdit: () => _onEditTrip(trip),
                            onDelete: () => _onDeleteTrip(trip),
                          );
                        }, childCount: _pastTrips.length),
                      ),
                    ),
                  ],

                  // Empty state
                  if (_trips.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFFF7043,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.flight_takeoff_rounded,
                                size: 48,
                                color: Color(0xFFFF7043),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No trips yet',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start planning your next adventure!',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _onAddTrip,
                              icon: const Icon(Icons.add),
                              label: const Text('Add your first trip'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7043),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
      floatingActionButton: _trips.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: _onAddTrip,
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
              elevation: 4,
              child: const Icon(Icons.add, size: 28),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Connection Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Failed to connect to the server',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initializeConvex();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF7043),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTripTapped(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TripDetailScreen(trip: trip, primaryCountry: trip.primaryCountry),
      ),
    );
  }

  void _onEditTrip(Trip trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTripSheet(
        existingTrip: trip,
        onTripCreated: (name, startDate, endDate, notes) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Updated trip: $name'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _onDeleteTrip(Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Trip'),
        content: Text('Are you sure you want to delete "${trip.name}"?'),
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
        await convexService.deleteTrip(trip.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted: ${trip.name}'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete trip: $e'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _onAddTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTripSheet(
        onTripCreated: (name, startDate, endDate, notes) {
          // No need to reload - the subscription will automatically update
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Created trip: $name'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade500,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7043).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFF7043),
            ),
          ),
        ),
      ],
    );
  }
}
