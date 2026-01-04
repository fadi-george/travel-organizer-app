import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
}

/// Represents daily weather data
class DailyWeather {
  final DateTime date;
  final double tempHigh; // Fahrenheit
  final double tempLow; // Fahrenheit
  final String condition;
  final String iconCode;
  final int precipitationChance; // 0-100

  const DailyWeather({
    required this.date,
    required this.tempHigh,
    required this.tempLow,
    required this.condition,
    required this.iconCode,
    required this.precipitationChance,
  });
}

/// Service for fetching weather data from OpenWeatherMap API
class OpenWeatherMapService {
  static OpenWeatherMapService? _instance;

  OpenWeatherMapService._();

  static OpenWeatherMapService get instance {
    _instance ??= OpenWeatherMapService._();
    return _instance!;
  }

  String? get _apiKey => dotenv.env['OPENWEATHERMAP_API_KEY'];

  /// Fetch hourly weather for a location and date
  /// Returns weather for 8am, 10am, 12pm, 2pm, 4pm, 6pm, 8pm, 10pm, 12am
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    debugPrint('OpenWeatherMapService: apiKey: $apiKey');
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenWeatherMapService: API key not configured');
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

      debugPrint('OpenWeatherMapService: Calling $url');
      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('OpenWeatherMapService: API error ${response.statusCode}');
        debugPrint('OpenWeatherMapService: Response: ${response.body}');
        return null;
      }

      final data = json.decode(response.body);
      final hourlyData = data['hourly'] as List<dynamic>?;
      if (hourlyData == null) return null;

      // Parse all hourly data
      final allHours = hourlyData.map(_parseHourlyWeather).toList();

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
      debugPrint('OpenWeatherMapService: Error fetching weather: $e');
      return null;
    }
  }

  HourlyWeather _parseHourlyWeather(dynamic json) {
    final data = json as Map<String, dynamic>;
    final dt = DateTime.fromMillisecondsSinceEpoch(data['dt'] * 1000);
    final temp = (data['temp'] as num).toDouble();
    final weather = (data['weather'] as List).first as Map<String, dynamic>;
    final pop = ((data['pop'] as num?) ?? 0).toDouble();

    return HourlyWeather(
      time: dt,
      temperature: temp,
      condition: weather['main'] as String? ?? 'Unknown',
      iconCode: weather['icon'] as String? ?? '01d',
      precipitationChance: (pop * 100).round(),
    );
  }
}
