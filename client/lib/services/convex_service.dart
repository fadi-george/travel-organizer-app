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
}
