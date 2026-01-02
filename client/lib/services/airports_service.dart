import 'dart:convert';
import 'package:flutter/services.dart';

/// Represents an airport with IATA code
class Airport {
  final String iata;
  final String icao;
  final String name;
  final String city;
  final String country;
  final String? state;

  const Airport({
    required this.iata,
    required this.icao,
    required this.name,
    required this.city,
    required this.country,
    this.state,
  });

  /// Display format: "LAX - Los Angeles International"
  String get displayName => '$iata - $name';

  /// Display with city: "LAX - Los Angeles International (Los Angeles, US)"
  String get displayNameWithCity => '$iata - $name ($city, $country)';

  factory Airport.fromJson(String icaoCode, Map<String, dynamic> json) {
    return Airport(
      iata: json['iata'] as String,
      icao: icaoCode,
      name: json['name'] as String? ?? '',
      city: json['city'] as String? ?? '',
      country: json['country'] as String? ?? '',
      state: json['state'] as String?,
    );
  }
}

/// Service for searching airports
class AirportsService {
  static AirportsService? _instance;
  static List<Airport>? _airports;
  static bool _isLoading = false;

  AirportsService._();

  static AirportsService get instance {
    _instance ??= AirportsService._();
    return _instance!;
  }

  /// Load airports from JSON asset (only airports with IATA codes)
  Future<void> loadAirports() async {
    if (_airports != null || _isLoading) return;

    _isLoading = true;
    try {
      final jsonString = await rootBundle.loadString('assets/airports.json');
      final Map<String, dynamic> data = json.decode(jsonString);

      _airports = [];
      for (final entry in data.entries) {
        final airportData = entry.value as Map<String, dynamic>;
        final iata = airportData['iata'] as String?;

        // Only include airports with IATA codes
        if (iata != null && iata.isNotEmpty && iata.length == 3) {
          _airports!.add(Airport.fromJson(entry.key, airportData));
        }
      }

      // Sort by IATA code for consistent results
      _airports!.sort((a, b) => a.iata.compareTo(b.iata));
    } finally {
      _isLoading = false;
    }
  }

  /// Search airports by IATA code, name, or city
  List<Airport> search(String query, {int limit = 10}) {
    if (_airports == null || query.isEmpty) return [];

    final q = query.toLowerCase().trim();
    final results = <Airport>[];

    // First priority: exact IATA match
    for (final airport in _airports!) {
      if (airport.iata.toLowerCase() == q) {
        results.add(airport);
        break;
      }
    }

    // Second priority: IATA starts with query
    if (results.length < limit) {
      for (final airport in _airports!) {
        if (airport.iata.toLowerCase().startsWith(q) &&
            !results.contains(airport)) {
          results.add(airport);
          if (results.length >= limit) break;
        }
      }
    }

    // Third priority: city or name starts with query
    if (results.length < limit) {
      for (final airport in _airports!) {
        if ((airport.city.toLowerCase().startsWith(q) ||
                airport.name.toLowerCase().startsWith(q)) &&
            !results.contains(airport)) {
          results.add(airport);
          if (results.length >= limit) break;
        }
      }
    }

    // Fourth priority: city or name contains query
    if (results.length < limit) {
      for (final airport in _airports!) {
        if ((airport.city.toLowerCase().contains(q) ||
                airport.name.toLowerCase().contains(q)) &&
            !results.contains(airport)) {
          results.add(airport);
          if (results.length >= limit) break;
        }
      }
    }

    return results;
  }

  /// Get airport by IATA code
  Airport? getByIata(String iata) {
    if (_airports == null) return null;
    final code = iata.toUpperCase();
    try {
      return _airports!.firstWhere((a) => a.iata == code);
    } catch (_) {
      return null;
    }
  }

  /// Check if airports are loaded
  bool get isLoaded => _airports != null;
}
