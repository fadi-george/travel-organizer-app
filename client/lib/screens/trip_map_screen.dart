import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../services/airports_service.dart';
import '../utils/time_format.dart';
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
  Set<Polyline> _polylines = {};
  final bool _mapError = false;
  bool _isLoadingMarkers = true; // Start as true to avoid flash of empty state

  // Cache geocoded addresses to avoid repeated API calls
  final Map<String, LatLng?> _geocodeCache = {};

  // Cache marker icons to avoid expensive recreation
  static final Map<String, BitmapDescriptor> _markerIconCache = {};

  static const _defaultCenter = LatLng(0, 0);

  // Light mode map style
  static const _lightMapStyle = '''
[
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "stylers": [{"visibility": "on"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"visibility": "on"}, {"color": "#aaaaaa"}, {"weight": 1}]},
  {"featureType": "administrative.province", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#c9e9f6"}]},
  {"featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [{"color": "#f5f5f5"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#fafafa"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#f0f0f0"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

  // Dark mode map style
  static const _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#1d2c4d"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#8ec3b9"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a3646"}]},
  {"featureType": "poi", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.park", "elementType": "geometry.fill", "stylers": [{"visibility": "on"}, {"color": "#023e58"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"visibility": "on"}, {"color": "#4b6878"}, {"weight": 1}]},
  {"featureType": "administrative.province", "elementType": "labels", "stylers": [{"visibility": "off"}]},
  {"featureType": "administrative.locality", "elementType": "labels", "stylers": [{"visibility": "simplified"}]},
  {"featureType": "water", "elementType": "geometry.fill", "stylers": [{"color": "#0e1626"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#4e6d70"}]},
  {"featureType": "landscape.natural", "elementType": "geometry.fill", "stylers": [{"color": "#1d2c4d"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#304a7d"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#98a5be"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#2c3e5e"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#2c3e50"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#255763"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]}
]
''';

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

            // Use departureTime for both to keep them together, sortOrder to maintain departure→arrival
            final depTime = data['departureTime'] as String?;

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
                  time: depTime,
                  airportCode: departureAirportCode,
                  sortOrder: 0, // Departure comes first
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
                  time: depTime, // Use departure time to keep with departure
                  airportCode: arrivalAirportCode,
                  sortOrder: 1, // Arrival comes after departure
                ),
              );
            }
          }
        }
      }
    }

    // Sort items by time, then by sortOrder for tiebreaking
    items.sort((a, b) {
      final timeA = parseTimeToMinutes(a.time);
      final timeB = parseTimeToMinutes(b.time);

      // Items without time go after items with time
      if (timeA == null && timeB == null) {
        return a.sortOrder.compareTo(b.sortOrder);
      }
      if (timeA == null) return 1;
      if (timeB == null) return -1;

      final timeCompare = timeA.compareTo(timeB);
      if (timeCompare != 0) return timeCompare;

      // Same time: use sortOrder (departure before arrival)
      return a.sortOrder.compareTo(b.sortOrder);
    });

    return items;
  }

  /// Get flight routes for the selected date (departure and arrival airport pairs)
  List<FlightRoute> _getFlightRoutesForSelectedDate() {
    final routes = <FlightRoute>[];

    if (widget.trip.flights != null) {
      for (final flight in widget.trip.flights!) {
        final data = flight as Map<String, dynamic>;
        final dateStr = data['departureDate'] as String?;

        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && _isSameDay(date, _selectedDate)) {
            final departureCode = data['departureAirportCode'] as String?;
            final arrivalCode = data['arrivalAirportCode'] as String?;

            if (departureCode != null &&
                departureCode.isNotEmpty &&
                arrivalCode != null &&
                arrivalCode.isNotEmpty) {
              final departureLoc = _getAirportLocation(departureCode);
              final arrivalLoc = _getAirportLocation(arrivalCode);

              if (departureLoc != null && arrivalLoc != null) {
                routes.add(
                  FlightRoute(
                    departure: departureLoc,
                    arrival: arrivalLoc,
                    departureCode: departureCode,
                    arrivalCode: arrivalCode,
                  ),
                );
              }
            }
          }
        }
      }
    }

    return routes;
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;

    // Capture dark mode status before async operations
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    setState(() => _isLoadingMarkers = true);

    try {
      final items = _getItemsForSelectedDate();
      final flightRoutes = _getFlightRoutesForSelectedDate();
      final markers = <Marker>{};
      final polylines = <Polyline>{};
      final bounds = <LatLng>[];
      final orderedLocations =
          <(LatLng, MapItem)>[]; // Track locations with items

      for (int i = 0; i < items.length; i++) {
        if (!mounted) return;

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
          orderedLocations.add((location, item));

          final icon = await _getNumberedMarkerIcon(
            item.type,
            i + 1,
            isDarkMode: isDarkMode,
          );
          markers.add(
            Marker(
              markerId: MarkerId('${item.type.name}_$i'),
              position: location,
              icon: icon,
              infoWindow: InfoWindow(
                title: item.title,
                snippet: item.time != null
                    ? '${item.time} • ${item.address}'
                    : item.address,
              ),
            ),
          );
        }

        // Yield to allow UI to remain responsive
        if (i % 2 == 1) {
          await Future.delayed(Duration.zero);
        }
      }

      // Create polylines for flight routes (geodesic curves)
      for (int i = 0; i < flightRoutes.length; i++) {
        final route = flightRoutes[i];
        polylines.add(
          Polyline(
            polylineId: PolylineId('flight_route_$i'),
            points: [route.departure, route.arrival],
            color: const Color(0xFF9C27B0),
            width: 3,
            geodesic: true,
          ),
        );
      }

      // Create lines connecting consecutive pins (itinerary path)
      for (int i = 0; i < orderedLocations.length - 1; i++) {
        final current = orderedLocations[i];
        final next = orderedLocations[i + 1];
        final isFlightPair =
            current.$2.type == MapItemType.flight &&
            next.$2.type == MapItemType.flight &&
            current.$2.sortOrder == 0 &&
            next.$2.sortOrder == 1;
        if (!isFlightPair) {
          // Add arrow markers evenly spaced along the path (no lines, just arrows)
          final angle = _calculateBearing(current.$1, next.$1);
          final arrowIcon = await _getArrowIcon(Colors.orange, angle);

          const arrowCount = 8;
          for (int j = 1; j <= arrowCount; j++) {
            final fraction = j / (arrowCount + 1); // Evenly spaced
            final arrowPos = LatLng(
              current.$1.latitude +
                  (next.$1.latitude - current.$1.latitude) * fraction,
              current.$1.longitude +
                  (next.$1.longitude - current.$1.longitude) * fraction,
            );
            markers.add(
              Marker(
                markerId: MarkerId('arrow_${i}_$j'),
                position: arrowPos,
                icon: arrowIcon,
                anchor: const Offset(0.5, 0.5),
              ),
            );
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _markers = markers;
        _polylines = polylines;
        _isLoadingMarkers = false;
      });

      // Fit camera to show all markers - use post-frame callback to avoid race condition
      if (bounds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _mapController == null) return;
          _fitBounds(bounds);
        });
      }
    } catch (e) {
      debugPrint('TripMapScreen: Error updating markers: $e');
      if (mounted) {
        setState(() => _isLoadingMarkers = false);
      }
    }
  }

  Color _getMarkerColor(MapItemType type) {
    switch (type) {
      case MapItemType.activity:
        return Colors.orange;
      case MapItemType.hotel:
        return Colors.blue;
      case MapItemType.flight:
        return Colors.purple;
    }
  }

  BitmapDescriptor _getDefaultMarkerIcon(MapItemType type) {
    switch (type) {
      case MapItemType.activity:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueOrange,
        );
      case MapItemType.hotel:
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      case MapItemType.flight:
        return BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueViolet,
        );
    }
  }

  Future<BitmapDescriptor> _getNumberedMarkerIcon(
    MapItemType type,
    int number, {
    bool isDarkMode = false,
  }) async {
    final cacheKey = '${type.name}_${number}_${isDarkMode ? 'dark' : 'light'}';
    final cached = _markerIconCache[cacheKey];
    if (cached != null) return cached;

    try {
      final color = _getMarkerColor(type);
      const width = 44.0;
      const height = 60.0;
      const circleRadius = 16.0;
      const circleY = circleRadius + 6; // Center of circle from top

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Draw pin shape (teardrop)
      final paint = Paint()..color = color;
      final path = Path();

      // Pin body - starts from bottom point
      path.moveTo(width / 2, height - 2); // Bottom point
      path.quadraticBezierTo(4, circleY + 8, 4, circleY);
      path.arcToPoint(
        Offset(width - 4, circleY),
        radius: const Radius.circular(circleRadius + 2),
        clockwise: true,
      );
      path.quadraticBezierTo(width - 4, circleY + 8, width / 2, height - 2);
      path.close();

      canvas.drawPath(path, paint);

      // Draw border around pin for better visibility
      final borderPaint = Paint()
        ..color = isDarkMode
            ? Colors.white
            : Colors.black.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawPath(path, borderPaint);

      // Draw number in white
      final textPainter = TextPainter(
        text: TextSpan(
          text: number.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          width / 2 - textPainter.width / 2,
          circleY - textPainter.height / 2,
        ),
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

      if (bytes == null) {
        return _getDefaultMarkerIcon(type);
      }

      final icon = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
      _markerIconCache[cacheKey] = icon;
      return icon;
    } catch (e) {
      debugPrint('Failed to create numbered marker: $e');
      return _getDefaultMarkerIcon(type);
    }
  }

  /// Calculate bearing angle between two points (in radians for canvas rotation)
  double _calculateBearing(LatLng start, LatLng end) {
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    // atan2 gives angle from positive X axis, we need from positive Y (north)
    // Canvas rotation: 0 = up, positive = clockwise
    return math.atan2(dLng, dLat);
  }

  /// Create arrow icon for direction indicator
  Future<BitmapDescriptor> _getArrowIcon(Color color, double bearing) async {
    const size = 24.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Rotate canvas to point in direction of travel
    canvas.translate(size / 2, size / 2);
    canvas.rotate(bearing);
    canvas.translate(-size / 2, -size / 2);

    // Draw arrow pointing up (will be rotated)
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size / 2, 4); // Top point
    path.lineTo(size - 4, size - 4); // Bottom right
    path.lineTo(size / 2, size - 8); // Bottom center notch
    path.lineTo(4, size - 4); // Bottom left
    path.close();

    canvas.drawPath(path, paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      return BitmapDescriptor.defaultMarker;
    }

    return BitmapDescriptor.bytes(bytes.buffer.asUint8List());
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty || _mapController == null) return;

    if (points.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 12),
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

    // Use generous pixel padding to ensure pins are visible at edges
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
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
                    polylines: _polylines,
                    style: Theme.of(context).brightness == Brightness.dark
                        ? _darkMapStyle
                        : _lightMapStyle,
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
                    zoomGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                  ),
                // Loading indicator - IgnorePointer so it doesn't block map gestures
                if (_isLoadingMarkers)
                  IgnorePointer(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.1),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF7043),
                        ),
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
  final int
  sortOrder; // For maintaining logical order (e.g., departure before arrival)

  const MapItem({
    required this.title,
    required this.address,
    required this.type,
    this.time,
    this.subtitle,
    this.airportCode,
    this.sortOrder = 0,
  });
}

class FlightRoute {
  final LatLng departure;
  final LatLng arrival;
  final String departureCode;
  final String arrivalCode;

  const FlightRoute({
    required this.departure,
    required this.arrival,
    required this.departureCode,
    required this.arrivalCode,
  });
}
