import 'package:flutter/material.dart';
import '../services/airports_service.dart';

/// A text field that autocompletes airport names from a local JSON database.
/// Returns the IATA airport code when an airport is selected.
class AirportAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool isDeparture;
  final String? Function(String?)? validator;
  final void Function(String airportCode, String airportName)?
  onAirportSelected;

  const AirportAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    this.hint = 'Search airports',
    this.isDeparture = true,
    this.validator,
    this.onAirportSelected,
  });

  @override
  State<AirportAutocomplete> createState() => _AirportAutocompleteState();
}

class _AirportAutocompleteState extends State<AirportAutocomplete> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<Airport> _suggestions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Airports are preloaded in TripsScreen, so we're ready immediately
    _isLoading = false;
    _focusNode.addListener(_onFocusChange);

    // If there's already a value, show it
    if (widget.controller.text.isNotEmpty) {
      _searchController.text = widget.controller.text;
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _removeOverlay();
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    _removeOverlay();
    if (_suggestions.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final airport = _suggestions[index];
                    return ListTile(
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFFF7043,
                          ).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          airport.iata,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7043),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        airport.name,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${airport.city}, ${airport.country}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      onTap: () => _selectAirport(airport),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectAirport(Airport airport) {
    widget.controller.text = airport.iata;
    _searchController.text = airport.iata;
    widget.onAirportSelected?.call(airport.iata, airport.displayNameWithCity);
    _removeOverlay();
    _focusNode.unfocus();
  }

  void _onSearchChanged(String value) {
    // Update main controller for manual entry
    widget.controller.text = value.toUpperCase();

    if (value.length < 2) {
      _suggestions = [];
      _removeOverlay();
      return;
    }

    _suggestions = AirportsService.instance.search(value, limit: 8);
    if (_suggestions.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: _searchController,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: _isLoading ? 'Loading...' : widget.hint,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(
            widget.isDeparture ? Icons.flight_takeoff : Icons.flight_land,
            size: 20,
          ),
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
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        textCapitalization: TextCapitalization.characters,
        enabled: !_isLoading,
        validator: (_) => widget.validator?.call(widget.controller.text),
        onChanged: _onSearchChanged,
      ),
    );
  }
}
