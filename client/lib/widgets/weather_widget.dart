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

/// Height for loading and daily fallback views
const double _kWeatherRowHeight = 64;

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
  int? _lastActivityCount;

  // Scroll tracking for fade indicators
  final ScrollController _scrollController = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _initWeather();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    _updateFadeState();
  }

  void _updateFadeState() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Check if content even needs scrolling
    final canScroll = position.maxScrollExtent > 0;
    final atStart = position.pixels <= 0;
    final atEnd =
        position.pixels >= position.maxScrollExtent - 1; // 1px tolerance

    final newShowLeft = canScroll && !atStart;
    final newShowRight = canScroll && !atEnd;

    if (_showLeftFade != newShowLeft || _showRightFade != newShowRight) {
      setState(() {
        _showLeftFade = newShowLeft;
        _showRightFade = newShowRight;
      });
    }
  }

  /// Try to load from cache synchronously first, then fetch if needed
  void _initWeather() {
    final service = WeatherService.instance;
    final tripId = widget.trip.id;
    final cached = service.getCachedTripWeather(
      tripId: tripId,
      date: widget.selectedDate,
    );
    if (cached != null) {
      // Cache hit - use cached data immediately, no loading state
      _weather = cached;
      _isLoading = false;
      _lastFetchedDate = widget.selectedDate;
      _lastTripId = tripId;
      _lastActivityCount = widget.trip.activities?.length ?? 0;
      return;
    }
    // Cache miss - fetch from API
    _fetchWeather();
  }

  @override
  void didUpdateWidget(WeatherWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refetch if date, trip, or activities changed
    final activityCount = widget.trip.activities?.length ?? 0;
    final dateChanged = !_isSameDay(
      widget.selectedDate,
      oldWidget.selectedDate,
    );
    final tripChanged = widget.trip.id != oldWidget.trip.id;
    final activitiesChanged = activityCount != _lastActivityCount;

    if (dateChanged || tripChanged || activitiesChanged) {
      if (activitiesChanged) {
        // Invalidate cache for current date since activity might affect weather location
        WeatherService.instance.invalidateCacheForDate(
          widget.trip.id,
          widget.selectedDate,
        );
      }
      _fetchWeather();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _fetchWeather() async {
    final activityCount = widget.trip.activities?.length ?? 0;

    // Avoid redundant fetches
    if (_lastFetchedDate != null &&
        _isSameDay(_lastFetchedDate!, widget.selectedDate) &&
        _lastTripId == widget.trip.id &&
        _lastActivityCount == activityCount) {
      return;
    }

    // Only show loading if we don't already have data
    if (_weather == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

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
          _lastActivityCount = activityCount;
        });
        return;
      }

      final weather = await service.getHourlyWeather(
        lat: location.lat,
        lng: location.lng,
        date: widget.selectedDate,
      );

      // Cache at trip level for fast sync lookup on screen transitions
      service.cacheTripWeather(widget.trip.id, widget.selectedDate, weather);

      if (!mounted) return;

      setState(() {
        _weather = weather;
        _isLoading = false;
        _error = weather == null ? 'Could not load weather' : null;
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
        _lastActivityCount = activityCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _weather = null;
        _isLoading = false;
        _error = 'Error loading weather';
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
        _lastActivityCount = widget.trip.activities?.length ?? 0;
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
    final hasHighLow = weather.tempHigh != null && weather.tempLow != null;

    return Container(
      key: const ValueKey('daily'),
      height: _kWeatherRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
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
              mainAxisAlignment: MainAxisAlignment.center,
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
                      color: const Color(0xFF3B8BBD),
                    ),
                  ),
              ],
            ),
          ),
          // High/Low temps on the right with gradient bar
          if (hasHighLow)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${weather.tempLow!.round()}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: const Color(0xFFFF8A65),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${weather.tempHigh!.round()}°',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
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
      height: _kWeatherRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
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

    final items = _weather!.asMap().entries.map((entry) {
      final index = entry.key;
      final hour = entry.value;
      final isNow =
          isToday &&
          (now.hour - hour.time.hour).abs() <= 1 &&
          now.hour >= hour.time.hour;
      return Padding(
        padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
        child: _WeatherHourItem(
          weather: hour,
          isNow: isNow && index == _findCurrentIndex(),
        ),
      );
    }).toList();

    // Check initial scroll state after layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFadeState());

    // Build gradient stops based on scroll position
    final leftStop = _showLeftFade ? 0.16 : 0.0;
    final rightStop = _showRightFade ? 0.84 : 1.0;

    return SizedBox(
      key: const ValueKey('weather'),
      height: _kWeatherRowHeight,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              _showLeftFade ? Colors.transparent : Colors.black,
              Colors.black,
              Colors.black,
              _showRightFade ? Colors.transparent : Colors.black,
            ],
            stops: [0.0, leftStop, rightStop, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: items,
          ),
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

  @override
  Widget build(BuildContext context) {
    final temp = weather.temperature.round();
    final precipChance = weather.precipitationChance;
    final label = isNow ? 'Now' : _formatTime(weather.time);
    final (:icon, :color) = getWeatherIconData(weather.weatherCondition);

    return SizedBox(
      width: 50,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Time label
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isNow ? FontWeight.w700 : FontWeight.w500,
              color: const Color(0xFF5D4E37).withValues(alpha: 0.7),
            ),
          ),
          // Temperature
          Text(
            '$temp°',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3E3428),
            ),
          ),
          // Icon + Precipitation row
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              if (precipChance > 0) ...[
                const SizedBox(width: 2),
                Text(
                  '$precipChance%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF3B8BBD),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
