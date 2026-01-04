import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/trip.dart';
import '../utils/time_format.dart';
import 'airports_service.dart';

/// Represents hourly weather data
class HourlyWeather {
  final DateTime time;
  final double temperature; // Fahrenheit
  final String condition;
  final String iconCode;
  final int precipitationChance; // 0-100

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.iconCode,
    required this.precipitationChance,
  });

  factory HourlyWeather.fromJson(Map<String, dynamic> json) {
    final dt = DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000);
    final temp = (json['temp'] as num).toDouble();
    final weather = (json['weather'] as List).first as Map<String, dynamic>;
    final pop = ((json['pop'] as num?) ?? 0).toDouble();

    return HourlyWeather(
      time: dt,
      temperature: temp,
      condition: weather['main'] as String? ?? 'Unknown',
      iconCode: weather['icon'] as String? ?? '01d',
      precipitationChance: (pop * 100).round(),
    );
  }
}

/// Location coordinates
class LatLng {
  final double lat;
  final double lng;

  const LatLng(this.lat, this.lng);
}

/// Singleton service for weather data
class WeatherService {
  static WeatherService? _instance;
  final Map<String, LatLng?> _geocodeCache = {};

  WeatherService._();

  static WeatherService get instance {
    _instance ??= WeatherService._();
    return _instance!;
  }

  String? get _apiKey => dotenv.env['OPENWEATHERMAP_API_KEY'];
  String? get _googleApiKey => dotenv.env['GOOGLE_PLACES_API_KEY'];

  /// Fetch hourly weather for a location and date
  /// Returns weather for 8am, 10am, 12pm, 2pm, 4pm, 6pm, 8pm, 10pm, 12am
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('WeatherService: OPENWEATHERMAP_API_KEY not configured');
      return null;
    }

    try {
      // Use One Call API 3.0 for hourly forecast
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall'
        '?lat=$lat&lon=$lng'
        '&exclude=minutely,daily,alerts'
        '&units=imperial'
        '&appid=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('WeatherService: API error ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final hourlyData = data['hourly'] as List<dynamic>?;
      if (hourlyData == null) return null;

      // Parse all hourly data
      final allHours = hourlyData
          .map((h) => HourlyWeather.fromJson(h as Map<String, dynamic>))
          .toList();

      // Filter to target hours: 8, 10, 12, 14, 16, 18, 20, 22, 24 (midnight next day)
      final targetHours = [8, 10, 12, 14, 16, 18, 20, 22, 0];
      final targetDate = DateTime(date.year, date.month, date.day);
      final nextDay = targetDate.add(const Duration(days: 1));

      final filtered = <HourlyWeather>[];
      for (final hour in targetHours) {
        final targetTime = hour == 0
            ? DateTime(nextDay.year, nextDay.month, nextDay.day, 0)
            : DateTime(targetDate.year, targetDate.month, targetDate.day, hour);

        // Find closest hour in data
        HourlyWeather? closest;
        int minDiff = 999999;
        for (final weather in allHours) {
          final diff = (weather.time.difference(targetTime).inMinutes).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closest = weather;
          }
        }
        if (closest != null && minDiff <= 90) {
          filtered.add(closest);
        }
      }

      return filtered;
    } catch (e) {
      debugPrint('WeatherService: Error fetching weather: $e');
      return null;
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
