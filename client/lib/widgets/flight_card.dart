import 'package:flutter/material.dart';
import 'swipe_action_card.dart';

class FlightCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FlightCard({
    super.key,
    required this.data,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  /// Parse time string (HH:MM or HH:MM:SS) to formatted time
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '--:--';
    final parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final period = hour >= 12 ? 'PM' : 'AM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${weekdays[dt.weekday - 1]}, ${months[dt.month - 1]} ${dt.day}';
  }

  /// Extract airport code from city string (e.g., "Newark (EWR)" -> "EWR")
  String _extractAirportCode(String city) {
    final match = RegExp(r'\(([A-Z]{3})\)').firstMatch(city);
    if (match != null) return match.group(1)!;
    // If no code in parens, take first 3 chars uppercase as fallback
    return city.length >= 3
        ? city.substring(0, 3).toUpperCase()
        : city.toUpperCase();
  }

  /// Extract city name without airport code
  String _extractCityName(String city) {
    // Remove airport code in parentheses if present
    return city.replaceAll(RegExp(r'\s*\([A-Z]{3}\)'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final departureCity = data['departureCity'] as String? ?? 'Departure';
    final arrivalCity = data['arrivalCity'] as String? ?? 'Arrival';
    final origin = _extractAirportCode(departureCity);
    final destination = _extractAirportCode(arrivalCity);
    final originCityName = _extractCityName(departureCity);
    final destinationCityName = _extractCityName(arrivalCity);
    final departureDate = data['departureDate'] as String?;
    final departureTime = data['departureTime'] as String?;
    final arrivalTime = data['arrivalTime'] as String?;
    final flightNumber = data['flightNumber'] as String? ?? '';

    return SwipeActionCard(
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Top row: Cities and flight number
            Row(
              children: [
                Expanded(
                  child: Text(
                    originCityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    flightNumber,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    destinationCityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Middle row: Airport codes and flight path
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Origin airport code
                Text(
                  origin,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                // Flight path with plane
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Line
                      Container(height: 2, color: const Color(0xFFB8D4E8)),
                      // Plane icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFE3F0F9),
                          shape: BoxShape.circle,
                        ),
                        child: const RotatedBox(
                          quarterTurns: 1,
                          child: Icon(
                            Icons.flight,
                            color: Color(0xFF5B9BD5),
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Destination airport code
                Text(
                  destination,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Bottom row: Times and date
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatTime(departureTime),
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    _formatDate(departureDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatTime(arrivalTime),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
