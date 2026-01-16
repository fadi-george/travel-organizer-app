import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../models/trip.dart';
import '../services/weather_service.dart';
import 'fading_scroll_view.dart';

/// Returns HugeIcon widget for a weather condition
Widget getWeatherIcon(WeatherCondition condition, {double size = 24}) {
  final dayColor = Colors.orange.shade800;
  final nightColor = Colors.blue.shade800;
  final neutralColor = Colors.grey.shade800;
  return switch (condition) {
    // Day conditions
    WeatherCondition.clear => HugeIcon(
      icon: HugeIconsStrokeRounded.sun01,
      color: dayColor,
      size: size,
    ),
    WeatherCondition.fewClouds => HugeIcon(
      icon: HugeIconsStrokeRounded.sunCloud01,
      color: dayColor,
      size: size,
    ),
    WeatherCondition.cloudy => HugeIcon(
      icon: HugeIconsStrokeRounded.cloud,
      color: neutralColor,
      size: size,
    ),
    WeatherCondition.mist => HugeIcon(
      icon: HugeIconsStrokeRounded.slowWinds,
      color: neutralColor,
      size: size,
    ),
    WeatherCondition.drizzle => HugeIcon(
      icon: HugeIconsStrokeRounded.sunCloudLittleRain01,
      color: dayColor,
      size: size,
    ),
    WeatherCondition.rain => HugeIcon(
      icon: HugeIconsStrokeRounded.cloudSlowWind,
      color: dayColor,
      size: size,
    ),
    WeatherCondition.thunderstorm => HugeIcon(
      icon: HugeIconsStrokeRounded.sunCloudAngledZap01,
      color: neutralColor,
      size: size,
    ),
    WeatherCondition.snow => HugeIcon(
      icon: HugeIconsStrokeRounded.cloudSnow,
      color: neutralColor,
      size: size,
    ),
    WeatherCondition.unknown => HugeIcon(
      icon: HugeIconsStrokeRounded.cloud,
      color: neutralColor,
      size: size,
    ),
    // Night conditions
    WeatherCondition.clearNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moon02,
      color: nightColor,
      size: size,
    ),
    WeatherCondition.fewCloudsNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moonCloud,
      color: nightColor,
      size: size,
    ),
    WeatherCondition.drizzleNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moonCloudLittleRain,
      color: nightColor,
      size: size,
    ),
    WeatherCondition.rainNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moonCloudMidRain,
      color: nightColor,
      size: size,
    ),
    WeatherCondition.thunderstormNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moonCloudAngledZap,
      color: nightColor,
      size: size,
    ),
    WeatherCondition.snowNight => HugeIcon(
      icon: HugeIconsStrokeRounded.moonCloudSnow,
      color: nightColor,
      size: size,
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
  bool _isFetching = false; // Prevent concurrent fetches
  DateTime? _lastFetchedDate;
  String? _lastTripId;
  int? _lastActivityCount;

  @override
  void initState() {
    super.initState();
    _initWeather();
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
    // Prevent concurrent fetches
    if (_isFetching) return;

    final activityCount = widget.trip.activities?.length ?? 0;

    // Avoid redundant fetches
    if (_lastFetchedDate != null &&
        _isSameDay(_lastFetchedDate!, widget.selectedDate) &&
        _lastTripId == widget.trip.id &&
        _lastActivityCount == activityCount) {
      return;
    }

    _isFetching = true;

    // Check if we have cached data for this specific date
    final service = WeatherService.instance;
    final cached = service.getCachedTripWeather(
      tripId: widget.trip.id,
      date: widget.selectedDate,
    );
    if (cached != null) {
      // Cache hit - use cached data immediately
      setState(() {
        _weather = cached;
        _isLoading = false;
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
        _lastActivityCount = activityCount;
      });
      return;
    }

    // No cached data for this date - show loading and clear old data
    setState(() {
      _weather = null;
      _isLoading = true;
    });

    try {
      final location = await service.getLocationForDate(
        widget.trip,
        widget.selectedDate,
      );

      if (location == null) {
        setState(() {
          _weather = null;
          _isLoading = false;
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

      if (!mounted) {
        _isFetching = false;
        return;
      }

      setState(() {
        _weather = weather;
        _isLoading = false;
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
        _lastActivityCount = activityCount;
      });
    } catch (_) {
      if (!mounted) {
        _isFetching = false;
        return;
      }
      setState(() {
        _weather = null;
        _isLoading = false;
        _lastFetchedDate = widget.selectedDate;
        _lastTripId = widget.trip.id;
        _lastActivityCount = widget.trip.activities?.length ?? 0;
      });
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check for null OR empty list
    final hasWeatherData = _weather != null && _weather!.isNotEmpty;

    // Single item = daily forecast fallback, multiple = hourly forecast
    final isDailyFallback = hasWeatherData && _weather!.length == 1;

    // Calculate days ahead for appropriate message
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
      widget.selectedDate.day,
    );
    final daysAhead = selectedDay.difference(today).inDays;

    // Determine which message to show when no data
    final showNoDataMessage = !hasWeatherData && !_isLoading;
    final isTooFarAhead = daysAhead > 8;
    final isToday = _isSameDay(widget.selectedDate, DateTime.now());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: hasWeatherData
          ? isDailyFallback
                ? _buildDailyFallback()
                : _buildHourlyRow()
          : showNoDataMessage
          ? isTooFarAhead
                ? _buildFarFutureMessage()
                : _buildUnavailableMessage()
          : isToday
          ? _buildHourlyRow(skeleton: true)
          : _buildDailyFallback(skeleton: true),
    );
  }

  Widget _buildFarFutureMessage() {
    return _buildMessageRow(
      key: 'far-future',
      icon: Icons.auto_awesome,
      message: "Too far ahead to predict 🔮",
    );
  }

  Widget _buildUnavailableMessage() {
    return _buildMessageRow(
      key: 'unavailable',
      icon: Icons.cloud_off,
      message: "Weather unavailable",
    );
  }

  Widget _buildMessageRow({
    required String key,
    required IconData icon,
    required String message,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = colorScheme.onSurface.withValues(alpha: 0.65);

    return Container(
      key: ValueKey(key),
      height: _kWeatherRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFallback({bool skeleton = false}) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = Container(
      key: const ValueKey('daily'),
      height: _kWeatherRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildActualDailyContent(skeleton: skeleton),
    );

    return Skeletonizer(enabled: skeleton, child: content);
  }

  Widget _buildActualDailyContent({bool skeleton = false}) {
    if (_weather == null || (_weather!.isEmpty && !skeleton)) {
      return const SizedBox.shrink();
    }

    final weather = _weather?.first;
    final temp = weather?.temperature.round() ?? 0;
    final precipChance = weather?.precipitationChance ?? 0;
    final colorScheme = Theme.of(context).colorScheme;
    final hasHighLow = weather?.tempHigh != null && weather?.tempLow != null;

    return Row(
      children: [
        // Weather icon
        _DailyWeatherIcon(
          condition: weather?.weatherCondition ?? WeatherCondition.cloudy,
          skeleton: skeleton,
        ),
        const SizedBox(width: 12),
        // Temperature and condition
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$temp° · ${weather?.condition ?? "Unknown"}',
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
                '${weather?.tempLow?.round() ?? "--"}°',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8A65),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${weather?.tempHigh?.round() ?? "--"}°',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildHourlyRow({bool skeleton = false}) {
    final now = DateTime.now();
    final isToday = _isSameDay(widget.selectedDate, now);

    final items = (_weather == null || _weather!.isEmpty)
        ? <Widget>[]
        : _weather!.asMap().entries.map((entry) {
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

    final skeletonItems = List.generate(6, (index) {
      return Padding(
        padding: EdgeInsets.only(left: index == 0 ? 0 : 16),
        child: _WeatherHourItem(skeleton: true),
      );
    });

    return Skeletonizer(
      enabled: skeleton,
      child: SizedBox(
        key: const ValueKey('weather'),
        height: _kWeatherRowHeight,
        child: FadingScrollView(
          fadeWidth: 0.16,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: skeleton ? skeletonItems : items,
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
  final HourlyWeather? weather;
  final bool isNow;
  final bool skeleton;

  const _WeatherHourItem({
    this.weather,
    this.isNow = false,
    this.skeleton = false,
  });

  String _formatTime(DateTime time) {
    final hour = time.hour;
    if (hour == 0) return '12am';
    if (hour == 12) return '12pm';
    if (hour < 12) return '${hour}am';
    return '${hour - 12}pm';
  }

  @override
  Widget build(BuildContext context) {
    if (weather == null && !skeleton) {
      return const SizedBox.shrink();
    }

    final temp = weather?.temperature.round() ?? 0;
    final precipChance = weather?.precipitationChance ?? 0;
    final weatherCondition =
        weather?.weatherCondition ?? WeatherCondition.cloudy;
    final label = skeleton
        ? 'Now'
        : (isNow ? 'Now' : _formatTime(weather!.time));
    final colorScheme = Theme.of(context).colorScheme;

    return Skeletonizer(
      enabled: skeleton,
      child: SizedBox(
        width: 50,
        child: SingleChildScrollView(
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
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              // const SizedBox(height: 2),
              // Temperature
              Text(
                '$temp°',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              // const SizedBox(height: 2),
              // Icon + Precipitation row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  skeleton
                      ? Icon(Icons.cloud, size: 16)
                      : getWeatherIcon(weatherCondition, size: 20),
                  if (precipChance > 0) ...[
                    const SizedBox(width: 2),
                    Text(
                      '$precipChance%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF42A5F5),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _DailyWeatherIcon extends StatelessWidget {
  final WeatherCondition condition;
  final bool skeleton;

  const _DailyWeatherIcon({required this.condition, this.skeleton = false});

  @override
  Widget build(BuildContext context) {
    if (skeleton) {
      return Icon(Icons.cloud, size: 28);
    }
    return getWeatherIcon(condition, size: 28);
  }
}
