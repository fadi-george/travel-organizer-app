import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'openweathermap_service.dart' show DailyWeather, HourlyWeather;
import 'weather_service.dart' show WeatherConditionExtension;

/// Service for fetching weather data from Tomorrow.io API
class TomorrowIoService {
  static TomorrowIoService? _instance;

  TomorrowIoService._();

  static TomorrowIoService get instance {
    _instance ??= TomorrowIoService._();
    return _instance!;
  }

  String? get _apiKey => dotenv.env['TOMORROWIO_API_KEY'];

  /// Fetch hourly weather for a location and date
  /// Returns weather for 8am, 10am, 12pm, 2pm, 4pm, 6pm, 8pm, 10pm, 12am
  /// Note: Free tier limited to 5 days ahead
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('TomorrowIoService: API key not configured');
      return null;
    }

    // Free tier limitation: max 5 days ahead
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    final daysAhead = targetDate.difference(today).inDays;

    // Free tier: hourly up to 5 days, daily up to 14 days
    if (daysAhead > 5) {
      debugPrint('TomorrowIoService: Falling back to daily forecast ($daysAhead days ahead)');
      return _getDailyAsFallback(lat: lat, lng: lng, date: date);
    }

    try {
      // Use Timeline API for hourly forecast
      final startTime = targetDate.toUtc().toIso8601String();
      final endTime = targetDate
          .add(const Duration(days: 1, hours: 1))
          .toUtc()
          .toIso8601String();

      final url = Uri.parse(
        'https://api.tomorrow.io/v4/timelines'
        '?location=$lat,$lng'
        '&fields=temperature,weatherCode,precipitationProbability'
        '&timesteps=1h'
        '&startTime=$startTime'
        '&endTime=$endTime'
        '&units=imperial'
        '&apikey=$apiKey',
      );

      final response = await http.get(
        url,
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        debugPrint('TomorrowIoService: API error ${response.statusCode}');
        debugPrint('TomorrowIoService: ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      final timelines = data['data']?['timelines'] as List<dynamic>?;
      if (timelines == null || timelines.isEmpty) return null;

      final intervals = timelines.first['intervals'] as List<dynamic>?;
      if (intervals == null) return null;

      // Parse all hourly data
      final allHours = intervals.map(_parseInterval).toList();

      // Filter to target hours: 8, 10, 12, 14, 16, 18, 20, 22, 0 (midnight)
      final targetHours = [8, 10, 12, 14, 16, 18, 20, 22, 0];
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
      debugPrint('TomorrowIoService: Error fetching weather: $e');
      return null;
    }
  }

  HourlyWeather _parseInterval(dynamic interval) {
    final data = interval as Map<String, dynamic>;
    final startTime = DateTime.parse(data['startTime'] as String);
    final values = data['values'] as Map<String, dynamic>;

    final temp = (values['temperature'] as num?)?.toDouble() ?? 0;
    final weatherCode = values['weatherCode'] as int? ?? 1000;
    final precipProb =
        (values['precipitationProbability'] as num?)?.toDouble() ?? 0;

    return HourlyWeather(
      time: startTime.toLocal(),
      temperature: temp,
      condition: _getConditionFromCode(weatherCode),
      weatherCondition: WeatherConditionExtension.fromTomorrowIoCode(weatherCode),
      precipitationChance: precipProb.round(),
    );
  }

  /// Map Tomorrow.io weather codes to condition names
  String _getConditionFromCode(int code) {
    return switch (code) {
      0 => 'Unknown',
      1000 => 'Clear',
      1100 => 'Mostly Clear',
      1101 => 'Partly Cloudy',
      1102 => 'Mostly Cloudy',
      1001 => 'Cloudy',
      2000 => 'Fog',
      2100 => 'Light Fog',
      4000 => 'Drizzle',
      4001 => 'Rain',
      4200 => 'Light Rain',
      4201 => 'Heavy Rain',
      5000 => 'Snow',
      5001 => 'Flurries',
      5100 => 'Light Snow',
      5101 => 'Heavy Snow',
      6000 => 'Freezing Drizzle',
      6001 => 'Freezing Rain',
      6200 => 'Light Freezing Rain',
      6201 => 'Heavy Freezing Rain',
      7000 => 'Ice Pellets',
      7101 => 'Heavy Ice Pellets',
      7102 => 'Light Ice Pellets',
      8000 => 'Thunderstorm',
      _ => 'Unknown',
    };
  }

  /// Fallback: fetch daily forecast and convert to hourly-like format
  /// Used when date is beyond hourly forecast limit
  Future<List<HourlyWeather>?> _getDailyAsFallback({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final daily = await getDailyWeather(lat: lat, lng: lng, date: date);
    if (daily == null) return null;

    // Return single entry with daily temps at noon
    return [
      HourlyWeather(
        time: DateTime(date.year, date.month, date.day, 12),
        temperature: daily.tempHigh,
        condition: daily.condition,
        weatherCondition: daily.weatherCondition,
        precipitationChance: daily.precipitationChance,
        tempHigh: daily.tempHigh,
        tempLow: daily.tempLow,
      ),
    ];
  }

  /// Fetch daily weather for a specific date using the forecast endpoint
  /// Note: Free tier limited to 5 days for daily as well
  Future<DailyWeather?> getDailyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('TomorrowIoService: API key not configured');
      return null;
    }

    try {
      // Use the forecast endpoint which provides daily forecasts
      final url = Uri.parse(
        'https://api.tomorrow.io/v4/weather/forecast'
        '?location=$lat,$lng'
        '&units=imperial'
        '&apikey=$apiKey',
      );

      final response = await http.get(
        url,
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode != 200) {
        debugPrint('TomorrowIoService: Forecast API error ${response.statusCode}');
        debugPrint('TomorrowIoService: ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      final dailyData = data['timelines']?['daily'] as List<dynamic>?;
      if (dailyData == null || dailyData.isEmpty) return null;

      // Find the matching day in the forecast
      final targetDate = DateTime(date.year, date.month, date.day);
      for (final day in dailyData) {
        final dayData = day as Map<String, dynamic>;
        final timeStr = dayData['time'] as String?;
        if (timeStr == null) continue;

        final dayTime = DateTime.parse(timeStr).toLocal();
        final dayDate = DateTime(dayTime.year, dayTime.month, dayTime.day);

        if (dayDate == targetDate) {
          final values = dayData['values'] as Map<String, dynamic>;
          final tempHigh = (values['temperatureMax'] as num?)?.toDouble() ?? 0;
          final tempLow = (values['temperatureMin'] as num?)?.toDouble() ?? 0;
          final weatherCode = values['weatherCodeMax'] as int? ?? 1000;
          final precipProb =
              (values['precipitationProbabilityMax'] as num?)?.toDouble() ?? 0;

          return DailyWeather(
            date: targetDate,
            tempHigh: tempHigh,
            tempLow: tempLow,
            condition: _getConditionFromCode(weatherCode),
            weatherCondition: WeatherConditionExtension.fromTomorrowIoCode(weatherCode),
            precipitationChance: precipProb.round(),
          );
        }
      }

      debugPrint('TomorrowIoService: Date not found in forecast range');
      return null;
    } catch (e) {
      debugPrint('TomorrowIoService: Error fetching daily weather: $e');
      return null;
    }
  }
}
