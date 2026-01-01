import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/convex_service.dart';

class FlightOptionsSheet extends StatelessWidget {
  final String tripId;

  const FlightOptionsSheet({super.key, required this.tripId});

  static void show(BuildContext context, {required String tripId}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => FlightOptionsSheet(tripId: tripId),
    );
  }

  void _onAddFlightManually(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualFlightFormSheet(tripId: tripId),
    );
  }

  static void showEditFlight(
    BuildContext context, {
    required String tripId,
    required Map<String, dynamic> flightData,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ManualFlightFormSheet(tripId: tripId, existingFlight: flightData),
    );
  }

  void _onUploadFlightPdf(BuildContext context) {
    Navigator.pop(context);
    _showPdfUploadDialog(context);
  }

  void _showPdfUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _PdfUploadDialog(tripId: tripId),
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

class _PdfUploadDialog extends StatefulWidget {
  final String tripId;

  const _PdfUploadDialog({required this.tripId});

  @override
  State<_PdfUploadDialog> createState() => _PdfUploadDialogState();
}

class _ManualFlightFormSheet extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? existingFlight;

  const _ManualFlightFormSheet({required this.tripId, this.existingFlight});

  @override
  State<_ManualFlightFormSheet> createState() => _ManualFlightFormSheetState();
}

class _ManualFlightFormSheetState extends State<_ManualFlightFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _airlineController = TextEditingController();
  final _flightNumberController = TextEditingController();
  final _departureCityController = TextEditingController();
  final _arrivalCityController = TextEditingController();
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
      _departureCityController.text = flight['departureCity'] as String? ?? '';
      _arrivalCityController.text = flight['arrivalCity'] as String? ?? '';
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
    _departureCityController.dispose();
    _arrivalCityController.dispose();
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
    final initialDate = isDeparture
        ? (_departureDate ?? DateTime.now())
        : (_arrivalDate ?? _departureDate ?? DateTime.now());

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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

      if (isEditing) {
        await convexService.updateFlight(
          id: widget.existingFlight!['_id'] as String,
          airline: _airlineController.text.trim(),
          flightNumber: flightNumber,
          departureCity: _departureCityController.text.trim(),
          arrivalCity: _arrivalCityController.text.trim(),
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
          departureCity: _departureCityController.text.trim(),
          arrivalCity: _arrivalCityController.text.trim(),
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

                  // Departure City
                  TextFormField(
                    controller: _departureCityController,
                    decoration: _inputDecoration('From', 'e.g. Newark (EWR)'),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Arrival City
                  TextFormField(
                    controller: _arrivalCityController,
                    decoration: _inputDecoration('To', 'e.g. Tokyo (NRT)'),
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
                            isEditing ? 'Update Flight' : 'Add Flight',
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

class _PdfUploadDialogState extends State<_PdfUploadDialog> {
  PlatformFile? _selectedFile;
  bool _isUploading = false;
  String? _error;

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick file: $e';
      });
    }
  }

  Future<void> _uploadAndExtract() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      // Read file and convert to base64
      final file = File(_selectedFile!.path!);
      final bytes = await file.readAsBytes();
      final base64Pdf = base64Encode(bytes);

      // Call Convex action
      final convexService = await ConvexService.getInstance();
      final result = await convexService.extractFlightsFromPdf(
        tripId: widget.tripId,
        pdfBase64: base64Pdf,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final flights = result['flights'] as List?;
        final count = flights?.length ?? 0;

        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Extracted $count flight${count > 1 ? 's' : ''} from PDF'
                  : 'No flights found in PDF',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: count > 0 ? Colors.green : Colors.orange,
          ),
        );
      } else {
        setState(() {
          _error = result['error'] ?? 'Failed to extract flights';
          _isUploading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Upload Flight PDF',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a flight confirmation PDF to automatically extract flight details',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const SizedBox(height: 24),

            // Drop zone / file picker
            GestureDetector(
              onTap: _isUploading ? null : _pickFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: _selectedFile != null
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null
                        ? Colors.green.shade300
                        : Colors.grey.shade300,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null
                          ? Colors.green
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.name
                          : 'Tap to select PDF',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedFile != null
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: _selectedFile != null
                            ? Colors.green.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedFile != null && !_isUploading
                        ? _uploadAndExtract
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7043),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Extract Flights'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
