import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_places_autocomplete_text_field/google_places_autocomplete_text_field.dart';

/// A reusable address autocomplete field using Google Places API.
class AddressAutocomplete extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final void Function(String address)? onAddressSelected;
  final int minInputLength;
  final int debounceTime;

  const AddressAutocomplete({
    super.key,
    required this.controller,
    this.label = 'Address',
    this.hint = 'Search for an address',
    this.validator,
    this.onAddressSelected,
    this.minInputLength = 2,
    this.debounceTime = 400,
  });

  @override
  Widget build(BuildContext context) {
    final apiKey = dotenv.env['GOOGLE_PLACES_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      // Fallback to regular text field if no API key
      return TextFormField(
        controller: controller,
        decoration: _buildDecoration(context),
        validator: validator,
      );
    }

    return GooglePlacesAutoCompleteTextFormField(
      textEditingController: controller,
      config: GoogleApiConfig(
        apiKey: apiKey,
        debounceTime: debounceTime,
      ),
      minInputLength: minInputLength,
      decoration: _buildDecoration(context),
      validator: validator,
      overlayContainerBuilder: (child) => Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: child,
        ),
      ),
      onSuggestionClicked: (prediction) {
        final address = prediction.description ?? '';
        controller.text = address;
        controller.selection = TextSelection.fromPosition(
          TextPosition(offset: controller.text.length),
        );
        onAddressSelected?.call(address);
      },
    );
  }

  InputDecoration _buildDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
      filled: true,
      fillColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

