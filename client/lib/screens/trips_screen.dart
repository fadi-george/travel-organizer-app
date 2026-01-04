import 'dart:async';

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
  List<Trip> _upcomingTrips = [];
  List<Trip> _pastTrips = [];
  bool _isLoading = true;
  String? _error;
  SubscriptionHandle? _subscription;
  Timer? _emptyFallbackTimer;

  @override
  void initState() {
    super.initState();
    _startTripsSubscription();
  }

  @override
  void dispose() {
    _emptyFallbackTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  bool get _hasTrips => _upcomingTrips.isNotEmpty || _pastTrips.isNotEmpty;

  Future<void> _startTripsSubscription({bool showLoading = false}) async {
    _subscription?.cancel();
    _emptyFallbackTimer?.cancel();

    if (showLoading && mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final convexService = await ConvexService.getInstance();
      _subscription = await convexService.subscribeToTrips(
        onUpdate: (tripsData) {
          if (!mounted) return;
          _emptyFallbackTimer?.cancel();

          final trips = tripsData.map(Trip.fromJson).toList();

          // Avoid "No trips yet" flash on hot-restart: Convex can emit an
          // initial empty update before hydrating cached/remote data.
          if (_isLoading && trips.isEmpty) {
            _emptyFallbackTimer ??= Timer(
              const Duration(milliseconds: 250),
              () {
                if (mounted) setState(() => _isLoading = false);
              },
            );
            return;
          }

          // Single-pass partition into upcoming/past
          final upcoming = <Trip>[];
          final past = <Trip>[];
          for (final t in trips) {
            (t.isUpcoming ? upcoming : past).add(t);
          }
          upcoming.sort((a, b) => a.startDate.compareTo(b.startDate));
          past.sort((a, b) => b.startDate.compareTo(a.startDate));

          setState(() {
            _upcomingTrips = upcoming;
            _pastTrips = past;
            _isLoading = false;
            _error = null;
          });
        },
        onError: (message, value) {
          if (!mounted) return;
          _emptyFallbackTimer?.cancel();
          debugPrint('Convex subscription error: $message $value');

          if (_hasTrips) {
            showAppSnackBar(context, message, isError: true);
          } else {
            setState(() {
              _error = message;
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (!mounted) return;
      debugPrint('Error initializing Convex: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String get _tripsSummary {
    final (u, p) = (_upcomingTrips.length, _pastTrips.length);
    if (u > 0 && p > 0) return '$u upcoming · $p past';
    if (u > 0) return '$u upcoming';
    if (p > 0) return '$p past ${p == 1 ? 'trip' : 'trips'}';
    return 'No trips yet';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(child: _buildBody(context)),
      floatingActionButton: _hasTrips
          ? AppFab.add(onPressed: _onAddTrip)
          : null,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildErrorState();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHeader(context)),
        ..._buildTripSection('Upcoming', _upcomingTrips, isCompact: false),
        ..._buildTripSection('Past Trips', _pastTrips, isCompact: true),
        if (!_hasTrips) SliverFillRemaining(child: _buildEmptyState()),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  List<Widget> _buildTripSection(
    String title,
    List<Trip> trips, {
    required bool isCompact,
  }) {
    if (trips.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: _SectionHeader(title: title, count: trips.length),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.symmetric(horizontal: isCompact ? 20 : 16),
        sliver: SliverList.builder(
          itemCount: trips.length,
          itemBuilder: (context, index) {
            final trip = trips[index];
            return TripCard(
              trip: trip,
              primaryPlace: trip.primaryPlace,
              index: index,
              isCompact: isCompact,
              onTap: () => _onTripTapped(trip),
              onEdit: () => _onEditTrip(trip),
              onDelete: () => _onDeleteTrip(trip),
            );
          },
        ),
      ),
    ];
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
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
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ],
          ),
          _buildProfileButton(context),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _CircleIcon(
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

    return PopupMenuButton<VoidCallback>(
      offset: const Offset(0, 48),
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(12),
      onSelected: (callback) => callback(),
      itemBuilder: (_) => [
        if (user != null) ...[
          PopupMenuItem(
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
        PopupMenuItem(
          value: () => ClerkAuth.of(context).signOut(),
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 20, color: colorScheme.error),
              const SizedBox(width: 12),
              Text('Sign out', style: TextStyle(color: colorScheme.error)),
            ],
          ),
        ),
      ],
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.settings_rounded, size: 20),
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
            const _CircleIcon(icon: Icons.cloud_off_rounded, color: Colors.red),
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
              onPressed: () => _startTripsSubscription(showLoading: true),
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

  void _onEditTrip(Trip trip) => _showTripSheet(trip);

  void _onAddTrip() => _showTripSheet(null);

  void _showTripSheet(Trip? trip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateTripSheet(
        existingTrip: trip,
        onTripCreated: (name, _, __, ___) => showAppSnackBar(
          context,
          '${trip == null ? 'Created' : 'Updated'} trip: $name',
        ),
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
      showAppSnackBar(context, 'Deleted: ${trip.name}');
    } catch (e) {
      showAppSnackBar(context, 'Failed to delete trip: $e', isError: true);
    }
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
  const _CircleIcon({required this.icon, required this.color});
  final IconData icon;
  final Color color;

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
