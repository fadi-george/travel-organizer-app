import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import '../models/trip.dart';
import '../services/convex_service.dart';

class CreateTripSheet extends StatefulWidget {
  final void Function(
    String name,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
  )?
  onTripCreated;
  final Trip? existingTrip;

  const CreateTripSheet({super.key, this.onTripCreated, this.existingTrip});

  bool get isEditing => existingTrip != null;

  @override
  State<CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<CreateTripSheet>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DateTime? _startDate;
  DateTime? _endDate;
  bool _isSubmitting = false;
  String? _dateError;

  late final AnimationController _planeController;
  late final Animation<double> _oscillation;

  @override
  void initState() {
    super.initState();
    _planeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _oscillation = Tween<double>(begin: -1.0, end: 1.0).animate(
      CurvedAnimation(parent: _planeController, curve: Curves.easeInOut),
    );

    // Populate fields if editing an existing trip
    if (widget.existingTrip != null) {
      final trip = widget.existingTrip!;
      _nameController.text = trip.name;
      _notesController.text = trip.notes ?? '';
      _startDate = DateTime.tryParse(trip.startDate);
      _endDate = DateTime.tryParse(trip.endDate);
    }
  }

  @override
  void dispose() {
    _planeController.dispose();
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<DateTime?> _showThemedDatePicker({
    required DateTime initialDate,
    required DateTime firstDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: const Color(0xFFFF7043)),
        ),
        child: child!,
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final picked = await _showThemedDatePicker(
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _dateError = null;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await _showThemedDatePicker(
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate:
          _startDate ?? DateTime.now().subtract(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
        _dateError = null;
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return DateFormat('MMM d, yyyy').format(date);
  }

  String? _validateDates() {
    if (_startDate == null) {
      return 'Please select a start date';
    }
    if (_endDate == null) {
      return 'Please select an end date';
    }
    return null;
  }

  Future<void> _onSubmit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final dateError = _validateDates();
    if (dateError != null) {
      setState(() => _dateError = dateError);
      return;
    }
    setState(() => _dateError = null);

    setState(() => _isSubmitting = true);

    try {
      final name = _nameController.text.trim();
      final notes = _notesController.text.trim();

      final convexService = await ConvexService.getInstance();

      if (widget.isEditing) {
        await convexService.updateTrip(
          id: widget.existingTrip!.id,
          name: name,
          startDate: _startDate!.toIso8601String(),
          endDate: _endDate!.toIso8601String(),
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await convexService.createTrip(
          name: name,
          startDate: _startDate!.toIso8601String(),
          endDate: _endDate!.toIso8601String(),
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (!mounted) return;

      Navigator.pop(context);
      widget.onTripCreated?.call(
        name,
        _startDate,
        _endDate,
        notes.isEmpty ? null : notes,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error ${widget.isEditing ? 'updating' : 'creating'} trip: $e',
          ),
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

                  // Header row: Title on left, 3D model on right
                  SizedBox(
                    height: 120,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Title and subtitle
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isEditing
                                    ? 'Edit trip'
                                    : 'Create a new trip',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.isEditing
                                    ? 'Update your trip details'
                                    : 'Plan your next adventure',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 3D Airplane model
                        SizedBox(
                          width: 140,
                          height: 120,
                          child: AnimatedBuilder(
                            animation: _oscillation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(
                                  _oscillation.value * 6,
                                  _oscillation.value * -6,
                                ),
                                child: child,
                              );
                            },
                            child: IgnorePointer(
                              child: ModelViewer(
                                src: 'assets/models/toy_airplane.glb',
                                alt: 'Toy airplane',
                                autoRotate: false,
                                cameraControls: false,
                                disableZoom: true,
                                backgroundColor: Colors.transparent,
                                cameraOrbit: '45deg 55deg 20m',
                                fieldOfView: '20deg',
                                interactionPrompt: InteractionPrompt.none,
                                relatedCss: '''
                                    model-viewer::part(default-progress-bar) { display: none !important; }
                                  ''',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Trip name field
                  TextFormField(
                    controller: _nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      'Trip name *',
                      'e.g. London Trip',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a trip name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date pickers row
                  Row(
                    children: [
                      Expanded(
                        child: _DatePickerField(
                          label: 'Start date *',
                          value: _formatDate(_startDate),
                          hasValue: _startDate != null,
                          onTap: _selectStartDate,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'End date *',
                          value: _formatDate(_endDate),
                          hasValue: _endDate != null,
                          onTap: _selectEndDate,
                        ),
                      ),
                    ],
                  ),
                  if (_dateError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _dateError!,
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Notes field
                  TextFormField(
                    controller: _notesController,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 3,
                    decoration: _inputDecoration(
                      'Notes (optional)',
                      'Add any notes about your trip',
                      alignLabelWithHint: true,
                    ),
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
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            widget.isEditing ? 'Update Trip' : 'Create Trip',
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

  InputDecoration _inputDecoration(
    String label,
    String hint, {
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      alignLabelWithHint: alignLabelWithHint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF7043), width: 2),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  final bool hasValue;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.value,
    required this.hasValue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: hasValue
                      ? const Color(0xFFFF7043)
                      : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: hasValue ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
