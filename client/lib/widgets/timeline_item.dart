import 'package:flutter/material.dart';
import 'flight_card.dart';

class TimelineItem extends StatelessWidget {
  final String type;
  final Map<String, dynamic> data;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const TimelineItem({
    super.key,
    required this.type,
    required this.data,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
  });

  IconData get _icon {
    switch (type) {
      case 'flight':
        return Icons.flight;
      case 'accommodation':
        return Icons.hotel;
      case 'activity':
        return Icons.local_activity;
      default:
        return Icons.event;
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'flight':
        return Colors.blue;
      case 'accommodation':
        return Colors.purple;
      case 'activity':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String get _title {
    switch (type) {
      case 'flight':
        final origin = data['origin'] as String? ?? '';
        final destination = data['destination'] as String? ?? '';
        return '$origin to $destination';
      case 'accommodation':
        return data['hotelName'] as String? ?? 'Hotel';
      case 'activity':
        return data['name'] as String? ?? 'Activity';
      default:
        return 'Event';
    }
  }

  String? get _subtitle {
    switch (type) {
      case 'flight':
        final airline = data['airline'] as String?;
        final flightNumber = data['flightNumber'] as String?;
        if (airline != null && flightNumber != null) {
          return '$airline $flightNumber';
        }
        return airline ?? flightNumber;
      case 'accommodation':
        return 'Check-in';
      case 'activity':
        return data['location'] as String?;
      default:
        return null;
    }
  }

  String? get _timeStr {
    switch (type) {
      case 'flight':
        final departure = data['departureTime'] as String?;
        if (departure != null) {
          final dt = DateTime.tryParse(departure);
          if (dt != null) {
            final hour = dt.hour > 12
                ? dt.hour - 12
                : (dt.hour == 0 ? 12 : dt.hour);
            final period = dt.hour >= 12 ? 'PM' : 'AM';
            final minute = dt.minute.toString().padLeft(2, '0');
            return '$hour:$minute $period';
          }
        }
        return null;
      case 'accommodation':
        return null;
      case 'activity':
        final time = data['time'] as String?;
        return time;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use special flight widget for flights
    if (type == 'flight') {
      return FlightCard(data: data, onEdit: onEdit, onDelete: onDelete);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _iconColor, size: 20),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _subtitle!,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_timeStr != null)
                    Text(
                      _timeStr!,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
