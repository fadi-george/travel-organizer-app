import 'package:flutter/material.dart';
import 'activity_card.dart';
import 'flight_card.dart';
import 'flight_details_sheet.dart';
import 'hotel_card.dart';

class TimelineItem extends StatelessWidget {
  final String type;
  final Map<String, dynamic> data;
  final bool isLast;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final HotelCardType hotelCardType;

  const TimelineItem({
    super.key,
    required this.type,
    required this.data,
    this.isLast = false,
    this.onEdit,
    this.onDelete,
    this.hotelCardType = HotelCardType.checkIn,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case 'flight':
        return FlightCard(
          data: data,
          viewType: FlightCardViewType.timeline,
          onTap: () => showFlightDetailsSheet(context, data),
          onEdit: onEdit,
          onDelete: onDelete,
        );
      case 'accommodation':
        return HotelCard(
          data: data,
          type: hotelCardType,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      case 'activity':
        return ActivityCard(
          data: data,
          viewType: ActivityCardViewType.timeline,
          onEdit: onEdit,
          onDelete: onDelete,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
