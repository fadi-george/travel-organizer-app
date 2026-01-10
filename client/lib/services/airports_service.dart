import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Represents an airport with IATA code
class Airport {
  final String iata;
  final String icao;
  final String name;
  final String city;
  final String country;
  final String? state;
  final double? lat;
  final double? lon;
  final String? tz; // IANA timezone (e.g., "America/Los_Angeles")

  const Airport({
    required this.iata,
    required this.icao,
    required this.name,
    required this.city,
    required this.country,
    this.state,
    this.lat,
    this.lon,
    this.tz,
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
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      tz: json['tz'] as String?,
    );
  }

  /// Create from a list representation (for isolate transfer)
  factory Airport.fromList(List<dynamic> data) {
    return Airport(
      iata: data[0] as String,
      icao: data[1] as String,
      name: data[2] as String,
      city: data[3] as String,
      country: data[4] as String,
      state: data[5] as String?,
      lat: data[6] as double?,
      lon: data[7] as double?,
      tz: data[8] as String?,
    );
  }
}

/// Parse airports JSON in a background isolate
List<List<dynamic>> _parseAirportsJson(String jsonString) {
  final Map<String, dynamic> data = json.decode(jsonString);
  final airports = <List<dynamic>>[];

  for (final entry in data.entries) {
    final airportData = entry.value as Map<String, dynamic>;
    final iata = airportData['iata'] as String?;

    // Only include airports with IATA codes
    if (iata != null && iata.isNotEmpty && iata.length == 3) {
      airports.add([
        iata,
        entry.key,
        airportData['name'] as String? ?? '',
        airportData['city'] as String? ?? '',
        airportData['country'] as String? ?? '',
        airportData['state'] as String?,
        (airportData['lat'] as num?)?.toDouble(),
        (airportData['lon'] as num?)?.toDouble(),
        airportData['tz'] as String?,
      ]);
    }
  }

  // Sort by IATA code
  airports.sort((a, b) => (a[0] as String).compareTo(b[0] as String));
  return airports;
}

/// Service for searching airports
class AirportsService {
  static AirportsService? _instance;
  static List<Airport>? _airports;
  static Map<String, Airport>? _airportsByIata;
  static bool _isLoading = false;

  AirportsService._();

  static AirportsService get instance {
    _instance ??= AirportsService._();
    return _instance!;
  }

  /// Load airports from JSON asset (only airports with IATA codes)
  /// Parsing is done in a background isolate to prevent UI freeze
  Future<void> loadAirports() async {
    if (_airports != null || _isLoading) return;

    _isLoading = true;
    try {
      final jsonString = await rootBundle.loadString('assets/airports.json');

      // Parse in background isolate to prevent UI freeze
      final parsedData = await compute(_parseAirportsJson, jsonString);

      _airports = parsedData.map(Airport.fromList).toList();

      // Build lookup map for fast IATA searches
      _airportsByIata = {for (final a in _airports!) a.iata: a};
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
    _addMatchingAirports(
      results: results,
      limit: limit,
      predicate: (a) => a.iata.toLowerCase().startsWith(q),
    );

    // Third priority: city or name starts with query
    _addMatchingAirports(
      results: results,
      limit: limit,
      predicate: (a) =>
          a.city.toLowerCase().startsWith(q) ||
          a.name.toLowerCase().startsWith(q),
    );

    // Fourth priority: city or name contains query
    _addMatchingAirports(
      results: results,
      limit: limit,
      predicate: (a) =>
          a.city.toLowerCase().contains(q) || a.name.toLowerCase().contains(q),
    );

    return results;
  }

  /// Helper to add matching airports to results until limit is reached
  void _addMatchingAirports({
    required List<Airport> results,
    required int limit,
    required bool Function(Airport) predicate,
  }) {
    if (results.length >= limit) return;
    for (final airport in _airports!) {
      if (predicate(airport) && !results.contains(airport)) {
        results.add(airport);
        if (results.length >= limit) break;
      }
    }
  }

  /// Get airport by IATA code (O(1) lookup)
  Airport? getByIata(String iata) {
    if (_airportsByIata == null) return null;
    return _airportsByIata![iata.toUpperCase()];
  }

  /// Check if airports are loaded
  bool get isLoaded => _airports != null;
}
