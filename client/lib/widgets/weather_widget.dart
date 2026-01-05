import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/weather_service.dart';

/// Returns icon and color for a weather condition
({IconData icon, Color color}) getWeatherIconData(WeatherCondition condition) {
  return switch (condition) {
    WeatherCondition.clear => (
      icon: Icons.wb_sunny,
      color: const Color(0xFFFFA726),
    ),
    WeatherCondition.fewClouds => (
      icon: Icons.wb_sunny,
      color: const Color(0xFFFFA726),
    ),
    WeatherCondition.cloudy => (
      icon: Icons.cloud,
      color: const Color(0xFF78909C),
    ),
    WeatherCondition.mist => (
      icon: Icons.foggy,
      color: const Color(0xFFB0BEC5),
    ),
    WeatherCondition.drizzle => (
      icon: Icons.water_drop,
      color: const Color(0xFF42A5F5),
    ),
    WeatherCondition.rain => (
      icon: Icons.water_drop,
      color: const Color(0xFF42A5F5),
    ),
    WeatherCondition.thunderstorm => (
      icon: Icons.thunderstorm,
      color: const Color(0xFF5C6BC0),
    ),
    WeatherCondition.snow => (
      icon: Icons.ac_unit,
      color: const Color(0xFF90CAF9),
    ),
    WeatherCondition.unknown => (
      icon: Icons.cloud,
      color: const Color(0xFF78909C),
    ),
  };
}

/// Displays weather forecast - hourly for near dates, daily for future dates
class WeatherWidget extends StatefulWidget {
  final Trip trip;
  final DateTime selectedDate;

  const WeatherWidget({
    super.key,
    required this.trip,
    required this.selectedDate,
  });

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  List<HourlyWeather>? _weather;
  bool _isLoading = true;
  String? _error;
  DateTime? _lastFetchedDate;
  String? _lastTripId;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  @override
  void didUpdateWidget(WeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch if date or trip changed
    if (!_isSameDay(widget.selectedDate, oldWidget.selectedDate) ||
        widget.trip.id != oldWidget.trip.id) {
      _fetchWeather();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _fetchWeather() async {
    // Avoid redundant fetches
    if (_lastFetchedDate != null &&
        _isSameDay(_lastFetchedDate!, widget.selectedDate) &&
        _lastTripId == widget.trip.id) {
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = WeatherService.instance;
      final location = await service.getLocationForDate(
        widget.trip,
        widget.selectedDate,
      );

      if (location == null) {
        debugPrint('No location found');
        setState(() {
          _weather = null;
          _isLoading = false;
          _error = 'No location found';
          _lastFetchedDate = widget.selectedDate;
          _lastTripId = widget.trip.id;
        });
        return;
      }

      final weather = await service.getHourlyWeather(
        lat: location.lat,
        lng: location.lng,
        date: widget.selectedDate,
      );

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _isLoading = false;
        _error = weather == null ? 'Could not load weather' : null;
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _isLoading = false;
        _error = 'Error loading weather';
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show anything if there's an error or no data
    if (_error != null && !_isLoading) {
      return const SizedBox.shrink();
    }

    // Check for null OR empty list
    final hasWeatherData = _weather != null && _weather!.isNotEmpty;

    // Single item = daily forecast fallback, multiple = hourly forecast
    final isDailyFallback = hasWeatherData && _weather!.length == 1;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? _buildLoadingState()
          : hasWeatherData
          ? isDailyFallback
                ? _buildDailyFallback()
                : _buildHourlyRow()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildDailyFallback() {
    final weather = _weather!.first;
    final temp = weather.temperature.round();
    final precipChance = weather.precipitationChance;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('daily'),
      margin: const EdgeInsets.symmetric(
        horizontal: 0,
        vertical: 0,
      ).copyWith(top: 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Weather icon
          _buildWeatherIcon(weather.weatherCondition, size: 28),
          const SizedBox(width: 12),
          // Temperature and condition
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$temp° · ${weather.condition}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
                if (precipChance > 0)
                  Text(
                    '$precipChance% chance of rain',
                    style: TextStyle(
                      fontSize: 13,
                      color: const Color(0xFF5DA4D9).withValues(alpha: 0.9),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherIcon(WeatherCondition condition, {double size = 28}) {
    final (:icon, :color) = getWeatherIconData(condition);
    return Icon(icon, size: size, color: color);
  }

  Widget _buildLoadingState() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      key: const ValueKey('loading'),
      // margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 21),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading weather...',
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyRow() {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.selectedDate, now);

    return Container(
      key: const ValueKey('weather'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        child: Row(
          children: _weather!.map((hour) {
            final isNow =
                isToday &&
                (now.hour - hour.time.hour).abs() <= 1 &&
                now.hour >= hour.time.hour;
            return _WeatherHourItem(
              weather: hour,
              isNow: isNow && _weather!.indexOf(hour) == _findCurrentIndex(),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _findCurrentIndex() {
    if (_weather == null || _weather!.isEmpty) return -1;
    final now = DateTime.now();
    int closestIndex = 0;
    int minDiff = 999999;
    for (int i = 0; i < _weather!.length; i++) {
      final diff = (now.hour - _weather![i].time.hour).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestIndex = i;
      }
    }
    return closestIndex;
  }
}

class _WeatherHourItem extends StatelessWidget {
  final HourlyWeather weather;
  final bool isNow;

  const _WeatherHourItem({required this.weather, this.isNow = false});

  String _formatTime(DateTime time) {
    final hour = time.hour;
    if (hour == 0) return '12am';
    if (hour == 12) return '12pm';
    if (hour < 12) return '${hour}am';
    return '${hour - 12}pm';
  }

  Widget _buildWeatherIcon() {
    final (:icon, :color) = getWeatherIconData(weather.weatherCondition);
    return Icon(icon, size: 28, color: color);
  }

  @override
  Widget build(BuildContext context) {
    final temp = weather.temperature.round();
    final precipChance = weather.precipitationChance;

    final label = isNow ? 'Now' : _formatTime(weather.time);

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF5D4E37),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$temp°',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E3428),
            ),
          ),
          const SizedBox(height: 6),
          _buildWeatherIcon(),
          if (precipChance > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.water_drop_outlined,
                  size: 12,
                  color: const Color(0xFF5DA4D9).withValues(alpha: 0.8),
                ),
                const SizedBox(width: 2),
                Text(
                  '$precipChance%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF5DA4D9).withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
