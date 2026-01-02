import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/trip.dart';
import '../widgets/days_carousel.dart';

class TripMapScreen extends StatefulWidget {
  final Trip trip;
  final DateTime initialDate;

  const TripMapScreen({
    super.key,
    required this.trip,
    required this.initialDate,
  });

  @override
  State<TripMapScreen> createState() => _TripMapScreenState();
}

class _TripMapScreenState extends State<TripMapScreen> {
  late DateTime _selectedDate;
  late DateTime _startDate;
  late DateTime _endDate;
  // ignore: unused_field
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  static const _defaultCenter = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startDate = DateTime.parse(widget.trip.startDate);
    _endDate = DateTime.parse(widget.trip.endDate);
    _updateMarkers();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Get items with locations for the selected date
  List<MapItem> get _itemsForSelectedDate {
    final items = <MapItem>[];

    // Add activities
    if (widget.trip.activities != null) {
      for (final activity in widget.trip.activities!) {
        final data = activity as Map<String, dynamic>;
        final dateStr = data['date'] as String?;
        final location = data['location'] as String?;

        if (dateStr != null && location != null && location.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _isSameDay(date, _selectedDate)) {
            items.add(MapItem(
              title: data['title'] as String? ?? 'Activity',
              address: location,
              type: MapItemType.activity,
              time: data['time'] as String?,
            ));
          }
        }
      }
    }

    // Add accommodations (check-in on selected date)
    if (widget.trip.accommodations != null) {
      for (final acc in widget.trip.accommodations!) {
        final data = acc as Map<String, dynamic>;
        final checkIn = data['checkIn'] as String?;
        final checkOut = data['checkOut'] as String?;
        final address = data['address'] as String?;

        if (address != null && address.isNotEmpty) {
          // Show on check-in day
          if (checkIn != null) {
            final date = DateTime.tryParse(checkIn);
            if (date != null && _isSameDay(date, _selectedDate)) {
              items.add(MapItem(
                title: data['name'] as String? ?? 'Hotel',
                address: address,
                type: MapItemType.hotel,
                subtitle: 'Check-in',
              ));
            }
          }
          // Show on check-out day
          if (checkOut != null) {
            final date = DateTime.tryParse(checkOut);
            if (date != null && _isSameDay(date, _selectedDate)) {
              items.add(MapItem(
                title: data['name'] as String? ?? 'Hotel',
                address: address,
                type: MapItemType.hotel,
                subtitle: 'Check-out',
              ));
            }
          }
        }
      }
    }

    // Add flight airports
    if (widget.trip.flights != null) {
      for (final flight in widget.trip.flights!) {
        final data = flight as Map<String, dynamic>;
        final dateStr = data['departureDate'] as String?;

        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _isSameDay(date, _selectedDate)) {
            final departureAirport = data['departureAirport'] as String?;
            final arrivalAirport = data['arrivalAirport'] as String?;
            final departureCity = data['departureCity'] as String?;
            final arrivalCity = data['arrivalCity'] as String?;

            if (departureAirport != null && departureAirport.isNotEmpty) {
              items.add(MapItem(
                title: 'Departure: $departureAirport',
                address: '$departureAirport Airport, ${departureCity ?? ''}',
                type: MapItemType.flight,
                time: data['departureTime'] as String?,
              ));
            }
            if (arrivalAirport != null && arrivalAirport.isNotEmpty) {
              items.add(MapItem(
                title: 'Arrival: $arrivalAirport',
                address: '$arrivalAirport Airport, ${arrivalCity ?? ''}',
                type: MapItemType.flight,
                time: data['arrivalTime'] as String?,
              ));
            }
          }
        }
      }
    }

    return items;
  }

  void _updateMarkers() {
    // Note: In a real app, you'd use geocoding to convert addresses to coordinates
    // For now, we show the list of locations with addresses
    setState(() {
      _markers = {};
    });
  }

  /// Get event counts per day for the carousel indicators
  Map<DateTime, int> get _eventCountsPerDay {
    final counts = <DateTime, int>{};

    if (widget.trip.flights != null) {
      for (final flight in widget.trip.flights!) {
        final data = flight as Map<String, dynamic>;
        final dateStr = data['departureDate'] as String?;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
      }
    }

    if (widget.trip.accommodations != null) {
      for (final acc in widget.trip.accommodations!) {
        final data = acc as Map<String, dynamic>;
        final checkIn = data['checkIn'] as String?;
        final checkOut = data['checkOut'] as String?;

        if (checkIn != null) {
          final date = DateTime.tryParse(checkIn);
          if (date != null) {
            final normalized = DateTime(date.year, date.month, date.day);
            counts[normalized] = (counts[normalized] ?? 0) + 1;
          }
        }
        if (checkOut != null) {
          final date = DateTime.tryParse(checkOut);
          final checkInDate = checkIn != null ? DateTime.tryParse(checkIn) : null;
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

    if (widget.trip.activities != null) {
      for (final activity in widget.trip.activities!) {
        final data = activity as Map<String, dynamic>;
        final dateStr = data['date'] as String?;
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

  @override
  Widget build(BuildContext context) {
    final items = _itemsForSelectedDate;
    final hasLocations = items.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.name),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Days Carousel
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 12),
                DaysCarousel(
                  startDate: _startDate,
                  endDate: _endDate,
                  selectedDate: _selectedDate,
                  eventCounts: _eventCountsPerDay,
                  onDateSelected: (date) {
                    setState(() {
                      _selectedDate = date;
                    });
                    _updateMarkers();
                  },
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),
          // Map and locations
          Expanded(
            child: Stack(
              children: [
                // Google Map
                GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _defaultCenter,
                    zoom: 2,
                  ),
                  markers: _markers,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
                // Locations list overlay
                if (hasLocations)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Text(
                                  'Locations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF7043)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${items.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF7043),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: 24,
                              ),
                              itemCount: items.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _LocationCard(item: item);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Empty state
                if (!hasLocations)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_outlined,
                            size: 48,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No locations for this day',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add addresses to activities to see them here',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum MapItemType { activity, hotel, flight }

class MapItem {
  final String title;
  final String address;
  final MapItemType type;
  final String? time;
  final String? subtitle;

  const MapItem({
    required this.title,
    required this.address,
    required this.type,
    this.time,
    this.subtitle,
  });

  IconData get icon {
    switch (type) {
      case MapItemType.activity:
        return Icons.local_activity;
      case MapItemType.hotel:
        return Icons.hotel;
      case MapItemType.flight:
        return Icons.flight;
    }
  }

  Color get color {
    switch (type) {
      case MapItemType.activity:
        return Colors.orange;
      case MapItemType.hotel:
        return Colors.blue;
      case MapItemType.flight:
        return Colors.purple;
    }
  }
}

class _LocationCard extends StatelessWidget {
  final MapItem item;

  const _LocationCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.icon,
              color: item.color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (item.time != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        item.time!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle ?? item.address,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.open_in_new,
            size: 18,
            color: colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }
}

