import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/auth_service.dart';
import '../services/convex_service.dart';
import '../theme/app_theme.dart';
import '../utils/dialogs.dart';
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
        ..sort((a, b) => a.startDate.compareTo(b.startDate));

  List<Trip> get _pastTrips =>
      _trips.where((t) => t.isPast).toList()
        ..sort((a, b) => b.startDate.compareTo(a.startDate));

  String get _tripsSummary {
    final upcoming = _upcomingTrips.length;
    final past = _pastTrips.length;
    if (upcoming > 0 && past > 0) return '$upcoming upcoming · $past past';
    if (upcoming > 0) return '$upcoming upcoming';
    if (past > 0) return '$past past ${past == 1 ? 'trip' : 'trips'}';
    return 'No trips yet';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    showAppSnackBar(context, message, isError: isError);
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
                          // Profile menu button
                          _buildProfileButton(context),
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
                            primaryPlace: trip.primaryPlace,
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
                            primaryPlace: trip.primaryPlace,
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

                  if (_trips.isEmpty)
                    SliverFillRemaining(child: _buildEmptyState()),

                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
      ),
      floatingActionButton: _trips.isEmpty
          ? null
          : AppFab.add(onPressed: _onAddTrip),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _CircleIcon(
            icon: Icons.flight_takeoff_rounded,
            color: AppColors.primary,
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
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _onAddTrip,
            icon: const Icon(Icons.add),
            label: const Text('Add your first trip'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = AuthService.instance.user;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) async {
        if (value == 'sign_out') {
          try {
            final clerkAuth = ClerkAuth.of(context);
            await clerkAuth.signOut();
          } catch (e) {
            debugPrint('Error signing out: $e');
          }
        }
      },
      itemBuilder: (context) => [
        if (user != null) ...[
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name ?? 'User',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem<String>(
          value: 'sign_out',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Sign out', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.settings_rounded,
          size: 24,
          color: colorScheme.onSurfaceVariant,
        ),
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
            _CircleIcon(icon: Icons.cloud_off_rounded, color: Colors.red),
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
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
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
            TripDetailScreen(trip: trip, primaryPlace: trip.primaryPlace),
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
        onTripCreated: (name, startDate, endDate, notes) =>
            _showSnackBar('Updated trip: $name'),
      ),
    );
  }

  Future<void> _onDeleteTrip(Trip trip) async {
    final confirmed = await showDeleteConfirmation(
      context,
      title: 'Delete Trip',
      message: 'Are you sure you want to delete "${trip.name}"?',
    );
    if (!confirmed) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteTrip(trip.id);
      _showSnackBar('Deleted: ${trip.name}');
    } catch (e) {
      _showSnackBar('Failed to delete trip: $e', isError: true);
    }
  }

  void _onAddTrip() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTripSheet(
        onTripCreated: (name, startDate, endDate, notes) =>
            _showSnackBar('Created trip: $name'),
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
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CircleIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 48, color: color),
    );
  }
}
