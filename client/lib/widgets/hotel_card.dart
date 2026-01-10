import 'package:flutter/material.dart';
import 'swipe_action_card.dart';
import 'timeline_styles.dart';

enum HotelCardType { checkIn, checkOut }

class HotelCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final HotelCardType type;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const HotelCard({
    super.key,
    required this.data,
    this.type = HotelCardType.checkIn,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  String get _typeLabel =>
      type == HotelCardType.checkIn ? 'Check-in' : 'Check-out';

  IconData get _typeIcon =>
      type == HotelCardType.checkIn ? Icons.login : Icons.logout;

  static const _accentColor = Color(0xFF9C27B0);

  /// Extract a short location (city, country) from a full address
  static String? _getShortLocation(String? address) {
    if (address == null || address.isEmpty) return null;
    final parts = address.split(',').map((p) => p.trim()).toList();
    if (parts.length >= 2) {
      // Return last 2 parts (typically city, country)
      return parts.sublist(parts.length - 2).join(', ');
    }
    return parts.last;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hotelName = data['hotelName'] as String? ?? 'Hotel';
    final roomType = data['roomType'] as String?;
    final address = data['address'] as String?;
    final location = _getShortLocation(address);

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
            // Hotel icon
            TimelineStyles.iconContainer(
              accentColor: _accentColor,
              child: Icon(
                Icons.hotel,
                color: _accentColor,
                size: TimelineStyles.iconSize,
              ),
            ),
            const SizedBox(width: TimelineStyles.contentSpacing),
            // Hotel name and room type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotelName,
                    style: TimelineStyles.titleStyle(colorScheme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (roomType != null)
                    Text(
                      roomType,
                      style: TimelineStyles.subtitleStyle(colorScheme),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Check-in/out type and city
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon, size: 14, color: _accentColor),
                    const SizedBox(width: 4),
                    Text(
                      _typeLabel,
                      style: TextStyle(
                        fontSize: TimelineStyles.subtitleFontSize,
                        color: _accentColor,
                        fontWeight: TimelineStyles.subtitleFontWeight,
                      ),
                    ),
                  ],
                ),
                if (location != null)
                  Text(
                    location,
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
