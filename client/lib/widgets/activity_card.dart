import 'dart:developer';

import 'package:flutter/material.dart';
import '../utils/time_format.dart';
import 'swipe_action_card.dart';
import 'timeline_styles.dart';

enum ActivityCardViewType { card, timeline }

class ActivityCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final ActivityCardViewType viewType;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ActivityCard({
    super.key,
    required this.data,
    this.viewType = ActivityCardViewType.timeline,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  static const _accentColor = Color(0xFFFF7043);

  static const Map<String, IconData> _typeIcons = {
    'Sightseeing': Icons.photo_camera_outlined,
    'Food & Dining': Icons.restaurant_outlined,
    'Entertainment': Icons.theater_comedy_outlined,
    'Shopping': Icons.shopping_bag_outlined,
    'Tour': Icons.tour_outlined,
    'Transportation': Icons.directions_car_outlined,
    'Relaxation': Icons.spa_outlined,
    'Adventure': Icons.paragliding_outlined,
    'Cultural': Icons.museum_outlined,
    'Nature': Icons.park_outlined,
    'Other': Icons.more_horiz_outlined,
  };

  IconData get _icon {
    final type = data['type'] as String?;
    return _typeIcons[type] ?? Icons.local_activity_outlined;
  }

  String? get _formattedTime => formatTimeOrNull(data['time'] as String?);

  Widget _buildTimelineView(
    BuildContext context, {
    required ColorScheme colorScheme,
    required bool isDark,
    required String title,
    required String? location,
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
            // Activity icon
            TimelineStyles.iconContainer(
              accentColor: _accentColor,
              child: Icon(
                _icon,
                color: _accentColor,
                size: TimelineStyles.iconSize,
              ),
            ),
            const SizedBox(width: TimelineStyles.contentSpacing),
            // Activity title and location
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TimelineStyles.titleStyle(colorScheme),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location != null)
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TimelineStyles.subtitleStyle(colorScheme),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Time
            if (_formattedTime != null)
              Text(
                _formattedTime!,
                style: TimelineStyles.subtitleStyle(colorScheme),
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

    final title = data['title'] as String? ?? 'Activity';
    final location = data['location'] as String?;
    final type = data['type'] as String?;

    if (viewType == ActivityCardViewType.timeline) {
      return _buildTimelineView(
        context,
        colorScheme: colorScheme,
        isDark: isDark,
        title: title,
        location: location,
      );
    }

    // Card view
    return SwipeActionCard(
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? colorScheme.outline.withValues(alpha: 0.2)
                : Colors.grey.shade200,
          ),
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
        child: Row(
          children: [
            // Activity icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon, color: _accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Activity info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_formattedTime != null) ...[
                        Icon(Icons.access_time, size: 14, color: _accentColor),
                        const SizedBox(width: 4),
                        Text(
                          _formattedTime!,
                          style: TextStyle(
                            fontSize: TimelineStyles.subtitleFontSize,
                            color: _accentColor,
                            fontWeight: TimelineStyles.subtitleFontWeight,
                          ),
                        ),
                      ],
                      if (_formattedTime != null && type != null)
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 13,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      if (type != null)
                        Flexible(
                          child: Text(
                            type,
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  if (location != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
