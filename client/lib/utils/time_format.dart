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

/// Formats a time string, returning null if the input is null/empty.
String? formatTimeOrNull(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return null;
  return formatTime(timeStr);
}

