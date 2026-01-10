import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

/// Initialize timezone database (call once at app startup)
bool _tzInitialized = false;
void initializeTimezones() {
  if (!_tzInitialized) {
    tz_data.initializeTimeZones();
    _tzInitialized = true;
  }
}

/// Formats a time string (HH:MM or HH:MM:SS) to 12-hour format with AM/PM.
/// Returns '--:--' for null/empty input, or the original string if parsing fails.
String formatTime(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return '--:--';
  final parts = timeStr.split(':');
  if (parts.length < 2) return timeStr;
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = int.tryParse(parts[1]) ?? 0;
  final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
  final period = hour >= 12 ? 'PM' : 'AM';
  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

/// Convert UTC ISO timestamp to local time in given timezone, return formatted time string.
/// If timezone is null, uses device's local timezone.
String formatUtcToLocalTime(String? isoTimestamp, {String? timezone}) {
  if (isoTimestamp == null || isoTimestamp.isEmpty) return '--:--';

  try {
    initializeTimezones();
    final utcTime = DateTime.parse(isoTimestamp).toUtc();

    DateTime localTime;
    if (timezone != null) {
      final location = tz.getLocation(timezone);
      localTime = tz.TZDateTime.from(utcTime, location);
    } else {
      localTime = utcTime.toLocal();
    }

    final hour = localTime.hour;
    final minute = localTime.minute;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  } catch (e) {
    return '--:--';
  }
}

/// Formats a time string, returning null if the input is null/empty.
String? formatTimeOrNull(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return null;
  return formatTime(timeStr);
}

/// Parse time string (e.g., "9:15 AM", "14:30") to hour and minute.
/// Returns null if parsing fails.
(int hour, int minute)? parseTime(String? time) {
  if (time == null || time.isEmpty) return null;

  try {
    final upperTime = time.toUpperCase().trim();
    final isPM = upperTime.contains('PM');
    final isAM = upperTime.contains('AM');

    final cleanTime = upperTime
        .replaceAll('AM', '')
        .replaceAll('PM', '')
        .trim();

    final parts = cleanTime.split(':');
    if (parts.length < 2) return null;

    var hours = int.tryParse(parts[0]) ?? 0;
    final minutes =
        int.tryParse(parts[1].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

    if (isPM && hours != 12) hours += 12;
    if (isAM && hours == 12) hours = 0;

    return (hours, minutes);
  } catch (_) {
    return null;
  }
}

/// Parse time string to minutes since midnight.
/// Returns null if parsing fails.
int? parseTimeToMinutes(String? time) {
  final parsed = parseTime(time);
  if (parsed == null) return null;
  return parsed.$1 * 60 + parsed.$2;
}
