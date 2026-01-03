import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/login_screen.dart';
import 'screens/trips_screen.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables based on build mode
  // - Release builds: .env (production)
  // - Debug/Profile builds: .env.local (development)
  await dotenv.load(fileName: '.env');
  if (!kReleaseMode) {
    await dotenv.load(fileName: '.env.local').catchError((error) {
      debugPrint('Error loading .env.local: $error');
    });
  }

  // Initialize authentication service
  await AuthService.instance.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TravelOrganizerApp());
}

class TravelOrganizerApp extends StatelessWidget {
  const TravelOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final publishableKey = AuthService.instance.publishableKey;

    // If no Clerk key is configured, show the app without auth
    if (publishableKey == null || publishableKey.isEmpty) {
      return _buildMaterialApp(child: const TripsScreen());
    }

    // Wrap with Clerk authentication
    return ClerkAuth(
      config: ClerkAuthConfig(publishableKey: publishableKey),
      child: _buildMaterialApp(child: const AuthWrapper()),
    );
  }

  MaterialApp _buildMaterialApp({required Widget child}) {
    return MaterialApp(
      title: 'Travel Organizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7043),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7043),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Display',
      ),
      themeMode: ThemeMode.system,
      home: child,
    );
  }
}

/// Widget that wraps the app with authentication state
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _lastSyncedUserId;
  String? _lastSyncedToken;
  bool _lastSyncedSignedIn = false;

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      builder: (context, authState) {
        // Sync auth state with our AuthService (only when state changes)
        _syncAuthState(context, authState);

        // Show loading only during initial Clerk initialization
        if (authState.isNotAvailable && authState.user == null) {
          return const _LoadingScreen();
        }

        // Show sign-in screen if not authenticated
        if (!authState.isSignedIn) {
          return const LoginScreen();
        }

        // Show main app if authenticated
        return const TripsScreen();
      },
    );
  }

  void _syncAuthState(BuildContext context, ClerkAuthState authState) {
    final user = authState.user;
    final isSignedIn = authState.isSignedIn;
    final session = authState.session;

    // Get token from session's lastActiveToken
    final token = session?.lastActiveToken?.jwt;

    // Debug: log session details
    if (isSignedIn && session != null) {
      debugPrint(
        'Session details: id=${session.id}, '
        'lastActiveToken=${session.lastActiveToken}, '
        'status=${session.status}',
      );
    }

    // Only sync if state has actually changed
    final stateChanged =
        isSignedIn != _lastSyncedSignedIn ||
        user?.id != _lastSyncedUserId ||
        token != _lastSyncedToken;

    if (!stateChanged) return;

    // Update tracking variables
    _lastSyncedSignedIn = isSignedIn;
    _lastSyncedUserId = user?.id;
    _lastSyncedToken = token;

    debugPrint(
      'Auth state changed: isSignedIn=$isSignedIn, '
      'user=${user?.id}, '
      'token=${token != null ? 'present (${token.length} chars)' : 'null'}',
    );

    // Schedule the sync after the current frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      if (isSignedIn) {
        AuthService.instance.onAuthStateChanged(
          isSignedIn: true,
          userId: user?.id,
          email: user?.email,
          name: '${user?.firstName ?? ''} ${user?.lastName ?? ''}'.trim(),
          imageUrl: user?.imageUrl,
          sessionToken: token,
        );
      } else if (!authState.isNotAvailable) {
        AuthService.instance.onAuthStateChanged(isSignedIn: false);
      }
    });
  }
}

/// Loading screen shown while authentication is initializing
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.flight_takeoff_rounded,
              size: 64,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Travel Organizer',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
