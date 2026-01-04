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

  const AuthUser({required this.id, this.email, this.name, this.imageUrl});
}

/// Singleton service for managing authentication and syncing with Convex.
class AuthService extends ChangeNotifier {
  static AuthService? _instance;

  AuthState _state = AuthState.loading;
  AuthUser? _user;
  String? _error;
  String? _publishableKey;
  String? _currentToken;
  bool _signInInProgress = false;

  AuthService._();

  static AuthService get instance => _instance ??= AuthService._();

  // Auth state
  AuthState get state => _state;
  AuthUser? get user => _user;
  String? get error => _error;
  String? get currentToken => _currentToken;
  String? get publishableKey => _publishableKey;

  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get isClerkConfigured => _publishableKey?.isNotEmpty ?? false;

  /// Whether sign-in is in progress (persists through OAuth redirect)
  bool get signInInProgress => _signInInProgress;
  set signInInProgress(bool value) {
    _signInInProgress = value;
    notifyListeners();
  }

  /// Initialize authentication
  Future<void> initialize() async {
    _publishableKey = dotenv.env['CLERK_PUBLISHABLE_KEY'];
    _state = AuthState.unauthenticated;
    notifyListeners();
  }

  /// Called when auth state changes (from Clerk)
  Future<void> onAuthStateChanged({
    required bool isSignedIn,
    String? userId,
    String? email,
    String? name,
    String? imageUrl,
    String? sessionToken,
  }) async {
    _signInInProgress = false;

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

      if (sessionToken?.isNotEmpty ?? false) {
        await _syncTokenToConvex(sessionToken);
        await _storeUserInConvex();
      }
    } else {
      _user = null;
      _state = AuthState.unauthenticated;
      _currentToken = null;
      await _syncTokenToConvex(null);
    }

    notifyListeners();
  }

  /// Sign out the current user
  Future<void> signOut() async {
    _error = null;
    _user = null;
    _state = AuthState.unauthenticated;
    _currentToken = null;
    await _syncTokenToConvex(null);
    notifyListeners();
  }

  Future<void> _syncTokenToConvex(String? token) async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.client.setAuth(token: token);
    } catch (e) {
      debugPrint('Error syncing token to Convex: $e');
    }
  }

  Future<void> _storeUserInConvex() async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.client.mutation(name: 'users:store', args: {});
    } catch (e) {
      debugPrint('Error storing user in Convex: $e');
    }
  }
}
