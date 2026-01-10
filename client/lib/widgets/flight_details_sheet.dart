import 'package:flutter/material.dart';
import '../services/airports_service.dart';
import '../services/convex_service.dart';
import '../utils/time_format.dart';

const _accentColor = Color(0xFF5B9BD5);

/// Shows a bottom sheet with detailed flight information.
void showFlightDetailsSheet(
  BuildContext context,
  Map<String, dynamic> data, {
  VoidCallback? onStatusRefreshed,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _FlightDetailsContent(data: data, onStatusRefreshed: onStatusRefreshed),
  );
}

class _FlightDetailsContent extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback? onStatusRefreshed;

  const _FlightDetailsContent({required this.data, this.onStatusRefreshed});

  @override
  State<_FlightDetailsContent> createState() => _FlightDetailsContentState();
}

class _FlightDetailsContentState extends State<_FlightDetailsContent> {
  bool _isRefreshing = false;
  late String? _status;
  late String? _gate;
  String? _estimatedOut; // Full ISO timestamp (UTC)
  String? _estimatedIn; // Full ISO timestamp (UTC)

  @override
  void initState() {
    super.initState();
    _status = widget.data['status'] as String?;
    _gate = widget.data['departureGate'] as String?;
  }

  Future<void> _refreshStatus() async {
    final flightId = widget.data['_id'] as String?;
    if (flightId == null) return;

    setState(() => _isRefreshing = true);

    try {
      final convexService = await ConvexService.getInstance();
      final result = await convexService.refreshFlightStatus(
        flightId: flightId,
      );
      widget.onStatusRefreshed?.call();

      // Update local state with new data
      if (mounted && result != null) {
        setState(() {
          _status = result['status'] as String?;
          _gate = result['departureGate'] as String?;
          _estimatedOut = result['estimatedOut'] as String?;
          _estimatedIn = result['estimatedIn'] as String?;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing flight status: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;

    final s = status.toLowerCase();
    if (s.contains('landed') || s.contains('arrived')) return Colors.green;
    if (s.contains('en route') ||
        s.contains('active') ||
        s.contains('airborne'))
      return Colors.blue;
    if (s.contains('cancelled') || s.contains('diverted')) return Colors.red;
    if (s.contains('delayed')) return Colors.orange;
    return Colors.grey;
  }

  String _formatStatus(String? status) {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final origin = widget.data['departureAirportCode'] as String? ?? 'DEP';
    final destination = widget.data['arrivalAirportCode'] as String? ?? 'ARR';
    final originAirport = AirportsService.instance.getByIata(origin);
    final destinationAirport = AirportsService.instance.getByIata(destination);
    final originCityName = originAirport?.city ?? origin;
    final destinationCityName = destinationAirport?.city ?? destination;
    final departureDate = widget.data['departureDate'] as String?;
    final arrivalDate = widget.data['arrivalDate'] as String?;
    final originalDepartureTime = widget.data['departureTime'] as String?;
    final originalArrivalTime = widget.data['arrivalTime'] as String?;
    final flightNumber = widget.data['flightNumber'] as String? ?? '';
    final airline = widget.data['airline'] as String?;
    final terminal = widget.data['departureTerminal'] as String?;
    final confirmationNumber = widget.data['confirmationNumber'] as String?;
    final seatNumber = widget.data['seatNumber'] as String?;
    // Use local state for status and gate (updated by refresh)
    final status = _status;
    final gate = _gate;

    // Use estimated times if available (with timezone conversion), otherwise original
    final departureTime = _estimatedOut != null
        ? formatUtcToLocalTime(_estimatedOut, timezone: originAirport?.tz)
        : formatTime(originalDepartureTime);
    final arrivalTime = _estimatedIn != null
        ? formatUtcToLocalTime(_estimatedIn, timezone: destinationAirport?.tz)
        : formatTime(originalArrivalTime);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Flight route header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    origin,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          height: 2,
                          color: isDark
                              ? const Color(0xFF4A6572)
                              : const Color(0xFFB8D4E8),
                        ),
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
                              color: _accentColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    destination,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // City names with status badge centered
              Row(
                children: [
                  Expanded(
                    child: Text(
                      originCityName,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  // Status badge
                  if (status != null && status.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getStatusColor(status).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _formatStatus(status),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _getStatusColor(status),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      destinationCityName,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Departure and arrival times
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.onSurface.withValues(alpha: 0.05)
                      : colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Departure',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                ),
                              ),
                              if (gate != null && gate.isNotEmpty) ...[
                                Text(
                                  ' · Gate $gate',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _accentColor,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            departureTime,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _formatDate(departureDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final divider = Container(
                          width: 1,
                          height: 14,
                          color: colorScheme.onSurface.withValues(alpha: 0.2),
                        );
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            divider,
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                onPressed: _isRefreshing
                                    ? null
                                    : _refreshStatus,
                                icon: _isRefreshing
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.refresh,
                                        size: 20,
                                        color: colorScheme.onSurface.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                splashRadius: 20,
                              ),
                            ),
                            divider,
                          ],
                        );
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Arrival',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            arrivalTime,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            _formatDate(arrivalDate ?? departureDate),
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Flight details grid
              _buildDetailsSection(
                colorScheme: colorScheme,
                isDark: isDark,
                items: [
                  if (flightNumber.isNotEmpty)
                    _DetailItem(label: 'Flight', value: flightNumber),
                  if (airline != null && airline.isNotEmpty)
                    _DetailItem(label: 'Airline', value: airline),
                  if (terminal != null && terminal.isNotEmpty)
                    _DetailItem(label: 'Terminal', value: terminal),
                  if (seatNumber != null && seatNumber.isNotEmpty)
                    _DetailItem(label: 'Seat', value: seatNumber),
                  if (confirmationNumber != null &&
                      confirmationNumber.isNotEmpty)
                    _DetailItem(
                      label: 'Confirmation',
                      value: confirmationNumber,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
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

Widget _buildDetailsSection({
  required ColorScheme colorScheme,
  required bool isDark,
  required List<_DetailItem> items,
}) {
  if (items.isEmpty) return const SizedBox.shrink();

  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: items.map((item) {
      return Container(
        constraints: const BoxConstraints(minWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.onSurface.withValues(alpha: 0.05)
              : colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
      );
    }).toList(),
  );
}

class _DetailItem {
  final String label;
  final String value;

  const _DetailItem({required this.label, required this.value});
}
