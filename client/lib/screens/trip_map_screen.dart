import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
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
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  List<Marker> _arrowMarkers = [];
  List<Marker> _flightIconMarkers = [];
  List<Polyline> _polylines = [];
  bool _isLoadingMarkers = true;
  double _currentZoom = 2;
  List<(LatLng, MapItem)> _orderedLocations = [];
  final Map<String, LatLng?> _geocodeCache = {};

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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime _normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  Future<LatLng?> _geocodeAddress(String address) async {
    if (_geocodeCache.containsKey(address)) return _geocodeCache[address];

    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';
    if (apiKey.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeComponent(address)}&key=$apiKey',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final loc = data['results'][0]['geometry']['location'];
          final latLng = LatLng(loc['lat'], loc['lng']);
          _geocodeCache[address] = latLng;
          return latLng;
        }
      }
    } catch (_) {}
    _geocodeCache[address] = null;
    return null;
  }

  LatLng? _getAirportLocation(String iataCode) {
    final airport = AirportsService.instance.getByIata(iataCode);
    return (airport?.lat != null && airport?.lon != null)
        ? LatLng(airport!.lat!, airport.lon!)
        : null;
  }

  List<MapItem> _getItemsForSelectedDate() {
    final items = <MapItem>[];

    // Activities
    for (final activity in widget.trip.activities ?? []) {
      final data = activity as Map<String, dynamic>;
      final date = DateTime.tryParse(data['date'] as String? ?? '');
      final location = data['location'] as String?;

      if (date != null &&
          location?.isNotEmpty == true &&
          _isSameDay(date, _selectedDate)) {
        items.add(
          MapItem(
            title: data['title'] as String? ?? 'Activity',
            address: location!,
            type: MapItemType.activity,
            time: data['time'] as String?,
          ),
        );
      }
    }

    // Accommodations
    for (final acc in widget.trip.accommodations ?? []) {
      final data = acc as Map<String, dynamic>;
      final address = data['address'] as String?;
      if (address?.isEmpty != false) continue;

      final checkIn = DateTime.tryParse(data['checkIn'] as String? ?? '');
      final checkOut = DateTime.tryParse(data['checkOut'] as String? ?? '');
      final name = data['name'] as String? ?? 'Hotel';

      if (checkIn != null && _isSameDay(checkIn, _selectedDate)) {
        items.add(
          MapItem(
            title: name,
            address: address!,
            type: MapItemType.hotel,
            subtitle: 'Check-in',
          ),
        );
      }
      if (checkOut != null && _isSameDay(checkOut, _selectedDate)) {
        items.add(
          MapItem(
            title: name,
            address: address!,
            type: MapItemType.hotel,
            subtitle: 'Check-out',
          ),
        );
      }
    }

    // Flights
    for (final flight in widget.trip.flights ?? []) {
      final data = flight as Map<String, dynamic>;
      final date = DateTime.tryParse(data['departureDate'] as String? ?? '');
      if (date == null || !_isSameDay(date, _selectedDate)) continue;

      final depCode = data['departureAirportCode'] as String?;
      final arrCode = data['arrivalAirportCode'] as String?;
      final depTime = data['departureTime'] as String?;

      if (depCode?.isNotEmpty == true) {
        final airport = AirportsService.instance.getByIata(depCode!);
        items.add(
          MapItem(
            title: 'Departure: $depCode',
            address: airport?.name ?? '$depCode Airport',
            type: MapItemType.flight,
            time: depTime,
            airportCode: depCode,
            sortOrder: 0,
          ),
        );
      }
      if (arrCode?.isNotEmpty == true) {
        final airport = AirportsService.instance.getByIata(arrCode!);
        items.add(
          MapItem(
            title: 'Arrival: $arrCode',
            address: airport?.name ?? '$arrCode Airport',
            type: MapItemType.flight,
            time: depTime,
            airportCode: arrCode,
            sortOrder: 1,
          ),
        );
      }
    }

    // Sort by time, then sortOrder
    items.sort((a, b) {
      final timeA = parseTimeToMinutes(a.time);
      final timeB = parseTimeToMinutes(b.time);
      if (timeA == null && timeB == null)
        return a.sortOrder.compareTo(b.sortOrder);
      if (timeA == null) return 1;
      if (timeB == null) return -1;
      final cmp = timeA.compareTo(timeB);
      return cmp != 0 ? cmp : a.sortOrder.compareTo(b.sortOrder);
    });

    return items;
  }

  List<_FlightRoute> _getFlightRoutesForSelectedDate() {
    final routes = <_FlightRoute>[];
    for (final flight in widget.trip.flights ?? []) {
      final data = flight as Map<String, dynamic>;
      final date = DateTime.tryParse(data['departureDate'] as String? ?? '');
      if (date == null || !_isSameDay(date, _selectedDate)) continue;

      final depCode = data['departureAirportCode'] as String?;
      final arrCode = data['arrivalAirportCode'] as String?;
      if (depCode?.isEmpty != false || arrCode?.isEmpty != false) continue;

      final depLoc = _getAirportLocation(depCode!);
      final arrLoc = _getAirportLocation(arrCode!);
      if (depLoc != null && arrLoc != null) {
        routes.add(_FlightRoute(departure: depLoc, arrival: arrLoc));
      }
    }
    return routes;
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;
    setState(() => _isLoadingMarkers = true);

    try {
      final items = _getItemsForSelectedDate();
      final flightRoutes = _getFlightRoutesForSelectedDate();
      final markers = <Marker>[];
      final arrowMarkers = <Marker>[];
      final polylines = <Polyline>[];
      final bounds = <LatLng>[];
      final orderedLocations = <(LatLng, MapItem)>[];

      // Create numbered markers
      for (int i = 0; i < items.length; i++) {
        if (!mounted) return;
        final item = items[i];
        final location = item.airportCode != null
            ? _getAirportLocation(item.airportCode!)
            : await _geocodeAddress(item.address);

        if (location != null) {
          bounds.add(location);
          orderedLocations.add((location, item));
          markers.add(_buildNumberedMarker(location, i + 1, item));
        }
      }

      // Flight route polylines with airplane icon at midpoint
      for (final route in flightRoutes) {
        final routePoints = _getGeodesicPoints(route.departure, route.arrival);
        polylines.add(
          Polyline(
            points: routePoints,
            strokeWidth: 3,
            color: const Color(0xFF9C27B0),
          ),
        );

        // Add airplane icon at midpoint
        final midIndex = routePoints.length ~/ 2;
        final midPoint = routePoints[midIndex];
        final angle = math.atan2(
          route.arrival.longitude - route.departure.longitude,
          route.arrival.latitude - route.departure.latitude,
        );
        arrowMarkers.add(
          Marker(
            point: midPoint,
            width: 36,
            height: 36,
            child: Transform.rotate(
              angle: angle,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // White border/shadow layer
                  Icon(
                    Icons.airplanemode_active,
                    color: Colors.white,
                    size: 30,
                    shadows: const [
                      Shadow(color: Colors.white, blurRadius: 3),
                      Shadow(color: Colors.white, blurRadius: 6),
                    ],
                  ),
                  // Purple icon on top
                  const Icon(
                    Icons.airplanemode_active,
                    color: Color(0xFF9C27B0),
                    size: 26,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _markers = markers;
        _orderedLocations = orderedLocations;
        _flightIconMarkers = arrowMarkers; // Store airplane icons
        _arrowMarkers = _buildArrowMarkers(orderedLocations, arrowMarkers);
        _polylines = polylines;
        _isLoadingMarkers = false;
      });

      if (bounds.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _fitBounds(bounds);
        });
      }
    } catch (e) {
      debugPrint('TripMapScreen: Error updating markers: $e');
      if (mounted) setState(() => _isLoadingMarkers = false);
    }
  }

  Marker _buildNumberedMarker(LatLng location, int number, MapItem item) {
    final color = _getMarkerColor(item.type);
    final subtitle = item.time != null
        ? '${item.time} • ${item.address}'
        : item.address;

    return Marker(
      point: location,
      width: 36,
      height: 36,
      child: GestureDetector(
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(subtitle, style: const TextStyle(fontSize: 12)),
              ],
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          alignment: Alignment.center,
          child: Text(
            number.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Build arrow markers with count based on zoom level and distance
  List<Marker> _buildArrowMarkers(
    List<(LatLng, MapItem)> orderedLocations,
    List<Marker> flightArrows,
  ) {
    final arrows = List<Marker>.from(flightArrows);
    if (_currentZoom < 6) return arrows;

    final distance = const Distance();

    for (int i = 0; i < orderedLocations.length - 1; i++) {
      final (curr, currItem) = orderedLocations[i];
      final (next, nextItem) = orderedLocations[i + 1];

      final isFlightPair =
          currItem.type == MapItemType.flight &&
          nextItem.type == MapItemType.flight &&
          currItem.sortOrder == 0 &&
          nextItem.sortOrder == 1;

      if (!isFlightPair) {
        // Calculate distance between markers in km
        final dist = distance.as(LengthUnit.Kilometer, curr, next);

        // Scale arrows: more arrows for longer distances, scaled by zoom
        // At zoom 6: ~2-5 arrows, at zoom 14+: up to 20 arrows
        final zoomFactor = ((_currentZoom - 4) * 0.8).clamp(1, 4);
        final distFactor = (dist / 2).clamp(1, 10); // 1 arrow per 2km, max 10x
        final arrowCount = (zoomFactor * distFactor).clamp(2, 20).toInt();

        final angle = math.atan2(
          next.longitude - curr.longitude,
          next.latitude - curr.latitude,
        );
        // Evenly distribute arrows along the path (avoiding endpoints)
        for (int j = 0; j < arrowCount; j++) {
          final t = (j + 1) / (arrowCount + 1);
          arrows.add(
            Marker(
              point: LatLng(
                curr.latitude + (next.latitude - curr.latitude) * t,
                curr.longitude + (next.longitude - curr.longitude) * t,
              ),
              width: 20,
              height: 20,
              child: Transform.rotate(
                angle: angle,
                child: const Icon(
                  Icons.navigation,
                  color: Colors.orange,
                  size: 12,
                ),
              ),
            ),
          );
        }
      }
    }
    return arrows;
  }

  List<LatLng> _getGeodesicPoints(
    LatLng start,
    LatLng end, {
    int segments = 50,
  }) {
    final distance = const Distance();
    final totalDist = distance.as(LengthUnit.Kilometer, start, end);

    return List.generate(segments + 1, (i) {
      final t = i / segments;
      final lat = start.latitude + (end.latitude - start.latitude) * t;
      final lng = start.longitude + (end.longitude - start.longitude) * t;

      if (totalDist < 500) return LatLng(lat, lng);

      // Add arc for longer distances
      final curve = math.sin(t * math.pi);
      return LatLng(lat + curve * totalDist * 0.0005, lng);
    });
  }

  Color _getMarkerColor(MapItemType type) => switch (type) {
    MapItemType.activity => Colors.orange,
    MapItemType.hotel => Colors.blue,
    MapItemType.flight => Colors.purple,
  };

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      _mapController.move(points.first, 12);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
        maxZoom: 15,
      ),
    );
  }

  Map<DateTime, int> get _eventCountsPerDay {
    final counts = <DateTime, int>{};

    void addDate(String? dateStr) {
      final date = DateTime.tryParse(dateStr ?? '');
      if (date != null)
        counts[_normalizeDate(date)] = (counts[_normalizeDate(date)] ?? 0) + 1;
    }

    for (final f in widget.trip.flights ?? []) {
      addDate((f as Map<String, dynamic>)['departureDate'] as String?);
    }
    for (final a in widget.trip.accommodations ?? []) {
      final data = a as Map<String, dynamic>;
      addDate(data['checkIn'] as String?);
      final checkOut = data['checkOut'] as String?;
      final checkIn = data['checkIn'] as String?;
      if (checkOut != checkIn) addDate(checkOut);
    }
    for (final a in widget.trip.activities ?? []) {
      addDate((a as Map<String, dynamic>)['date'] as String?);
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip.name),
        backgroundColor: const Color(0xFFFF7043),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildDaysCarousel(),
          Expanded(child: _buildMap(isDark)),
        ],
      ),
    );
  }

  Widget _buildDaysCarousel() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Hero(
            tag: 'days-carousel-${widget.trip.id}',
            flightShuttleBuilder: (_, __, ___, ____, toCtx) =>
                Material(color: Colors.transparent, child: toCtx.widget),
            child: DaysCarousel(
              startDate: _startDate,
              endDate: _endDate,
              selectedDate: _selectedDate,
              eventCounts: _eventCountsPerDay,
              onDateSelected: (date) {
                setState(() => _selectedDate = date);
                _updateMarkers();
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: const LatLng(0, 0),
            initialZoom: 2,
            minZoom: 0,
            maxZoom: 18,
            backgroundColor: isDark
                ? const Color(0xFF1d2c4d)
                : const Color(0xFFE8E8E8),
            onPositionChanged: (position, hasGesture) {
              if (position.zoom != _currentZoom) {
                final oldZoom = _currentZoom;
                _currentZoom = position.zoom;
                // Rebuild arrows if zoom changed by 1+ level or crossed threshold
                final crossedThreshold = (oldZoom < 6) != (_currentZoom < 6);
                final zoomChanged = (oldZoom - _currentZoom).abs() >= 1;
                if ((crossedThreshold || zoomChanged) &&
                    _orderedLocations.isNotEmpty) {
                  setState(() {
                    _arrowMarkers = _buildArrowMarkers(
                      _orderedLocations,
                      _flightIconMarkers,
                    );
                  });
                }
              }
            },
          ),
          children: [
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.travel_organizer',
              retinaMode: true,
            ),
            PolylineLayer(polylines: _polylines),
            MarkerLayer(markers: _arrowMarkers),
            MarkerLayer(markers: _markers),
            RichAttributionWidget(
              popupInitialDisplayDuration: Duration.zero,
              animationConfig: const ScaleRAWA(),
              attributions: [
                TextSourceAttribution('CARTO', onTap: () {}),
                TextSourceAttribution(
                  'OpenStreetMap contributors',
                  onTap: () {},
                ),
              ],
            ),
          ],
        ),
        if (_isLoadingMarkers) _buildLoadingOverlay(),
        if (!_isLoadingMarkers && _markers.isEmpty) _buildEmptyState(),
        if (_markers.isNotEmpty) _buildLegend(),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.1),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF7043)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final color = Theme.of(context).colorScheme.onSurface;
    return Center(
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
              color: color.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'No locations for this day',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: color.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add flights, hotels, or activities to see them on the map',
              style: TextStyle(
                fontSize: 13,
                color: color.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      left: 24,
      bottom: 24,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LegendItem(color: Colors.purple, label: 'Flight'),
            SizedBox(width: 12),
            _LegendItem(color: Colors.blue, label: 'Hotel'),
            SizedBox(width: 12),
            _LegendItem(color: Colors.orange, label: 'Activity'),
          ],
        ),
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
  final int sortOrder;

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

class _FlightRoute {
  final LatLng departure;
  final LatLng arrival;
  const _FlightRoute({required this.departure, required this.arrival});
}
