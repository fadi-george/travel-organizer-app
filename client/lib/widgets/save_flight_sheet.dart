import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/convex_service.dart';
import 'airport_autocomplete.dart';
import 'loading_button.dart';
import 'pdf_upload_dialog.dart';

class FlightOptionsSheet extends StatelessWidget {
  final String tripId;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const FlightOptionsSheet({
    super.key,
    required this.tripId,
    this.tripStartDate,
    this.tripEndDate,
  });

  static void show(
    BuildContext context, {
    required String tripId,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FlightOptionsSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onAddFlightManually(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualFlightFormSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  static void showEditFlight(
    BuildContext context, {
    required String tripId,
    required Map<String, dynamic> flightData,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualFlightFormSheet(
        tripId: tripId,
        existingFlight: flightData,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onUploadFlightPdf(BuildContext context) {
    Navigator.pop(context);
    _showPdfUploadDialog(context);
  }

  Future<void> _showPdfUploadDialog(BuildContext context) async {
    final convexService = await ConvexService.getInstance();
    if (!context.mounted) return;

    PdfUploadDialog.showForFlights(
      context,
      tripId: tripId,
      onExtract: convexService.extractFlightsFromPdf,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Flight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.blue),
              ),
              title: const Text('Add Manually'),
              subtitle: const Text('Enter flight details by hand'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onAddFlightManually(context),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.upload_file, color: Colors.orange),
              ),
              title: const Text('Upload Flight Info (PDF)'),
              subtitle: const Text('Extract details from confirmation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onUploadFlightPdf(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ManualFlightFormSheet extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? existingFlight;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const _ManualFlightFormSheet({
    required this.tripId,
    this.existingFlight,
    this.tripStartDate,
    this.tripEndDate,
  });

  @override
  State<_ManualFlightFormSheet> createState() => _ManualFlightFormSheetState();
}

class _ManualFlightFormSheetState extends State<_ManualFlightFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _airlineController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _departureAirportCodeController = TextEditingController();
  final _arrivalAirportCodeController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _seatController = TextEditingController();
  final _cabinClassController = TextEditingController();

  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  DateTime? _arrivalDate;
  TimeOfDay? _arrivalTime;
  bool _isSubmitting = false;

  bool get isEditing => widget.existingFlight != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final flight = widget.existingFlight!;
      _airlineController.text = flight['airline'] as String? ?? '';
      _flightNumberController.text = flight['flightNumber'] as String? ?? '';
      _departureAirportCodeController.text =
          flight['departureAirportCode'] as String? ?? '';
      _arrivalAirportCodeController.text =
          flight['arrivalAirportCode'] as String? ?? '';
      _confirmationController.text =
          flight['confirmationNumber'] as String? ?? '';
      _seatController.text = flight['seatNumber'] as String? ?? '';
      _cabinClassController.text = flight['cabinClass'] as String? ?? '';

      final depDate = flight['departureDate'] as String?;
      if (depDate != null) {
        _departureDate = DateTime.tryParse(depDate);
      }

      final depTime = flight['departureTime'] as String?;
      if (depTime != null) {
        final parts = depTime.split(':');
        if (parts.length >= 2) {
          _departureTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }

      final arrDate = flight['arrivalDate'] as String?;
      if (arrDate != null) {
        _arrivalDate = DateTime.tryParse(arrDate);
      }

      final arrTime = flight['arrivalTime'] as String?;
      if (arrTime != null) {
        final parts = arrTime.split(':');
        if (parts.length >= 2) {
          _arrivalTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _airlineController.dispose();
    _flightNumberController.dispose();
    _departureAirportCodeController.dispose();
    _arrivalAirportCodeController.dispose();
    _confirmationController.dispose();
    _seatController.dispose();
    _cabinClassController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _selectDate(bool isDeparture) async {
    final firstDate = widget.tripStartDate ?? DateTime(1900);
    final lastDate = widget.tripEndDate ?? DateTime(3000);

    var initialDate = isDeparture
        ? (_departureDate ?? DateTime.now())
        : (_arrivalDate ?? _departureDate ?? DateTime.now());

    // Ensure initial date is within bounds
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (date != null) {
      setState(() {
        if (isDeparture) {
          _departureDate = date;
          // Auto-set arrival date if not set
          _arrivalDate ??= date;
        } else {
          _arrivalDate = date;
        }
      });
    }
  }

  Future<void> _selectTime(bool isDeparture) async {
    final initialTime = isDeparture
        ? (_departureTime ?? TimeOfDay.now())
        : (_arrivalTime ?? TimeOfDay.now());

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      setState(() {
        if (isDeparture) {
          _departureTime = time;
        } else {
          _arrivalTime = time;
        }
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_departureDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a departure date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final convexService = await ConvexService.getInstance();

      String? departureTimeStr;
      if (_departureTime != null) {
        departureTimeStr =
            '${_departureTime!.hour.toString().padLeft(2, '0')}:${_departureTime!.minute.toString().padLeft(2, '0')}';
      }

      String? arrivalTimeStr;
      if (_arrivalTime != null) {
        arrivalTimeStr =
            '${_arrivalTime!.hour.toString().padLeft(2, '0')}:${_arrivalTime!.minute.toString().padLeft(2, '0')}';
      }

      // Normalize flight number: remove spaces
      final flightNumber = _flightNumberController.text.trim().replaceAll(
        ' ',
        '',
      );

      final seatNumber = _seatController.text.trim();
      final cabinClass = _cabinClassController.text.trim();
      final departureAirportCode = _departureAirportCodeController.text
          .trim()
          .toUpperCase();
      final arrivalAirportCode = _arrivalAirportCodeController.text
          .trim()
          .toUpperCase();

      if (isEditing) {
        await convexService.updateFlight(
          id: widget.existingFlight!['_id'] as String,
          airline: _airlineController.text.trim(),
          flightNumber: flightNumber,
          departureAirportCode: departureAirportCode.isNotEmpty
              ? departureAirportCode
              : null,
          arrivalAirportCode: arrivalAirportCode.isNotEmpty
              ? arrivalAirportCode
              : null,
          departureDate: _departureDate!.toIso8601String().split('T').first,
          departureTime: departureTimeStr,
          arrivalDate: _arrivalDate?.toIso8601String().split('T').first,
          arrivalTime: arrivalTimeStr,
          confirmationNumber: _confirmationController.text.trim().isNotEmpty
              ? _confirmationController.text.trim()
              : null,
          seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
          cabinClass: cabinClass.isNotEmpty ? cabinClass : null,
        );
      } else {
        await convexService.createFlight(
          tripId: widget.tripId,
          airline: _airlineController.text.trim(),
          flightNumber: flightNumber,
          departureAirportCode: departureAirportCode,
          arrivalAirportCode: arrivalAirportCode,
          departureDate: _departureDate!.toIso8601String().split('T').first,
          departureTime: departureTimeStr,
          arrivalDate: _arrivalDate?.toIso8601String().split('T').first,
          arrivalTime: arrivalTimeStr,
          confirmationNumber: _confirmationController.text.trim().isNotEmpty
              ? _confirmationController.text.trim()
              : null,
          seatNumber: seatNumber.isNotEmpty ? seatNumber : null,
          cabinClass: cabinClass.isNotEmpty ? cabinClass : null,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'Flight updated' : 'Flight added successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding flight: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  Text(
                    isEditing ? 'Edit Flight' : 'Add Flight',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing
                        ? 'Update your flight details'
                        : 'Enter your flight details',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Airline & Flight Number row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _airlineController,
                          decoration: _inputDecoration(
                            'Airline',
                            'e.g. United',
                          ),
                          validator: (v) =>
                              v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _flightNumberController,
                          decoration: _inputDecoration('Flight #', 'UA123'),
                          validator: (v) =>
                              v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // From Airport
                  AirportAutocomplete(
                    controller: _departureAirportCodeController,
                    label: 'From',
                    hint: 'Search departure airport',
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // To Airport
                  AirportAutocomplete(
                    controller: _arrivalAirportCodeController,
                    label: 'To',
                    hint: 'Search arrival airport',
                    isDeparture: false,
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 20),

                  // Departure Date & Time
                  Text(
                    'Departure',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeButton(
                          icon: Icons.calendar_today,
                          label: _formatDate(_departureDate),
                          onTap: () => _selectDate(true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimeButton(
                          icon: Icons.access_time,
                          label: _formatTime(_departureTime),
                          onTap: () => _selectTime(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Arrival Date & Time
                  Text(
                    'Arrival',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeButton(
                          icon: Icons.calendar_today,
                          label: _formatDate(_arrivalDate),
                          onTap: () => _selectDate(false),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimeButton(
                          icon: Icons.access_time,
                          label: _formatTime(_arrivalTime),
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Confirmation Number (optional)
                  TextFormField(
                    controller: _confirmationController,
                    decoration: _inputDecoration(
                      'Confirmation # (optional)',
                      'e.g. ABC123',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Seat & Cabin Class row (optional)
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _seatController,
                          decoration: _inputDecoration(
                            'Seat (optional)',
                            'e.g. 12A',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: TextFormField(
                          controller: _cabinClassController,
                          decoration: _inputDecoration(
                            'Cabin Class (optional)',
                            'e.g. Economy',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  LoadingButton(
                    label: isEditing ? 'Update Flight' : 'Add Flight',
                    isLoading: _isSubmitting,
                    onPressed: _onSubmit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF7043), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateTimeButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: label.startsWith('Select')
                      ? Colors.grey.shade500
                      : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
