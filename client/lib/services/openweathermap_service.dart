import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'weather_service.dart' show WeatherCondition, WeatherConditionExtension;

/// Represents hourly weather data
class HourlyWeather {
  final DateTime time;
  final double temperature; // Fahrenheit
  final String condition;
  final WeatherCondition weatherCondition;
  final int precipitationChance; // 0-100
  final double? tempHigh; // For daily fallback display
  final double? tempLow; // For daily fallback display

  const HourlyWeather({
    required this.time,
    required this.temperature,
    required this.condition,
    required this.weatherCondition,
    required this.precipitationChance,
    this.tempHigh,
    this.tempLow,
  });
}

/// Represents daily weather data
class DailyWeather {
  final DateTime date;
  final double tempHigh; // Fahrenheit
  final double tempLow; // Fahrenheit
  final String condition;
  final WeatherCondition weatherCondition;
  final int precipitationChance; // 0-100

  const DailyWeather({
    required this.date,
    required this.tempHigh,
    required this.tempLow,
    required this.condition,
    required this.weatherCondition,
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
  /// Uses Time Machine API for past hours (today) and One Call for future hours
  Future<List<HourlyWeather>?> getHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final now = DateTime.now();
    final requestedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime(now.year, now.month, now.day);
    final daysAhead = requestedDate.difference(today).inDays;

    // Hourly forecast only available for ~48 hours, fall back to daily for 3-8 days
    if (daysAhead > 2) {
      if (daysAhead <= 8) {
        debugPrint(
          'OpenWeatherMapService: Falling back to daily forecast ($daysAhead days ahead)',
        );
        return _getDailyAsFallback(lat: lat, lng: lng, date: date);
      }
      debugPrint(
        'OpenWeatherMapService: Date $date is outside forecast range (max 8 days)',
      );
      return null;
    }

    // Past dates (before today) - use Time Machine API for the full day
    if (daysAhead < 0) {
      return _getHistoricalHourlyWeather(lat: lat, lng: lng, date: date);
    }

    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenWeatherMapService: API key not configured');
      return null;
    }

    // Target hours: 8am through midnight
    final targetHours = [8, 10, 12, 14, 16, 18, 20, 22, 0];
    final targetDate = DateTime(date.year, date.month, date.day);
    final nextDay = targetDate.add(const Duration(days: 1));

    // For today, split into past hours (Time Machine) and future hours (One Call)
    final isToday = daysAhead == 0;
    final pastHours = <HourlyWeather>[];
    final futureHours = <HourlyWeather>[];

    if (isToday) {
      // Fetch past hours using Time Machine API
      final pastTargetHours = targetHours.where((h) => h != 0 && h < now.hour).toList();
      if (pastTargetHours.isNotEmpty) {
        final historical = await _fetchPastHoursForToday(
          lat: lat,
          lng: lng,
          date: targetDate,
          targetHours: pastTargetHours,
        );
        pastHours.addAll(historical);
      }
    }

    try {
      // Use One Call API 3.0 for current and future hourly forecast
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall'
        '?lat=$lat&lon=$lng'
        '&exclude=minutely,daily,alerts'
        '&units=imperial'
        '&appid=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint('OpenWeatherMapService: API error ${response.statusCode}');
        debugPrint('OpenWeatherMapService: Response: ${response.body}');
        // If One Call fails but we have past hours, return those
        if (pastHours.isNotEmpty) return pastHours;
        return null;
      }

      final data = json.decode(response.body);
      final hourlyData = data['hourly'] as List<dynamic>?;
      if (hourlyData == null) {
        if (pastHours.isNotEmpty) return pastHours;
        return null;
      }

      // Parse all hourly data from forecast
      final allForecastHours = hourlyData.map(_parseHourlyWeather).toList();

      // Filter to target hours that are current or future
      final futureTargetHours = isToday
          ? targetHours.where((h) => h == 0 || h >= now.hour).toList()
          : targetHours;

      for (final hour in futureTargetHours) {
        final targetTime = hour == 0
            ? DateTime(nextDay.year, nextDay.month, nextDay.day, 0)
            : DateTime(targetDate.year, targetDate.month, targetDate.day, hour);

        // Find closest hour in forecast data
        HourlyWeather? closest;
        int minDiff = 999999;
        for (final weather in allForecastHours) {
          final diff = (weather.time.difference(targetTime).inMinutes).abs();
          if (diff < minDiff) {
            minDiff = diff;
            closest = weather;
          }
        }
        if (closest != null && minDiff <= 90) {
          futureHours.add(closest);
        }
      }

      // Combine past and future hours, sorted by time
      final combined = [...pastHours, ...futureHours];
      combined.sort((a, b) => a.time.compareTo(b.time));
      return combined;
    } catch (e) {
      debugPrint('OpenWeatherMapService: Error fetching weather: $e');
      if (pastHours.isNotEmpty) return pastHours;
      return null;
    }
  }

  /// Fetch past hours for today using Time Machine API
  Future<List<HourlyWeather>> _fetchPastHoursForToday({
    required double lat,
    required double lng,
    required DateTime date,
    required List<int> targetHours,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) return [];

    final results = <HourlyWeather>[];

    // Fetch each past hour individually (Time Machine returns data for specific timestamp)
    for (final hour in targetHours) {
      final targetTime = DateTime(date.year, date.month, date.day, hour);
      final timestamp = targetTime.millisecondsSinceEpoch ~/ 1000;

      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/3.0/onecall/timemachine'
          '?lat=$lat&lon=$lng'
          '&dt=$timestamp'
          '&units=imperial'
          '&appid=$apiKey',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final hourlyData = data['data'] as List<dynamic>?;
          if (hourlyData != null && hourlyData.isNotEmpty) {
            // Time Machine returns hourly data around the requested time
            // Find the closest match to our target hour
            HourlyWeather? closest;
            int minDiff = 999999;
            for (final hourData in hourlyData) {
              final weather = _parseHourlyWeather(hourData);
              final diff = (weather.time.difference(targetTime).inMinutes).abs();
              if (diff < minDiff) {
                minDiff = diff;
                closest = weather;
              }
            }
            if (closest != null && minDiff <= 90) {
              results.add(closest);
            }
          }
        }
      } catch (e) {
        debugPrint('OpenWeatherMapService: Time Machine error for hour $hour: $e');
      }
    }

    return results;
  }

  /// Fetch historical hourly weather for a past date using Time Machine API
  Future<List<HourlyWeather>?> _getHistoricalHourlyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenWeatherMapService: API key not configured');
      return null;
    }

    final targetHours = [8, 10, 12, 14, 16, 18, 20, 22];
    final results = <HourlyWeather>[];

    for (final hour in targetHours) {
      final targetTime = DateTime(date.year, date.month, date.day, hour);
      final timestamp = targetTime.millisecondsSinceEpoch ~/ 1000;

      try {
        final url = Uri.parse(
          'https://api.openweathermap.org/data/3.0/onecall/timemachine'
          '?lat=$lat&lon=$lng'
          '&dt=$timestamp'
          '&units=imperial'
          '&appid=$apiKey',
        );

        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final hourlyData = data['data'] as List<dynamic>?;
          if (hourlyData != null && hourlyData.isNotEmpty) {
            HourlyWeather? closest;
            int minDiff = 999999;
            for (final hourData in hourlyData) {
              final weather = _parseHourlyWeather(hourData);
              final diff = (weather.time.difference(targetTime).inMinutes).abs();
              if (diff < minDiff) {
                minDiff = diff;
                closest = weather;
              }
            }
            if (closest != null && minDiff <= 90) {
              results.add(closest);
            }
          }
        }
      } catch (e) {
        debugPrint('OpenWeatherMapService: Time Machine error for hour $hour: $e');
      }
    }

    return results.isNotEmpty ? results : null;
  }

  HourlyWeather _parseHourlyWeather(dynamic json) {
    final data = json as Map<String, dynamic>;
    final dt = DateTime.fromMillisecondsSinceEpoch(data['dt'] * 1000);
    final temp = (data['temp'] as num).toDouble();
    final weather = (data['weather'] as List).first as Map<String, dynamic>;
    final pop = ((data['pop'] as num?) ?? 0).toDouble();
    final iconCode = weather['icon'] as String? ?? '01d';

    return HourlyWeather(
      time: dt,
      temperature: temp,
      condition: weather['main'] as String? ?? 'Unknown',
      weatherCondition: WeatherConditionExtension.fromOpenWeatherCode(iconCode),
      precipitationChance: (pop * 100).round(),
    );
  }

  /// Fallback: fetch daily forecast and convert to hourly-like format
  /// Used when date is beyond hourly forecast limit (3-8 days ahead)
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

  /// Fetch daily weather for a specific date
  /// Note: One Call API 3.0 provides up to 8 days of daily forecast
  Future<DailyWeather?> getDailyWeather({
    required double lat,
    required double lng,
    required DateTime date,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      debugPrint('OpenWeatherMapService: API key not configured');
      return null;
    }

    try {
      // Use One Call API 3.0 for daily forecast
      final url = Uri.parse(
        'https://api.openweathermap.org/data/3.0/onecall'
        '?lat=$lat&lon=$lng'
        '&exclude=minutely,hourly,alerts,current'
        '&units=imperial'
        '&appid=$apiKey',
      );

      final response = await http.get(url);
      if (response.statusCode != 200) {
        debugPrint(
          'OpenWeatherMapService: Daily API error ${response.statusCode}',
        );
        return null;
      }

      final data = json.decode(response.body);
      final dailyData = data['daily'] as List<dynamic>?;
      if (dailyData == null || dailyData.isEmpty) return null;

      // Find the matching day in the forecast
      final targetDate = DateTime(date.year, date.month, date.day);
      for (final day in dailyData) {
        final dayData = day as Map<String, dynamic>;
        final dt = DateTime.fromMillisecondsSinceEpoch(dayData['dt'] * 1000);
        final dayDate = DateTime(dt.year, dt.month, dt.day);

        if (dayDate == targetDate) {
          final temp = dayData['temp'] as Map<String, dynamic>;
          final weather =
              (dayData['weather'] as List).first as Map<String, dynamic>;
          final pop = ((dayData['pop'] as num?) ?? 0).toDouble();
          final iconCode = weather['icon'] as String? ?? '01d';

          return DailyWeather(
            date: targetDate,
            tempHigh: (temp['max'] as num).toDouble(),
            tempLow: (temp['min'] as num).toDouble(),
            condition: weather['main'] as String? ?? 'Unknown',
            weatherCondition: WeatherConditionExtension.fromOpenWeatherCode(
              iconCode,
            ),
            precipitationChance: (pop * 100).round(),
          );
        }
      }

      debugPrint('OpenWeatherMapService: Date not found in forecast range');
      return null;
    } catch (e) {
      debugPrint('OpenWeatherMapService: Error fetching daily weather: $e');
      return null;
    }
  }
}
