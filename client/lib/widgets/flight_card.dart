import 'package:flutter/material.dart';
import '../services/airports_service.dart';
import '../utils/time_format.dart';
import 'swipe_action_card.dart';
import 'timeline_styles.dart';

enum FlightCardViewType { card, timeline }

class FlightCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final FlightCardViewType viewType;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const FlightCard({
    super.key,
    required this.data,
    this.viewType = FlightCardViewType.timeline,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

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

  /// Format date as short form (e.g., "Jan 13")
  String _formatShortDate(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
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
    return '${months[dt.month - 1]} ${dt.day}';
  }

  /// Get status badge color based on flight status
  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    final s = status.toLowerCase();
    if (s.contains('landed') || s.contains('arrived')) {
      return Colors.green;
    }
    if (s.contains('en route') || s.contains('active') || s.contains('airborne')) {
      return Colors.blue;
    }
    if (s.contains('cancelled') || s.contains('diverted')) {
      return Colors.red;
    }
    if (s.contains('delayed')) {
      return Colors.orange;
    }
    // Scheduled or unknown
    return Colors.grey;
  }

  /// Format status text for display
  String _formatStatus(String? status) {
    if (status == null) return '';

    // AeroAPI returns statuses like "Scheduled", "En Route / On Time", "Landed", etc.
    // Simplify for display
    final s = status.toLowerCase();
    if (s.contains('landed')) return 'Landed';
    if (s.contains('en route')) return 'En Route';
    if (s.contains('cancelled')) return 'Cancelled';
    if (s.contains('delayed')) return 'Delayed';
    if (s.contains('scheduled')) return 'Scheduled';
    if (s.contains('active') || s.contains('airborne')) return 'En Route';

    return status;
  }

  Widget _buildStatusBadge(String? status, ColorScheme colorScheme) {
    if (status == null || status.isEmpty) return const SizedBox.shrink();

    final color = _getStatusColor(status);
    final displayStatus = _formatStatus(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  static const _accentColor = Color(0xFF5B9BD5);

  Widget _buildTimelineView(
    BuildContext context, {
    required ColorScheme colorScheme,
    required bool isDark,
    required String origin,
    required String destination,
    required String flightNumber,
    required String? departureDate,
    required String? arrivalDate,
    required String? departureTime,
    required String? arrivalTime,
    required String? departureGate,
    required String? status,
  }) {
    return SwipeActionCard(
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      margin: TimelineStyles.itemMargin,
      child: Container(
        padding: TimelineStyles.containerPadding,
        decoration: TimelineStyles.containerDecoration(
          colorScheme: colorScheme,
          isDark: isDark,
        ),
        child: Row(
          children: [
            // Flight icon
            TimelineStyles.iconContainer(
              accentColor: _accentColor,
              child: const RotatedBox(
                quarterTurns: 1,
                child: Icon(
                  Icons.flight,
                  color: _accentColor,
                  size: TimelineStyles.iconSize,
                ),
              ),
            ),
            const SizedBox(width: TimelineStyles.contentSpacing),
            // Route and flight number
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$origin — $destination',
                        style: TimelineStyles.titleStyle(colorScheme),
                      ),
                      if (status != null && status.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge(status, colorScheme),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      if (flightNumber.isNotEmpty)
                        Text(
                          flightNumber,
                          style: TimelineStyles.subtitleStyle(colorScheme),
                        ),
                      if (departureGate != null && departureGate.isNotEmpty) ...[
                        Text(
                          ' · Gate $departureGate',
                          style: TimelineStyles.subtitleStyle(colorScheme),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Date and times
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (departureDate != null)
                  Text(
                    arrivalDate != null &&
                            _formatShortDate(departureDate) !=
                                _formatShortDate(arrivalDate)
                        ? '${_formatShortDate(departureDate)} – ${_formatShortDate(arrivalDate)}'
                        : _formatShortDate(departureDate),
                    style: TimelineStyles.subtitleStyle(colorScheme),
                  ),
                Text(
                  '${formatTime(departureTime)} – ${formatTime(arrivalTime)}',
                  style: TimelineStyles.subtitleStyle(colorScheme),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final origin = data['departureAirportCode'] as String? ?? 'DEP';
    final destination = data['arrivalAirportCode'] as String? ?? 'ARR';
    final originCityName =
        AirportsService.instance.getByIata(origin)?.city ?? origin;
    final destinationCityName =
        AirportsService.instance.getByIata(destination)?.city ?? destination;
    final departureDate = data['departureDate'] as String?;
    final departureTime = data['departureTime'] as String?;
    final arrivalTime = data['arrivalTime'] as String?;
    final flightNumber = data['flightNumber'] as String? ?? '';
    final departureGate = data['departureGate'] as String?;
    final status = data['status'] as String?;

    if (viewType == FlightCardViewType.timeline) {
      final arrivalDate = data['arrivalDate'] as String?;
      return _buildTimelineView(
        context,
        colorScheme: colorScheme,
        isDark: isDark,
        origin: origin,
        destination: destination,
        flightNumber: flightNumber,
        departureDate: departureDate,
        arrivalDate: arrivalDate,
        departureTime: departureTime,
        arrivalTime: arrivalTime,
        departureGate: departureGate,
        status: status,
      );
    }

    return SwipeActionCard(
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: isDark
              ? Border.all(color: colorScheme.outline.withValues(alpha: 0.15))
              : null,
          boxShadow: [
            if (isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 16,
                offset: const Offset(0, 4),
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          children: [
            // Top row: Cities, flight number, and status badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    originCityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        flightNumber,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (status != null && status.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildStatusBadge(status, colorScheme),
                      ],
                    ],
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
                      color: colorScheme.onSurface.withValues(alpha: 0.8),
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
                // Origin airport code with gate
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      origin,
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    if (departureGate != null && departureGate.isNotEmpty)
                      Text(
                        'Gate $departureGate',
                        style: TextStyle(
                          fontSize: 12,
                          color: _accentColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                // Flight path with plane
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Line
                      Container(
                        height: 2,
                        color: isDark
                            ? const Color(0xFF4A6572)
                            : const Color(0xFFB8D4E8),
                      ),
                      // Plane icon
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2D3E50)
                              : const Color(0xFFE3F0F9),
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
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
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
                    formatTime(departureTime),
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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
                      color: colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    formatTime(arrivalTime),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 15,
                      color: colorScheme.onSurface.withValues(alpha: 0.6),
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
