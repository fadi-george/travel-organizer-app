import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../widgets/create_trip_sheet.dart';
import '../widgets/trip_card.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<Trip> _trips = [];
  List<Destination> _destinations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        rootBundle.loadString(
          'assets/mocks/emptyArr.json',
        ), // TODO: switch back to trips.json
        rootBundle.loadString('assets/mocks/destinations.json'),
      ]);

      final List<dynamic> tripsJson = jsonDecode(results[0]);
      final List<dynamic> destinationsJson = jsonDecode(results[1]);

      setState(() {
        _trips = tripsJson.map((json) => Trip.fromJson(json)).toList();
        _destinations = destinationsJson
            .map((json) => Destination.fromJson(json))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading data: $e');
    }
  }

  /// Get the first destination's country for a trip
  String? _getPrimaryCountry(int tripId) {
    final destination = _destinations.where((d) => d.tripId == tripId).toList()
      ..sort((a, b) => (a.arrivalDate ?? '').compareTo(b.arrivalDate ?? ''));
    return destination.isNotEmpty ? destination.first.country : null;
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
      backgroundColor: const Color(0xFFF8F6F3),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
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
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final trip = _upcomingTrips[index];
                          return TripCard(
                            trip: trip,
                            primaryCountry: _getPrimaryCountry(trip.id),
                            index: index,
                            onTap: () => _onTripTapped(trip),
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
                            primaryCountry: _getPrimaryCountry(trip.id),
                            index: index,
                            isCompact: true,
                            onTap: () => _onTripTapped(trip),
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

  void _onTripTapped(Trip trip) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected: ${trip.name}'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onAddTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTripSheet(
        onTripCreated: (name, startDate, endDate, notes) {
          // TODO: Actually create the trip and refresh list
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
