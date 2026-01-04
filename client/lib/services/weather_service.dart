import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../utils/time_format.dart';
import 'airports_service.dart';
import 'openweathermap_service.dart';

// Re-export HourlyWeather for consumers
export 'openweathermap_service.dart' show HourlyWeather;

/// Supported weather API providers
enum WeatherApiType { openWeather }

/// Location coordinates
class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);
}

/// Singleton service for weather data and location resolution
class WeatherService {
  static WeatherService? _instance;
  final Map<String, LatLng?> _geocodeCache = {};
  final WeatherApiType _apiType;

  WeatherService._(this._apiType);

  static WeatherService get instance {
    _instance ??= WeatherService._(WeatherApiType.openWeather);
    return _instance!;
  }

  /// Get instance with specific API type
  static WeatherService withType(WeatherApiType type) {
    if (_instance == null || _instance!._apiType != type) {
      _instance = WeatherService._(type);
    }
    return _instance!;
  }

  String? get _googleApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'];

  /// Fetch hourly weather for a location and date
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) {
    switch (_apiType) {
      case WeatherApiType.openWeather:
        return OpenWeatherMapService.instance.getHourlyWeather(
          lat: lat,
          lng: lng,
          date: date,
        );
      // Add other cases here when new providers are added
    }
  }

  /// Get the best location for weather based on trip data for a specific date
  /// Priority: 1) Last activity with location, 2) Hotel, 3) Flight destination
  Future<LatLng?> getLocationForDate(Trip trip, DateTime date) async {
    // 1. Try last activity's location (sorted by time)
    final activityLocation = await _getLastActivityLocation(trip, date);
    if (activityLocation != null) return activityLocation;

    // 2. Try hotel location (check-in or staying that night)
    final hotelLocation = await _getHotelLocation(trip, date);
    if (hotelLocation != null) return hotelLocation;

    // 3. Try flight destination (arrival airport)
    final flightLocation = await _getFlightDestination(trip, date);
    if (flightLocation != null) return flightLocation;

    return null;
  }

  Future<LatLng?> _getLastActivityLocation(Trip trip, DateTime date) async {
    if (trip.activities == null || trip.activities!.isEmpty) return null;

    // Get activities for this date with locations
    final activitiesForDate = <Map<String, dynamic>>[];
    for (final activity in trip.activities!) {
      final data = activity as Map<String, dynamic>;
      final dateStr = data['date'] as String?;
      final location = data['location'] as String?;

      if (dateStr != null && location != null && location.isNotEmpty) {
        final activityDate = DateTime.tryParse(dateStr);
        if (activityDate != null && _isSameDay(activityDate, date)) {
          activitiesForDate.add(data);
        }
      }
    }

    if (activitiesForDate.isEmpty) return null;

    // Sort by time, get last one
    activitiesForDate.sort((a, b) {
      final aTime = a['time'] as String?;
      final bTime = b['time'] as String?;
      final aParsed = parseTime(aTime);
      final bParsed = parseTime(bTime);
      final aMinutes = aParsed != null ? aParsed.$1 * 60 + aParsed.$2 : 0;
      final bMinutes = bParsed != null ? bParsed.$1 * 60 + bParsed.$2 : 0;
      return aMinutes.compareTo(bMinutes);
    });

    final lastActivity = activitiesForDate.last;
    final location = lastActivity['location'] as String;
    return _geocodeAddress(location);
  }

  Future<LatLng?> _getHotelLocation(Trip trip, DateTime date) async {
    if (trip.accommodations == null || trip.accommodations!.isEmpty) {
      return null;
    }

    for (final acc in trip.accommodations!) {
      final data = acc as Map<String, dynamic>;
      final address = data['address'] as String?;
      final checkInStr = data['checkIn'] as String?;
      final checkOutStr = data['checkOut'] as String?;

      if (address == null || address.isEmpty) continue;

      final checkIn = checkInStr != null ? DateTime.tryParse(checkInStr) : null;
      final checkOut = checkOutStr != null
          ? DateTime.tryParse(checkOutStr)
          : null;

      // Check if staying at this hotel on this date
      // (check-in day through day before check-out)
      if (checkIn != null) {
        final isOnOrAfterCheckIn =
            _isSameDay(date, checkIn) || date.isAfter(checkIn);
        final isBeforeCheckOut =
            checkOut == null ||
            date.isBefore(checkOut) ||
            _isSameDay(date, checkIn);

        if (isOnOrAfterCheckIn && isBeforeCheckOut) {
          return _geocodeAddress(address);
        }
      }
    }

    return null;
  }

  Future<LatLng?> _getFlightDestination(Trip trip, DateTime date) async {
    if (trip.flights == null || trip.flights!.isEmpty) return null;

    // Ensure airports are loaded
    await AirportsService.instance.loadAirports();

    for (final flight in trip.flights!) {
      final data = flight as Map<String, dynamic>;
      final departureDateStr = data['departureDate'] as String?;
      final arrivalDateStr = data['arrivalDate'] as String?;
      final arrivalAirportCode = data['arrivalAirportCode'] as String?;

      if (departureDateStr != null && arrivalAirportCode != null) {
        final departureDate = DateTime.tryParse(departureDateStr);
        final arrivalDate = arrivalDateStr != null
            ? DateTime.tryParse(arrivalDateStr)
            : departureDate;

        if (departureDate != null && arrivalDate != null) {
          final isInRange =
              (_isSameDay(date, departureDate) ||
                  date.isAfter(departureDate)) &&
              (_isSameDay(date, arrivalDate) || date.isBefore(arrivalDate));

          if (isInRange) {
            final airport = AirportsService.instance.getByIata(
              arrivalAirportCode,
            );
            if (airport?.lat != null && airport?.lon != null) {
              return LatLng(airport!.lat!, airport.lon!);
            }
          }
        }
      }
    }

    return null;
  }

  Future<LatLng?> _geocodeAddress(String address) async {
    if (_geocodeCache.containsKey(address)) return _geocodeCache[address];

    final apiKey = _googleApiKey;
    if (apiKey == null || apiKey.isEmpty) return null;

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
    } catch (e) {
      debugPrint('WeatherService: Geocoding error: $e');
    }

    _geocodeCache[address] = null;
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
