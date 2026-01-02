import 'dart:convert';
import 'package:convex_flutter/convex_flutter.dart';
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
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
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
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
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
    required String departureCity,
    required String arrivalCity,
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
        'departureCity': departureCity,
        'arrivalCity': arrivalCity,
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
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> deleteFlight(String id) async {
    await client.mutation(name: 'flights:remove', args: {'id': id});
  }

  Future<Map<String, dynamic>?> updateFlight({
    required String id,
    String? flightNumber,
    String? airline,
    String? departureCity,
    String? arrivalCity,
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
        if (departureCity != null) 'departureCity': departureCity,
        if (arrivalCity != null) 'arrivalCity': arrivalCity,
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
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Create a new accommodation
  Future<Map<String, dynamic>?> createAccommodation({
    required String tripId,
    required String hotelName,
    String? city,
    String? country,
    String? roomType,
    String? checkIn,
    String? checkOut,
    String? address,
    String? confirmationNumber,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'accommodations:create',
      args: {
        'tripId': tripId,
        'hotelName': hotelName,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (roomType != null) 'roomType': roomType,
        if (checkIn != null) 'checkIn': checkIn,
        if (checkOut != null) 'checkOut': checkOut,
        if (address != null) 'address': address,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (notes != null) 'notes': notes,
      },
    );
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
  }

  /// Update an accommodation
  Future<Map<String, dynamic>?> updateAccommodation({
    required String id,
    String? hotelName,
    String? city,
    String? country,
    String? roomType,
    String? checkIn,
    String? checkOut,
    String? address,
    String? confirmationNumber,
    String? notes,
  }) async {
    final result = await client.mutation(
      name: 'accommodations:update',
      args: {
        'id': id,
        if (hotelName != null) 'hotelName': hotelName,
        if (city != null) 'city': city,
        if (country != null) 'country': country,
        if (roomType != null) 'roomType': roomType,
        if (checkIn != null) 'checkIn': checkIn,
        if (checkOut != null) 'checkOut': checkOut,
        if (address != null) 'address': address,
        if (confirmationNumber != null)
          'confirmationNumber': confirmationNumber,
        if (notes != null) 'notes': notes,
      },
    );
    final decoded = jsonDecode(result);
    if (decoded == null) return null;
    return Map<String, dynamic>.from(decoded as Map);
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
}
