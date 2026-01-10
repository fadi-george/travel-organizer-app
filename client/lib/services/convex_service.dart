import 'dart:convert';
import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Singleton service for managing the Convex client connection.
class ConvexService {
  static ConvexService? _instance;
  static ConvexClient? _client;

  ConvexService._();

  static Future<ConvexService> getInstance() async {
    if (_instance == null) {
      _instance = ConvexService._();
      await _instance!._initialize();
    }
    return _instance!;
  }

  Future<void> _initialize() async {
    final deploymentUrl = dotenv.env['CONVEX_URL'];
    if (deploymentUrl == null || deploymentUrl.isEmpty) {
      throw StateError(
        'CONVEX_URL not found in .env file. '
        'Create a .env file in the client/ folder with your Convex deployment URL.',
      );
    }

    _client = await ConvexClient.init(
      deploymentUrl: deploymentUrl,
      clientId: 'travel-organizer-flutter',
    );
  }

  ConvexClient get client {
    if (_client == null) {
      throw StateError(
        'ConvexService not initialized. Call getInstance() first.',
      );
    }
    return _client!;
  }

  /// Decode JSON result to a Map, returns null if result is null
  Map<String, dynamic>? _decodeAsMap(String result) {
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Query trips from Convex
  Future<List<Map<String, dynamic>>> getTrips() async {
    final result = await client.query('trips:list', {});
    final decoded = jsonDecode(result);
    if (decoded == null) return [];

    final List<dynamic> trips = decoded as List<dynamic>;
    return trips.map((t) => Map<String, dynamic>.from(t as Map)).toList();
  }

  /// Create a new trip
  Future<Map<String, dynamic>?> createTrip({
    required String name,
    required String startDate,
    required String endDate,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'trips:create',
      args: {
        'name': name,
        'startDate': startDate,
        'endDate': endDate,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Subscribe to trips updates for real-time sync
  Future<SubscriptionHandle> subscribeToTrips({
    required void Function(List<Map<String, dynamic>> trips) onUpdate,
    required void Function(String message, String? value) onError,
  }) async {
    return client.subscribe(
      name: 'trips:list',
      args: {},
      onUpdate: (value) {
        final decoded = jsonDecode(value);
        if (decoded == null) {
          onUpdate([]);
          return;
        }
        final List<dynamic> trips = decoded as List<dynamic>;
        onUpdate(
          trips.map((t) => Map<String, dynamic>.from(t as Map)).toList(),
        );
      },
      onError: onError,
    );
  }

  /// Update an existing trip
  Future<Map<String, dynamic>?> updateTrip({
    required String id,
    String? name,
    String? startDate,
    String? endDate,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'trips:update',
      args: {
        'id': id,
        if (name != null) 'name': name,
        if (startDate != null) 'startDate': startDate,
        if (endDate != null) 'endDate': endDate,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    await client.mutation(name: 'trips:remove', args: {'id': tripId});
  }

  /// Extract flights from PDF using Claude AI
  Future<Map<String, dynamic>> extractFlightsFromPdf({
    required String tripId,
    required String pdfBase64,
  }) async {
    final result = await client.action(
      name: 'flightExtractor:extractFlightsFromPdf',
      args: {'tripId': tripId, 'pdfBase64': pdfBase64},
    );
    final decoded = jsonDecode(result);
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Create a new flight
  Future<Map<String, dynamic>?> createFlight({
    required String tripId,
    required String flightNumber,
    required String airline,
    required String departureAirportCode,
    required String arrivalAirportCode,
    required String departureDate,
    String? departureTime,
    String? arrivalDate,
    String? arrivalTime,
    String? confirmationNumber,
    String? seatNumber,
    String? cabinClass,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'flights:create',
      args: {
        'tripId': tripId,
        'flightNumber': flightNumber,
        'airline': airline,
        'departureAirportCode': departureAirportCode,
        'arrivalAirportCode': arrivalAirportCode,
        'departureDate': departureDate,
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalDate != null) 'arrivalDate': arrivalDate,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (seatNumber != null) 'seatNumber': seatNumber,
        if (cabinClass != null) 'cabinClass': cabinClass,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  Future<void> deleteFlight(String id) async {
    await client.mutation(name: 'flights:remove', args: {'id': id});
  }

  Future<Map<String, dynamic>?> updateFlight({
    required String id,
    String? flightNumber,
    String? airline,
    String? departureAirportCode,
    String? arrivalAirportCode,
    String? departureDate,
    String? departureTime,
    String? arrivalDate,
    String? arrivalTime,
    String? confirmationNumber,
    String? seatNumber,
    String? cabinClass,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'flights:update',
      args: {
        'id': id,
        if (flightNumber != null) 'flightNumber': flightNumber,
        if (airline != null) 'airline': airline,
        if (departureAirportCode != null)
          'departureAirportCode': departureAirportCode,
        if (arrivalAirportCode != null)
          'arrivalAirportCode': arrivalAirportCode,
        if (departureDate != null) 'departureDate': departureDate,
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalDate != null) 'arrivalDate': arrivalDate,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (seatNumber != null) 'seatNumber': seatNumber,
        if (cabinClass != null) 'cabinClass': cabinClass,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Create a new accommodation
  Future<Map<String, dynamic>?> createAccommodation({
    required String tripId,
    required String hotelName,
    String? roomType,
    String? checkIn,
    String? checkInTime,
    String? checkOut,
    String? checkOutTime,
    String? address,
    String? confirmationNumber,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'accommodations:create',
      args: {
        'tripId': tripId,
        'hotelName': hotelName,
        if (roomType != null) 'roomType': roomType,
        if (checkIn != null) 'checkIn': checkIn,
        if (checkInTime != null) 'checkInTime': checkInTime,
        if (checkOut != null) 'checkOut': checkOut,
        if (checkOutTime != null) 'checkOutTime': checkOutTime,
        if (address != null) 'address': address,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Update an accommodation
  Future<Map<String, dynamic>?> updateAccommodation({
    required String id,
    String? hotelName,
    String? roomType,
    String? checkIn,
    String? checkInTime,
    String? checkOut,
    String? checkOutTime,
    String? address,
    String? confirmationNumber,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'accommodations:update',
      args: {
        'id': id,
        if (hotelName != null) 'hotelName': hotelName,
        if (roomType != null) 'roomType': roomType,
        if (checkIn != null) 'checkIn': checkIn,
        if (checkInTime != null) 'checkInTime': checkInTime,
        if (checkOut != null) 'checkOut': checkOut,
        if (checkOutTime != null) 'checkOutTime': checkOutTime,
        if (address != null) 'address': address,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Delete an accommodation
  Future<void> deleteAccommodation(String id) async {
    await client.mutation(name: 'accommodations:remove', args: {'id': id});
  }

  /// Extract accommodations from PDF using Claude AI
  Future<Map<String, dynamic>> extractAccommodationsFromPdf({
    required String tripId,
    required String pdfBase64,
  }) async {
    final result = await client.action(
      name: 'accommodationExtractor:extractAccommodationsFromPdf',
      args: {'tripId': tripId, 'pdfBase64': pdfBase64},
    );
    final decoded = jsonDecode(result);
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Extract activities from PDF using Claude AI
  Future<Map<String, dynamic>> extractActivitiesFromPdf({
    required String tripId,
    required String pdfBase64,
  }) async {
    final result = await client.action(
      name: 'activityExtractor:extractActivitiesFromPdf',
      args: {'tripId': tripId, 'pdfBase64': pdfBase64},
    );
    final decoded = jsonDecode(result);
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Create a new activity
  Future<Map<String, dynamic>?> createActivity({
    required String tripId,
    required String date,
    required String title,
    String? time,
    String? location,
    String? type,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'activities:create',
      args: {
        'tripId': tripId,
        'date': date,
        'title': title,
        if (time != null) 'time': time,
        if (location != null) 'location': location,
        if (type != null) 'type': type,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Update an activity
  Future<Map<String, dynamic>?> updateActivity({
    required String id,
    String? date,
    String? time,
    String? title,
    String? location,
    String? type,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'activities:update',
      args: {
        'id': id,
        if (date != null) 'date': date,
        if (time != null) 'time': time,
        if (title != null) 'title': title,
        if (location != null) 'location': location,
        if (type != null) 'type': type,
        if (notes != null) 'notes': notes,
      },
    );
    return _decodeAsMap(result);
  }

  /// Delete an activity
  Future<void> deleteActivity(String id) async {
    await client.mutation(name: 'activities:remove', args: {'id': id});
  }

  /// Get weather data from server-side cache
  /// Returns hourly weather data for the given location and date
  /// The server caches responses to reduce API calls across all users
  Future<List<Map<String, dynamic>>?> getWeather({
    required double lat,
    required double lng,
    required String date,
  }) async {
    try {
      final result = await client.action(
        name: 'weather:getWeather',
        args: {'lat': lat, 'lng': lng, 'date': date},
      );
      final decoded = jsonDecode(result);
      if (decoded == null) return null;
      final List<dynamic> weatherList = decoded as List<dynamic>;
      return weatherList
          .map((w) => Map<String, dynamic>.from(w as Map))
          .toList();
    } catch (e) {
      debugPrint('ConvexService.getWeather error: $e');
      return null;
    }
  }

  /// Refresh flight status from AeroAPI
  /// Returns updated status and gate info, or null if unavailable
  Future<Map<String, dynamic>?> refreshFlightStatus({
    required String flightId,
  }) async {
    try {
      final result = await client.action(
        name: 'flightStatus:refreshFlightStatus',
        args: {'flightId': flightId},
      );
      return _decodeAsMap(result);
    } catch (e) {
      debugPrint('ConvexService.refreshFlightStatus error: $e');
      return null;
    }
  }

  /// Check if a flight should auto-refresh based on departure time
  /// Returns true if flight is within 24 hours and status is stale (>15 min)
  static bool shouldAutoRefreshFlight(Map<String, dynamic> flight) {
    final departureDateStr = flight['departureDate'] as String?;
    final departureTimeStr = flight['departureTime'] as String?;
    final statusLastUpdatedRaw = flight['statusLastUpdated'];
    final statusLastUpdated = statusLastUpdatedRaw != null
        ? (statusLastUpdatedRaw as num).toInt()
        : null;

    if (departureDateStr == null) return false;

    // Parse departure datetime
    DateTime departureDateTime;
    try {
      if (departureTimeStr != null) {
        departureDateTime = DateTime.parse(
          '${departureDateStr}T$departureTimeStr',
        );
      } else {
        departureDateTime = DateTime.parse(departureDateStr);
      }
    } catch (e) {
      return false;
    }

    final now = DateTime.now();
    final hoursUntilDeparture = departureDateTime.difference(now).inHours;

    // Only auto-refresh for flights within 24 hours (and not already departed long ago)
    if (hoursUntilDeparture > 24 || hoursUntilDeparture < -6) {
      return false;
    }

    // Check if status is stale (null or older than 15 minutes)
    if (statusLastUpdated == null) {
      return true;
    }

    final lastUpdated = DateTime.fromMillisecondsSinceEpoch(statusLastUpdated);
    final minutesSinceUpdate = now.difference(lastUpdated).inMinutes;

    return minutesSinceUpdate >= 15;
  }
}
