import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'convex_service.dart';

/// Authentication state enum
enum AuthState { loading, authenticated, unauthenticated }

/// User information model
class AuthUser {
  final String id;
  final String? email;
  final String? name;
  final String? imageUrl;

  const AuthUser({
    required this.id,
    this.email,
    this.name,
    this.imageUrl,
  });
}

/// Singleton service for managing authentication and syncing with Convex.
///
/// This service manages auth state and syncs JWT tokens with the Convex client.
/// When ready to integrate Clerk:
/// 1. Uncomment clerk_flutter in pubspec.yaml
/// 2. Wrap your app with ClerkAuth widget
/// 3. Call onAuthStateChanged from ClerkAuthBuilder
class AuthService extends ChangeNotifier {
  static AuthService? _instance;

  AuthState _state = AuthState.loading;
  AuthUser? _user;
  String? _error;
  String? _publishableKey;
  String? _currentToken;

  AuthService._();

  /// Get the singleton instance
  static AuthService get instance {
    _instance ??= AuthService._();
    return _instance!;
  }

  /// Current authentication state
  AuthState get state => _state;

  /// Current authenticated user (null if not authenticated)
  AuthUser? get user => _user;

  /// Whether the user is authenticated
  bool get isAuthenticated => _state == AuthState.authenticated;

  /// Whether auth is still loading
  bool get isLoading => _state == AuthState.loading;

  /// Last error message (null if no error)
  String? get error => _error;

  /// Get the Clerk publishable key
  String? get publishableKey => _publishableKey;

  /// Check if Clerk is configured
  bool get isClerkConfigured =>
      _publishableKey != null && _publishableKey!.isNotEmpty;

  /// Initialize authentication
  Future<void> initialize() async {
    try {
      _publishableKey = dotenv.env['CLERK_PUBLISHABLE_KEY'];
      if (_publishableKey == null || _publishableKey!.isEmpty) {
        debugPrint(
          'CLERK_PUBLISHABLE_KEY not found in .env file. '
          'Add your Clerk publishable key to enable authentication.',
        );
      }

      // Set initial state to unauthenticated
      _state = AuthState.unauthenticated;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _state = AuthState.unauthenticated;
      notifyListeners();
      debugPrint('AuthService initialization error: $e');
    }
  }

  /// Called when auth state changes (from external auth provider)
  Future<void> onAuthStateChanged({
    required bool isSignedIn,
    String? userId,
    String? email,
    String? name,
    String? imageUrl,
    String? sessionToken,
  }) async {
    if (isSignedIn && userId != null) {
      _user = AuthUser(
        id: userId,
        email: email,
        name: name,
        imageUrl: imageUrl,
      );
      _state = AuthState.authenticated;
      _error = null;
      _currentToken = sessionToken;

      // Sync token to Convex
      await _syncTokenToConvex(sessionToken);

      // Store/update user in Convex database
      await _storeUserInConvex();
    } else {
      _user = null;
      _state = AuthState.unauthenticated;
      _currentToken = null;
      await _syncTokenToConvex(null);
    }

    notifyListeners();
  }

  /// Directly set the auth token (for testing or custom auth flows)
  Future<void> setAuthToken(String? token, {AuthUser? user}) async {
    _currentToken = token;
    _user = user;
    _state = token != null ? AuthState.authenticated : AuthState.unauthenticated;
    await _syncTokenToConvex(token);
    if (token != null) {
      await _storeUserInConvex();
    }
    notifyListeners();
  }

  /// Sync the JWT token to the Convex client
  Future<void> _syncTokenToConvex(String? token) async {
    try {
      final convexService = await ConvexService.getInstance();
      convexService.client.setAuth(token: token);
    } catch (e) {
      debugPrint('Error syncing token to Convex: $e');
    }
  }

  /// Store or update the user in the Convex database
  Future<void> _storeUserInConvex() async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.client.mutation(name: 'users:store', args: {});
    } catch (e) {
      debugPrint('Error storing user in Convex: $e');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      _error = null;
      _user = null;
      _state = AuthState.unauthenticated;
      _currentToken = null;
      await _syncTokenToConvex(null);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      debugPrint('Sign out error: $e');
    }
  }

  /// Get the current token (for debugging/testing)
  String? get currentToken => _currentToken;
}
