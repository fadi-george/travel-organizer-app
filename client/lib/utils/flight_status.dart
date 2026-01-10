import 'package:flutter/material.dart';

class FlightStatusBadge extends StatelessWidget {
  final String? status;
  final bool small;

  const FlightStatusBadge({
    super.key,
    required this.status,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    if (status == null || status!.isEmpty) return const SizedBox.shrink();

    final color = getFlightStatusColor(status);
    final displayStatus = formatFlightStatus(status);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(small ? 10 : 12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        displayStatus,
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

Color getFlightStatusColor(String? status) {
  if (status == null) return Colors.grey;

  final s = status.toLowerCase();
  if (s.contains('landed') || s.contains('arrived')) return Colors.green;
  if (s.contains('en route') ||
      s.contains('active') ||
      s.contains('airborne')) {
    return Colors.blue;
  }
  if (s.contains('cancelled') || s.contains('diverted')) return Colors.red;
  if (s.contains('delayed')) return Colors.orange;
  return Colors.grey.shade600;
}

String formatFlightStatus(String? status) {
  if (status == null) return '';

  final s = status.toLowerCase();
  if (s.contains('landed')) return 'Landed';
  if (s.contains('en route')) return 'En Route';
  if (s.contains('cancelled')) return 'Cancelled';
  if (s.contains('delayed')) return 'Delayed';
  if (s.contains('scheduled')) return 'Scheduled';
  if (s.contains('active') || s.contains('airborne')) return 'En Route';
  return status;
}
