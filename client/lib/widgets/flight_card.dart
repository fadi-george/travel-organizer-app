import 'package:flutter/material.dart';
import '../utils/flight_status.dart';
import '../utils/time_format.dart';
import 'swipe_action_card.dart';
import 'timeline_styles.dart';

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

  static const _accentColor = Color(0xFF5B9BD5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final origin = data['departureAirportCode'] as String? ?? 'DEP';
    final destination = data['arrivalAirportCode'] as String? ?? 'ARR';
    final departureDate = data['departureDate'] as String?;
    final arrivalDate = data['arrivalDate'] as String?;
    final departureTime = data['departureTime'] as String?;
    final arrivalTime = data['arrivalTime'] as String?;
    final flightNumber = data['flightNumber'] as String? ?? '';
    final departureGate = data['departureGate'] as String?;
    final status = data['status'] as String?;

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
                  Text(
                    '$origin — $destination',
                    style: TimelineStyles.titleStyle(colorScheme),
                  ),
                  Row(
                    children: [
                      if (flightNumber.isNotEmpty)
                        Text(
                          flightNumber,
                          style: TimelineStyles.subtitleStyle(colorScheme),
                        ),
                      if (departureGate != null && departureGate.isNotEmpty)
                        Text(
                          ' · Gate $departureGate',
                          style: TimelineStyles.subtitleStyle(colorScheme),
                        ),
                      if (status != null && status.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        FlightStatusBadge(status: status, small: true),
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
}
