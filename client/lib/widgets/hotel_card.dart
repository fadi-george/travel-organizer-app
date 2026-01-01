import 'package:flutter/material.dart';
import 'swipe_action_card.dart';

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

  Color get _accentColor => Colors.purple;

  @override
  Widget build(BuildContext context) {
    final hotelName = data['hotelName'] as String? ?? 'Hotel';
    final roomType = data['roomType'] as String?;
    final city = data['city'] as String?;

    return SwipeActionCard(
      onTap: onTap,
      onEdit: onEdit,
      onDelete: onDelete,
      margin: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Hotel icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.hotel, color: _accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            // Hotel info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotelName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(_typeIcon, size: 14, color: _accentColor),
                      const SizedBox(width: 4),
                      Text(
                        _typeLabel,
                        style: TextStyle(
                          fontSize: 13,
                          color: _accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (roomType != null) ...[
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            roomType,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (city != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      city,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
