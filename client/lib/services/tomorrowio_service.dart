import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'openweathermap_service.dart' show HourlyWeather;

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

    try {
      // Use Timeline API for hourly forecast
      final targetDate = DateTime(date.year, date.month, date.day);
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
      iconCode: _getIconCodeFromWeatherCode(weatherCode),
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

  /// Map Tomorrow.io weather codes to OpenWeatherMap-style icon codes
  /// for compatibility with existing UI
  String _getIconCodeFromWeatherCode(int code) {
    return switch (code) {
      1000 => '01d', // Clear
      1100 => '01d', // Mostly Clear
      1101 => '02d', // Partly Cloudy
      1102 => '03d', // Mostly Cloudy
      1001 => '04d', // Cloudy
      2000 || 2100 => '50d', // Fog
      4000 || 4200 => '09d', // Drizzle/Light Rain
      4001 || 4201 => '10d', // Rain/Heavy Rain
      5000 || 5001 || 5100 || 5101 => '13d', // Snow
      6000 || 6001 || 6200 || 6201 => '13d', // Freezing Rain
      7000 || 7101 || 7102 => '13d', // Ice Pellets
      8000 => '11d', // Thunderstorm
      _ => '01d',
    };
  }
}
