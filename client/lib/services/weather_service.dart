import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../utils/time_format.dart';
import 'airports_service.dart';
import 'convex_service.dart';
import 'openweathermap_service.dart';
import 'tomorrowio_service.dart';

// Re-export weather models for consumers
export 'openweathermap_service.dart' show DailyWeather, HourlyWeather;
// WeatherCondition is defined in this file and exported directly

/// Supported weather API providers
enum WeatherApiType { openWeather, tomorrowIo }

/// Unified weather condition codes
/// Both OpenWeatherMap and Tomorrow.io map to these conditions
enum WeatherCondition {
  clear, // Clear sky
  fewClouds, // Few clouds (11-25%)
  cloudy, // Scattered/broken/overcast clouds
  mist, // Mist, fog, haze
  drizzle, // Light rain, drizzle
  rain, // Rain, heavy rain
  thunderstorm, // Thunderstorm
  snow, // Snow, sleet, ice
  unknown, // Unknown condition
}

/// Extension to get display name and icon for weather conditions
extension WeatherConditionExtension on WeatherCondition {
  String get displayName => switch (this) {
    WeatherCondition.clear => 'Clear',
    WeatherCondition.fewClouds => 'Partly Cloudy',
    WeatherCondition.cloudy => 'Cloudy',
    WeatherCondition.mist => 'Mist',
    WeatherCondition.drizzle => 'Drizzle',
    WeatherCondition.rain => 'Rain',
    WeatherCondition.thunderstorm => 'Thunderstorm',
    WeatherCondition.snow => 'Snow',
    WeatherCondition.unknown => 'Unknown',
  };

  /// Map OpenWeatherMap icon codes (e.g., "01d", "10n") to WeatherCondition
  static WeatherCondition fromOpenWeatherCode(String iconCode) {
    if (iconCode.startsWith('01') || iconCode.startsWith('02')) {
      return iconCode.startsWith('01')
          ? WeatherCondition.clear
          : WeatherCondition.fewClouds;
    } else if (iconCode.startsWith('03') || iconCode.startsWith('04')) {
      return WeatherCondition.cloudy;
    } else if (iconCode.startsWith('09')) {
      return WeatherCondition.drizzle;
    } else if (iconCode.startsWith('10')) {
      return WeatherCondition.rain;
    } else if (iconCode.startsWith('11')) {
      return WeatherCondition.thunderstorm;
    } else if (iconCode.startsWith('13')) {
      return WeatherCondition.snow;
    } else if (iconCode.startsWith('50')) {
      return WeatherCondition.mist;
    }
    return WeatherCondition.unknown;
  }

  /// Map Tomorrow.io weather codes to WeatherCondition
  static WeatherCondition fromTomorrowIoCode(int code) {
    return switch (code) {
      1000 => WeatherCondition.clear, // Clear
      1100 => WeatherCondition.clear, // Mostly Clear
      1101 => WeatherCondition.fewClouds, // Partly Cloudy
      1102 => WeatherCondition.cloudy, // Mostly Cloudy
      1001 => WeatherCondition.cloudy, // Cloudy
      2000 || 2100 => WeatherCondition.mist, // Fog
      4000 || 4200 => WeatherCondition.drizzle, // Drizzle/Light Rain
      4001 || 4201 => WeatherCondition.rain, // Rain/Heavy Rain
      5000 || 5001 || 5100 || 5101 => WeatherCondition.snow, // Snow
      6000 || 6001 || 6200 || 6201 => WeatherCondition.snow, // Freezing Rain
      7000 || 7101 || 7102 => WeatherCondition.snow, // Ice Pellets
      8000 => WeatherCondition.thunderstorm, // Thunderstorm
      _ => WeatherCondition.unknown,
    };
  }
}

/// Location coordinates
class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);
}

/// Cached weather result with timestamp
class _CachedWeather {
  final List<HourlyWeather>? data;
  final DateTime fetchedAt;

  _CachedWeather(this.data) : fetchedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(fetchedAt).inMinutes > 5; // 5 min TTL
}

/// Singleton service for weather data and location resolution
class WeatherService {
  static WeatherService? _instance;
  final Map<String, LatLng?> _geocodeCache = {};
  final Map<String, _CachedWeather> _weatherCache = {};
  // Trip-level cache: tripId_date -> weather (for fast sync lookup across screen navigations)
  final Map<String, _CachedWeather> _tripWeatherCache = {};
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

  /// Build cache key for weather lookup
  String _buildWeatherCacheKey(double lat, double lng, DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return '${lat.toStringAsFixed(2)}_${lng.toStringAsFixed(2)}_${dateKey}_${_apiType.name}';
  }

  /// Synchronously check if we have valid cached weather data
  List<HourlyWeather>? getCachedWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) {
    final cacheKey = _buildWeatherCacheKey(lat, lng, date);
    final cached = _weatherCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    return null;
  }

  /// Build cache key for trip-level weather lookup
  String _buildTripCacheKey(String tripId, DateTime date) {
    final dateKey = '${date.year}-${date.month}-${date.day}';
    return '${tripId}_$dateKey';
  }

  /// Synchronously check if we have valid cached weather for a trip+date
  /// This allows fast lookup without needing to geocode
  List<HourlyWeather>? getCachedTripWeather({
    required String tripId,
    required DateTime date,
  }) {
    final cacheKey = _buildTripCacheKey(tripId, date);
    final cached = _tripWeatherCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }
    return null;
  }

  /// Cache weather data for a trip+date
  void cacheTripWeather(
    String tripId,
    DateTime date,
    List<HourlyWeather>? data,
  ) {
    final cacheKey = _buildTripCacheKey(tripId, date);
    _tripWeatherCache[cacheKey] = _CachedWeather(data);
  }

  /// Invalidate weather cache for a specific trip+date
  /// Call when activities/hotels/flights change for that date
  void invalidateCacheForDate(String tripId, DateTime date) {
    final cacheKey = _buildTripCacheKey(tripId, date);
    _tripWeatherCache.remove(cacheKey);
  }

  /// Invalidate all weather cache for a trip
  void invalidateCacheForTrip(String tripId) {
    _tripWeatherCache.removeWhere((key, _) => key.startsWith('${tripId}_'));
  }

  /// Fetch hourly weather for a location and date (with caching)
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final cacheKey = _buildWeatherCacheKey(lat, lng, date);

    // Check cache
    final cached = _weatherCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.data;
    }

    // Fetch fresh data
    final List<HourlyWeather>? result;
    switch (_apiType) {
      case WeatherApiType.openWeather:
        result = await OpenWeatherMapService.instance.getHourlyWeather(
          lat: lat,
          lng: lng,
          date: date,
        );
      case WeatherApiType.tomorrowIo:
        result = await TomorrowIoService.instance.getHourlyWeather(
          lat: lat,
          lng: lng,
          date: date,
        );
    }

    // Cache the result
    _weatherCache[cacheKey] = _CachedWeather(result);
    return result;
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
    final flightLocation = _getFlightDestination(trip, date);
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

  LatLng? _getFlightDestination(Trip trip, DateTime date) {
    if (trip.flights == null || trip.flights!.isEmpty) return null;

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
    } catch (_) {
      // Geocoding failed
    }

    _geocodeCache[address] = null;
    return null;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
