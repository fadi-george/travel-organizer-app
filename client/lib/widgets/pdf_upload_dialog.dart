import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The type of content to extract from a PDF
enum PdfExtractType { flights, accommodations, activities }

/// A reusable dialog for uploading PDFs and extracting travel information
class PdfUploadDialog extends StatefulWidget {
  final String tripId;
  final PdfExtractType extractType;
  final Future<Map<String, dynamic>> Function({
    required String tripId,
    required String pdfBase64,
  })
  onExtract;

  const PdfUploadDialog({
    super.key,
    required this.tripId,
    required this.extractType,
    required this.onExtract,
  });

  /// Show the dialog for extracting flights
  static void showForFlights(
    BuildContext context, {
    required String tripId,
    required Future<Map<String, dynamic>> Function({
      required String tripId,
      required String pdfBase64,
    })
    onExtract,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PdfUploadDialog(
        tripId: tripId,
        extractType: PdfExtractType.flights,
        onExtract: onExtract,
      ),
    );
  }

  /// Show the dialog for extracting accommodations
  static void showForAccommodations(
    BuildContext context, {
    required String tripId,
    required Future<Map<String, dynamic>> Function({
      required String tripId,
      required String pdfBase64,
    })
    onExtract,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PdfUploadDialog(
        tripId: tripId,
        extractType: PdfExtractType.accommodations,
        onExtract: onExtract,
      ),
    );
  }

  /// Show the dialog for extracting activities
  static void showForActivities(
    BuildContext context, {
    required String tripId,
    required Future<Map<String, dynamic>> Function({
      required String tripId,
      required String pdfBase64,
    })
    onExtract,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => PdfUploadDialog(
        tripId: tripId,
        extractType: PdfExtractType.activities,
        onExtract: onExtract,
      ),
    );
  }

  @override
  State<PdfUploadDialog> createState() => _PdfUploadDialogState();
}

class _PdfUploadDialogState extends State<PdfUploadDialog> {
  PlatformFile? _selectedFile;
  final bool _isUploading = false;
  String? _error;

  String get _title {
    switch (widget.extractType) {
      case PdfExtractType.flights:
        return 'Upload Flight PDF';
      case PdfExtractType.accommodations:
        return 'Upload Hotel PDF';
      case PdfExtractType.activities:
        return 'Upload Itinerary PDF';
    }
  }

  String get _subtitle {
    switch (widget.extractType) {
      case PdfExtractType.flights:
        return 'Select a flight confirmation PDF to automatically extract flight details';
      case PdfExtractType.accommodations:
        return 'Select a hotel booking PDF to automatically extract accommodation details';
      case PdfExtractType.activities:
        return 'Select an itinerary PDF to automatically extract activity details';
    }
  }

  String get _extractButtonText => 'Extract';

  String get _itemName {
    switch (widget.extractType) {
      case PdfExtractType.flights:
        return 'flight';
      case PdfExtractType.accommodations:
        return 'hotel';
      case PdfExtractType.activities:
        return 'activity';
    }
  }

  String get _itemNamePlural {
    switch (widget.extractType) {
      case PdfExtractType.flights:
        return 'flights';
      case PdfExtractType.accommodations:
        return 'hotels';
      case PdfExtractType.activities:
        return 'activities';
    }
  }

  String get _resultKey {
    switch (widget.extractType) {
      case PdfExtractType.flights:
        return 'flights';
      case PdfExtractType.accommodations:
        return 'accommodations';
      case PdfExtractType.activities:
        return 'activities';
    }
  }

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

    // Read file and convert to base64 before closing
    final file = File(_selectedFile!.path!);
    final bytes = await file.readAsBytes();
    final base64Pdf = base64Encode(bytes);

    // Close dialog immediately and show processing snackbar
    if (!mounted) return;
    Navigator.pop(context);

    final messenger = ScaffoldMessenger.of(context);
    final itemName = _itemName;
    final itemNamePlural = _itemNamePlural;
    final resultKey = _resultKey;

    // Show processing snackbar
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Text('Processing $itemNamePlural PDF...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(
          minutes: 5,
        ), // Long duration, will be dismissed
        backgroundColor: AppColors.primary,
      ),
    );

    try {
      // Call the extraction function
      final result = await widget.onExtract(
        tripId: widget.tripId,
        pdfBase64: base64Pdf,
      );

      // Dismiss processing snackbar and show result
      messenger.hideCurrentSnackBar();

      if (result['success'] == true) {
        final items = result[resultKey] as List?;
        final count = items?.length ?? 0;

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              count > 0
                  ? 'Extracted $count $itemName${count > 1 ? 's' : ''} from PDF'
                  : 'No ${itemName}s found in PDF',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: count > 0 ? Colors.green : Colors.orange,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to extract ${itemName}s'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    const accentColor = AppColors.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 14,
              ),
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
                      : accentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedFile != null
                        ? Colors.green.shade300
                        : accentColor.withValues(alpha: 0.3),
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
                          : accentColor.withValues(alpha: 0.6),
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
                            : FontWeight.w500,
                        color: _selectedFile != null
                            ? Colors.green.shade700
                            : accentColor.withValues(alpha: 0.8),
                      ),
                    ),
                    if (_selectedFile != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurface.withValues(alpha: 0.5),
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
                      backgroundColor: AppColors.primary,
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
                        : Text(_extractButtonText),
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
