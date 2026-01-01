import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/convex_service.dart';

class HotelOptionsSheet extends StatelessWidget {
  final String tripId;

  const HotelOptionsSheet({super.key, required this.tripId});

  static void show(BuildContext context, {required String tripId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => HotelOptionsSheet(tripId: tripId),
    );
  }

  void _onAddHotelManually(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualHotelFormSheet(tripId: tripId),
    );
  }

  void _onUploadHotelPdf(BuildContext context) {
    Navigator.pop(context);
    // TODO: Show PDF upload dialog for hotels
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                color: Colors.grey.shade300,
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

  const _ManualHotelFormSheet({required this.tripId});

  @override
  State<_ManualHotelFormSheet> createState() => _ManualHotelFormSheetState();
}

class _ManualHotelFormSheetState extends State<_ManualHotelFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _hotelNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomTypeController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _checkInDate;
  DateTime? _checkOutDate;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _hotelNameController.dispose();
    _cityController.dispose();
    _countryController.dispose();
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

  Future<void> _selectDate(bool isCheckIn) async {
    final initialDate = isCheckIn
        ? (_checkInDate ?? DateTime.now())
        : (_checkOutDate ?? _checkInDate ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (date != null) {
      setState(() {
        if (isCheckIn) {
          _checkInDate = date;
          // Auto-set check-out date if not set or if it's before check-in
          if (_checkOutDate == null || _checkOutDate!.isBefore(date)) {
            _checkOutDate = date.add(const Duration(days: 1));
          }
        } else {
          _checkOutDate = date;
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

      await convexService.createAccommodation(
        tripId: widget.tripId,
        hotelName: _hotelNameController.text.trim(),
        city: _cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : null,
        country: _countryController.text.trim().isNotEmpty
            ? _countryController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        roomType: _roomTypeController.text.trim().isNotEmpty
            ? _roomTypeController.text.trim()
            : null,
        checkIn: _checkInDate!.toIso8601String().split('T').first,
        checkOut: _checkOutDate?.toIso8601String().split('T').first,
        confirmationNumber: _confirmationController.text.trim().isNotEmpty
            ? _confirmationController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hotel added successfully'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding hotel: $e'),
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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Header
                  const Text(
                    'Add Hotel',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Enter your hotel details',
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

                  // City & Country row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityController,
                          decoration: _inputDecoration('City', 'e.g. Tokyo'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _countryController,
                          decoration: _inputDecoration('Country', 'e.g. Japan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address
                  TextFormField(
                    controller: _addressController,
                    decoration: _inputDecoration(
                      'Address (optional)',
                      'e.g. 123 Main Street',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Check-in Date
                  Text(
                    'Check-in',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DateButton(
                    icon: Icons.calendar_today,
                    label: _formatDate(_checkInDate),
                    onTap: () => _selectDate(true),
                  ),
                  const SizedBox(height: 16),

                  // Check-out Date
                  Text(
                    'Check-out',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _DateButton(
                    icon: Icons.calendar_today,
                    label: _formatDate(_checkOutDate),
                    onTap: () => _selectDate(false),
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
                        : const Text(
                            'Add Hotel',
                            style: TextStyle(
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

class _DateButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DateButton({
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
