import 'package:flutter/material.dart';
import '../models/trip.dart';
import '../services/weather_service.dart';

/// Displays hourly weather forecast in a horizontal scrollable row
class HourlyWeatherWidget extends StatefulWidget {
  final Trip trip;
  final DateTime selectedDate;

  const HourlyWeatherWidget({
    super.key,
    required this.trip,
    required this.selectedDate,
  });

  @override
  State<HourlyWeatherWidget> createState() => _HourlyWeatherWidgetState();
}

class _HourlyWeatherWidgetState extends State<HourlyWeatherWidget> {
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
  void didUpdateWidget(HourlyWeatherWidget oldWidget) {
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

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isLoading
          ? _buildLoadingState()
          : _weather != null
          ? _buildWeatherRow()
          : const SizedBox.shrink(),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      key: const ValueKey('loading'),
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF8B7355),
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherRow() {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.selectedDate, now);

    return Container(
      key: const ValueKey('weather'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5EFE6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
    final iconCode = weather.iconCode;
    // Map OpenWeatherMap icon codes to appropriate icons and colors
    IconData icon;
    Color color;

    if (iconCode.startsWith('01')) {
      // Clear sky
      icon = Icons.wb_sunny;
      color = const Color(0xFFFFA726);
    } else if (iconCode.startsWith('02')) {
      // Few clouds
      icon = Icons.wb_sunny;
      color = const Color(0xFFFFA726);
    } else if (iconCode.startsWith('03') || iconCode.startsWith('04')) {
      // Scattered/broken clouds
      icon = Icons.cloud;
      color = const Color(0xFF78909C);
    } else if (iconCode.startsWith('09') || iconCode.startsWith('10')) {
      // Rain
      icon = Icons.water_drop;
      color = const Color(0xFF42A5F5);
    } else if (iconCode.startsWith('11')) {
      // Thunderstorm
      icon = Icons.thunderstorm;
      color = const Color(0xFF5C6BC0);
    } else if (iconCode.startsWith('13')) {
      // Snow
      icon = Icons.ac_unit;
      color = const Color(0xFF90CAF9);
    } else if (iconCode.startsWith('50')) {
      // Mist/fog
      icon = Icons.foggy;
      color = const Color(0xFFB0BEC5);
    } else {
      icon = Icons.cloud;
      color = const Color(0xFF78909C);
    }

    return Icon(icon, size: 28, color: color);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('WeatherService');
    final temp = weather.temperature.round();
    final precipChance = weather.precipitationChance;

    return Container(
      width: 60,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Time label
          Text(
            isNow ? 'Now' : _formatTime(weather.time),
            style: TextStyle(
              fontSize: 13,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF5D4E37),
            ),
          ),
          const SizedBox(height: 8),
          // Temperature
          Text(
            '$temp°',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E3428),
            ),
          ),
          const SizedBox(height: 6),
          // Weather icon
          _buildWeatherIcon(),
          // Precipitation chance (only show if > 0)
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
