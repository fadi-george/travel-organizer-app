import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/convex_service.dart';
import 'address_autocomplete.dart';
import 'loading_button.dart';
import 'pdf_upload_dialog.dart';

class ActivityOptionsSheet extends StatelessWidget {
  final String tripId;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const ActivityOptionsSheet({
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
      builder: (context) => ActivityOptionsSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  static void showEditActivity(
    BuildContext context, {
    required String tripId,
    required Map<String, dynamic> activityData,
    DateTime? tripStartDate,
    DateTime? tripEndDate,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualActivityFormSheet(
        tripId: tripId,
        existingActivity: activityData,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onAddActivityManually(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualActivityFormSheet(
        tripId: tripId,
        tripStartDate: tripStartDate,
        tripEndDate: tripEndDate,
      ),
    );
  }

  void _onUploadActivityPdf(BuildContext context) {
    Navigator.pop(context);
    _showPdfUploadDialog(context);
  }

  Future<void> _showPdfUploadDialog(BuildContext context) async {
    final convexService = await ConvexService.getInstance();
    if (!context.mounted) return;

    PdfUploadDialog.showForActivities(
      context,
      tripId: tripId,
      onExtract: convexService.extractActivitiesFromPdf,
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
              'Add Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7043).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.edit, color: Color(0xFFFF7043)),
              ),
              title: const Text('Add Manually'),
              subtitle: const Text('Enter activity details by hand'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onAddActivityManually(context),
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
              title: const Text('Upload Activities (PDF)'),
              subtitle: const Text('Extract details from itinerary'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _onUploadActivityPdf(context),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ManualActivityFormSheet extends StatefulWidget {
  final String tripId;
  final Map<String, dynamic>? existingActivity;
  final DateTime? tripStartDate;
  final DateTime? tripEndDate;

  const _ManualActivityFormSheet({
    required this.tripId,
    this.existingActivity,
    this.tripStartDate,
    this.tripEndDate,
  });

  @override
  State<_ManualActivityFormSheet> createState() =>
      _ManualActivityFormSheetState();
}

class _ManualActivityFormSheetState extends State<_ManualActivityFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _date;
  TimeOfDay? _time;
  String? _selectedType = 'Sightseeing';
  bool _isSubmitting = false;

  bool get isEditing => widget.existingActivity != null;

  static const Map<String, IconData> _activityTypes = {
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

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final activity = widget.existingActivity!;
      _titleController.text = activity['title'] as String? ?? '';
      _locationController.text = activity['location'] as String? ?? '';
      _notesController.text = activity['notes'] as String? ?? '';
      _selectedType = activity['type'] as String?;

      final dateStr = activity['date'] as String?;
      if (dateStr != null) {
        _date = DateTime.tryParse(dateStr);
      }

      final timeStr = activity['time'] as String?;
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          _time = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Select time (optional)';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _selectDate() async {
    final firstDate = widget.tripStartDate ?? DateTime(1900);
    final lastDate = widget.tripEndDate ?? DateTime(3000);

    // Ensure initial date is within bounds
    DateTime initialDate = _date ?? DateTime.now();
    if (initialDate.isBefore(firstDate)) initialDate = firstDate;
    if (initialDate.isAfter(lastDate)) initialDate = lastDate;

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: const Color(0xFFFF7043)),
        ),
        child: child!,
      ),
    );

    if (date != null) {
      setState(() => _date = date);
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: const Color(0xFFFF7043)),
        ),
        child: child!,
      ),
    );

    if (time != null) {
      setState(() => _time = time);
    }
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_date == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final convexService = await ConvexService.getInstance();

      String? timeStr;
      if (_time != null) {
        timeStr =
            '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
      }

      if (isEditing) {
        await convexService.updateActivity(
          id: widget.existingActivity!['_id'] as String,
          title: _titleController.text.trim(),
          date: _date!.toIso8601String().split('T').first,
          time: timeStr,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          type: _selectedType,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );
      } else {
        await convexService.createActivity(
          tripId: widget.tripId,
          title: _titleController.text.trim(),
          date: _date!.toIso8601String().split('T').first,
          time: timeStr,
          location: _locationController.text.trim().isNotEmpty
              ? _locationController.text.trim()
              : null,
          type: _selectedType,
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
                ? 'Activity updated successfully'
                : 'Activity added successfully',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error ${isEditing ? 'updating' : 'adding'} activity: $e',
          ),
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
                    isEditing ? 'Edit Activity' : 'Add Activity',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEditing
                        ? 'Update your activity details'
                        : 'Plan something fun for your trip',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: _inputDecoration(
                      'Title',
                      'e.g. Visit Eiffel Tower',
                    ),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Date & Time row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DateTimeButton(
                              icon: Icons.calendar_today,
                              label: _formatDate(_date),
                              onTap: _selectDate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _DateTimeButton(
                              icon: Icons.access_time,
                              label: _formatTime(_time),
                              onTap: _selectTime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Activity Type
                  DropdownButtonFormField<String>(
                    initialValue: _selectedType,
                    decoration: _inputDecoration('Type', ''),
                    hint: const Text('Select activity type'),
                    items: _activityTypes.entries.map((entry) {
                      return DropdownMenuItem(
                        value: entry.key,
                        child: Row(
                          children: [
                            Icon(
                              entry.value,
                              size: 20,
                              color: const Color(0xFFFF7043),
                            ),
                            const SizedBox(width: 12),
                            Text(entry.key),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedType = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Location with Google Places Autocomplete
                  AddressAutocomplete(
                    controller: _locationController,
                    label: 'Location (optional)',
                    hint: 'e.g. Champ de Mars, Paris',
                  ),
                  const SizedBox(height: 16),

                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: _inputDecoration(
                      'Notes (optional)',
                      'e.g. Guided tour, buy tickets in advance',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Submit button
                  LoadingButton(
                    label: isEditing ? 'Update Activity' : 'Add Activity',
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
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
