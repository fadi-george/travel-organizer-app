import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/convex_service.dart';
import 'address_autocomplete.dart';
import 'pdf_upload_dialog.dart';

class HotelOptionsSheet extends StatelessWidget {
  final String tripId;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const HotelOptionsSheet({
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
      builder: (context) => HotelOptionsSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  static void showEditHotel(
    BuildContext context, {
    required String tripId,
    required Map<String, dynamic> hotelData,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualHotelFormSheet(
        tripId: tripId,
        existingHotel: hotelData,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onAddHotelManually(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualHotelFormSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onUploadHotelPdf(BuildContext context) {
    Navigator.pop(context);
    _showPdfUploadDialog(context);
  }

  Future<void> _showPdfUploadDialog(BuildContext context) async {
    final convexService = await ConvexService.getInstance();
    if (!context.mounted) return;

    PdfUploadDialog.showForAccommodations(
      context,
      tripId: tripId,
      onExtract: convexService.extractAccommodationsFromPdf,
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
              'Add Hotel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Colors.purple),
              ),
              title: const Text('Add Manually'),
              subtitle: const Text('Enter hotel details by hand'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onAddHotelManually(context),
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
              title: const Text('Upload Hotel Info (PDF)'),
              subtitle: const Text('Extract details from confirmation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onUploadHotelPdf(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ManualHotelFormSheet extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? existingHotel;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const _ManualHotelFormSheet({
    required this.tripId,
    this.existingHotel,
    this.tripStartDate,
    this.tripEndDate,
  });

  @override
  State<_ManualHotelFormSheet> createState() => _ManualHotelFormSheetState();
}

class _ManualHotelFormSheetState extends State<_ManualHotelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hotelNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomTypeController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _checkInDate;
  TimeOfDay _checkInTime = const TimeOfDay(
    hour: 15,
    minute: 0,
  ); // Default 3:00 PM
  DateTime? _checkOutDate;
  TimeOfDay _checkOutTime = const TimeOfDay(
    hour: 11,
    minute: 0,
  ); // Default 11:00 AM
  bool _isSubmitting = false;

  bool get isEditing => widget.existingHotel != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final hotel = widget.existingHotel!;
      _hotelNameController.text = hotel['hotelName'] as String? ?? '';
      _addressController.text = hotel['address'] as String? ?? '';
      _roomTypeController.text = hotel['roomType'] as String? ?? '';
      _confirmationController.text =
          hotel['confirmationNumber'] as String? ?? '';
      _notesController.text = hotel['notes'] as String? ?? '';

      final checkIn = hotel['checkIn'] as String?;
      if (checkIn != null) {
        _checkInDate = DateTime.tryParse(checkIn);
      }
      final checkInTimeStr = hotel['checkInTime'] as String?;
      if (checkInTimeStr != null) {
        final parts = checkInTimeStr.split(':');
        if (parts.length >= 2) {
          _checkInTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 15,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      final checkOut = hotel['checkOut'] as String?;
      if (checkOut != null) {
        _checkOutDate = DateTime.tryParse(checkOut);
      }
      final checkOutTimeStr = hotel['checkOutTime'] as String?;
      if (checkOutTimeStr != null) {
        final parts = checkOutTimeStr.split(':');
        if (parts.length >= 2) {
          _checkOutTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 11,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _hotelNameController.dispose();
    _addressController.dispose();
    _roomTypeController.dispose();
    _confirmationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _timeToString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _selectDate(bool isCheckIn) async {
    final firstDate = widget.tripStartDate ?? DateTime(1900);
    final lastDate = widget.tripEndDate ?? DateTime(3000);

    var initialDate = isCheckIn
        ? (_checkInDate ?? DateTime.now())
        : (_checkOutDate ?? _checkInDate ?? DateTime.now());

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
        if (isCheckIn) {
          _checkInDate = date;
          // Auto-set check-out date if not set or if it's before check-in
          if (_checkOutDate == null || _checkOutDate!.isBefore(date)) {
            final nextDay = date.add(const Duration(days: 1));
            _checkOutDate = nextDay.isAfter(lastDate) ? lastDate : nextDay;
          }
        } else {
          _checkOutDate = date;
        }
      });
    }
  }

  Future<void> _selectTime(bool isCheckIn) async {
    final initialTime = isCheckIn ? _checkInTime : _checkOutTime;

    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      setState(() {
        if (isCheckIn) {
          _checkInTime = time;
        } else {
          _checkOutTime = time;
        }
      });
    }
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_checkInDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a check-in date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final convexService = await ConvexService.getInstance();

      if (isEditing) {
        await convexService.updateAccommodation(
          id: widget.existingHotel!['_id'] as String,
          hotelName: _hotelNameController.text.trim(),
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          roomType: _roomTypeController.text.trim().isNotEmpty
              ? _roomTypeController.text.trim()
              : null,
          checkIn: _checkInDate!.toIso8601String().split('T').first,
          checkInTime: _timeToString(_checkInTime),
          checkOut: _checkOutDate?.toIso8601String().split('T').first,
          checkOutTime: _timeToString(_checkOutTime),
          confirmationNumber: _confirmationController.text.trim().isNotEmpty
              ? _confirmationController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      } else {
        await convexService.createAccommodation(
          tripId: widget.tripId,
          hotelName: _hotelNameController.text.trim(),
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          roomType: _roomTypeController.text.trim().isNotEmpty
              ? _roomTypeController.text.trim()
              : null,
          checkIn: _checkInDate!.toIso8601String().split('T').first,
          checkInTime: _timeToString(_checkInTime),
          checkOut: _checkOutDate?.toIso8601String().split('T').first,
          checkOutTime: _timeToString(_checkOutTime),
          confirmationNumber: _confirmationController.text.trim().isNotEmpty
              ? _confirmationController.text.trim()
              : null,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Hotel updated successfully'
                : 'Hotel added successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error ${isEditing ? 'updating' : 'adding'} hotel: $e'),
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
                    isEditing ? 'Edit Hotel' : 'Add Hotel',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing
                        ? 'Update your hotel details'
                        : 'Enter your hotel details',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Hotel Name
                  TextFormField(
                    controller: _hotelNameController,
                    decoration: _inputDecoration(
                      'Hotel Name',
                      'e.g. Hilton Garden Inn',
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address with autocomplete
                  AddressAutocomplete(
                    controller: _addressController,
                    label: 'Address',
                    hint: 'e.g. 123 Main Street, Tokyo, Japan',
                  ),
                  const SizedBox(height: 20),

                  // Check-in Date & Time
                  Text(
                    'Check-in',
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
                        flex: 3,
                        child: _DateTimeButton(
                          icon: Icons.calendar_today,
                          label: _formatDate(_checkInDate),
                          onTap: () => _selectDate(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _DateTimeButton(
                          icon: Icons.access_time,
                          label: _formatTime(_checkInTime),
                          onTap: () => _selectTime(true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Check-out Date & Time
                  Text(
                    'Check-out',
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
                        flex: 3,
                        child: _DateTimeButton(
                          icon: Icons.calendar_today,
                          label: _formatDate(_checkOutDate),
                          onTap: () => _selectDate(false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _DateTimeButton(
                          icon: Icons.access_time,
                          label: _formatTime(_checkOutTime),
                          onTap: () => _selectTime(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Room Type & Confirmation row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _roomTypeController,
                          decoration: _inputDecoration(
                            'Room Type',
                            'e.g. Deluxe King',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _confirmationController,
                          decoration: _inputDecoration(
                            'Confirmation #',
                            'e.g. ABC123',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: _inputDecoration(
                      'Notes (optional)',
                      'e.g. Late check-in requested',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  FilledButton(
                    onPressed: _isSubmitting ? null : _onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEditing ? 'Update Hotel' : 'Add Hotel',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
