import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../services/airports_service.dart';
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
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _mapError = false;
  bool _isLoadingMarkers = false;

  // Cache geocoded addresses to avoid repeated API calls
  final Map<String, LatLng?> _geocodeCache = {};

  static const _defaultCenter = LatLng(0, 0);

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _startDate = DateTime.parse(widget.trip.startDate);
    _endDate = DateTime.parse(widget.trip.endDate);
    _loadAirportsAndMarkers();
  }

  Future<void> _loadAirportsAndMarkers() async {
    await AirportsService.instance.loadAirports();
    await _updateMarkers();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Geocode an address to LatLng using Google Geocoding API
  Future<LatLng?> _geocodeAddress(String address) async {
    if (_geocodeCache.containsKey(address)) {
      return _geocodeCache[address];
    }

    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}'
        '&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final latLng = LatLng(location['lat'], location['lng']);
          _geocodeCache[address] = latLng;
          return latLng;
        }
      }
    } catch (_) {
      // Geocoding failed
    }
    _geocodeCache[address] = null;
    return null;
  }

  /// Get airport coordinates by IATA code
  LatLng? _getAirportLocation(String iataCode) {
    final airport = AirportsService.instance.getByIata(iataCode);
    if (airport != null && airport.lat != null && airport.lon != null) {
      return LatLng(airport.lat!, airport.lon!);
    }
    return null;
  }

  /// Get items with locations for the selected date
  List<MapItem> _getItemsForSelectedDate() {
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
            items.add(
              MapItem(
                title: data['title'] as String? ?? 'Activity',
                address: location,
                type: MapItemType.activity,
                time: data['time'] as String?,
              ),
            );
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
              items.add(
                MapItem(
                  title: data['name'] as String? ?? 'Hotel',
                  address: address,
                  type: MapItemType.hotel,
                  subtitle: 'Check-in',
                ),
              );
            }
          }
          // Show on check-out day
          if (checkOut != null) {
            final date = DateTime.tryParse(checkOut);
            if (date != null && _isSameDay(date, _selectedDate)) {
              items.add(
                MapItem(
                  title: data['name'] as String? ?? 'Hotel',
                  address: address,
                  type: MapItemType.hotel,
                  subtitle: 'Check-out',
                ),
              );
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
            final departureAirportCode =
                data['departureAirportCode'] as String?;
            final arrivalAirportCode = data['arrivalAirportCode'] as String?;

            if (departureAirportCode != null &&
                departureAirportCode.isNotEmpty) {
              final airport = AirportsService.instance.getByIata(
                departureAirportCode,
              );
              items.add(
                MapItem(
                  title: 'Departure: $departureAirportCode',
                  address: airport?.name ?? '$departureAirportCode Airport',
                  type: MapItemType.flight,
                  time: data['departureTime'] as String?,
                  airportCode: departureAirportCode,
                ),
              );
            }

            if (arrivalAirportCode != null && arrivalAirportCode.isNotEmpty) {
              final airport = AirportsService.instance.getByIata(
                arrivalAirportCode,
              );
              items.add(
                MapItem(
                  title: 'Arrival: $arrivalAirportCode',
                  address: airport?.name ?? '$arrivalAirportCode Airport',
                  type: MapItemType.flight,
                  time: data['arrivalTime'] as String?,
                  airportCode: arrivalAirportCode,
                ),
              );
            }
          }
        }
      }
    }

    return items;
  }

  Future<void> _updateMarkers() async {
    setState(() => _isLoadingMarkers = true);

    final items = _getItemsForSelectedDate();
    final markers = <Marker>{};
    final bounds = <LatLng>[];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      LatLng? location;

      // Get location based on item type
      if (item.type == MapItemType.flight && item.airportCode != null) {
        location = _getAirportLocation(item.airportCode!);
      } else {
        location = await _geocodeAddress(item.address);
      }

      if (location != null) {
        bounds.add(location);

        markers.add(
          Marker(
            markerId: MarkerId('${item.type.name}_$i'),
            position: location,
            icon: await _getMarkerIcon(item.type),
            infoWindow: InfoWindow(
              title: item.title,
              snippet: item.time != null
                  ? '${item.time} • ${item.address}'
                  : item.address,
            ),
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _markers = markers;
      _isLoadingMarkers = false;
    });

    // Fit camera to show all markers
    if (bounds.isNotEmpty && _mapController != null) {
      _fitBounds(bounds);
    }
  }

  Future<BitmapDescriptor> _getMarkerIcon(MapItemType type) async {
    switch (type) {
      case MapItemType.activity:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case MapItemType.hotel:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
      case MapItemType.flight:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
    }
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 14),
      );
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
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
          final checkInDate = checkIn != null
              ? DateTime.tryParse(checkIn)
              : null;
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.name),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Days Carousel with Hero transition
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Hero(
                  tag: 'days-carousel-${widget.trip.id}',
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
                      _updateMarkers();
                    },
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
              ],
            ),
          ),
          // Map
          Expanded(
            child: Stack(
              children: [
                if (_mapError)
                  Container(
                    color: Colors.grey.shade200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Map unavailable',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Check Google Maps API key configuration',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: _defaultCenter,
                      zoom: 2,
                    ),
                    markers: _markers,
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Re-fit bounds after map is created if we have markers
                      if (_markers.isNotEmpty) {
                        final points = _markers.map((m) => m.position).toList();
                        _fitBounds(points);
                      }
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
                // Loading indicator
                if (_isLoadingMarkers)
                  Container(
                    color: Colors.black.withValues(alpha: 0.1),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7043),
                      ),
                    ),
                  ),
                // Empty state when no markers
                if (!_isLoadingMarkers && _markers.isEmpty)
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
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No locations for this day',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add flights, hotels, or activities to see them on the map',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                // Legend
                if (_markers.isNotEmpty)
                  Positioned(
                    left: 16,
                    bottom: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _LegendItem(color: Colors.purple, label: 'Flight'),
                          const SizedBox(width: 12),
                          _LegendItem(color: Colors.blue, label: 'Hotel'),
                          const SizedBox(width: 12),
                          _LegendItem(color: Colors.orange, label: 'Activity'),
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

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
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
  final String? airportCode;

  const MapItem({
    required this.title,
    required this.address,
    required this.type,
    this.time,
    this.subtitle,
    this.airportCode,
  });
}
