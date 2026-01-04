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

  // Load environment: production for release builds or ENV=prod override
  final useProd = kReleaseMode || const String.fromEnvironment('ENV') == 'prod';
  final envFile = useProd ? '.env.prod' : '.env.local';

  debugPrint(
    'Loading ${useProd ? 'production' : 'development'} environment ($envFile)',
  );
  await dotenv
      .load(fileName: envFile)
      .catchError((e) => debugPrint('Error loading $envFile: $e'));

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
    return ClerkAuth(
      config: ClerkAuthConfig(
        publishableKey: AuthService.instance.publishableKey!,
      ),
      child: _buildMaterialApp(child: const AuthWrapper()),
    );
  }

  MaterialApp _buildMaterialApp({required Widget child}) {
    return MaterialApp(
      title: 'Travel Organizer',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: child,
    );
  }

  ThemeData _buildTheme(Brightness brightness) => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFFFF7043),
      brightness: brightness,
    ),
    useMaterial3: true,
    fontFamily: 'SF Pro Display',
  );
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  (bool, String?) _lastSyncState = (false, null);

  @override
  Widget build(BuildContext context) {
    return ClerkAuthBuilder(
      builder: (context, authState) {
        _syncAuthState(authState);

        // Loading during initial Clerk initialization
        if (authState.isNotAvailable && authState.user == null) {
          return const _LoadingScreen();
        }

        return authState.isSignedIn ? const TripsScreen() : const LoginScreen();
      },
    );
  }

  void _syncAuthState(ClerkAuthState authState) {
    final user = authState.user;
    final currentState = (authState.isSignedIn, user?.id);

    if (currentState == _lastSyncState) return;
    _lastSyncState = currentState;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (authState.isSignedIn) {
        String? token;
        try {
          token = (await authState.sessionToken(templateName: 'convex')).jwt;
        } catch (_) {
          token = authState.session?.lastActiveToken?.jwt;
        }

        AuthService.instance.onAuthStateChanged(
          isSignedIn: true,
          userId: user?.id,
          email: user?.email,
          name: [user?.firstName, user?.lastName].whereType<String>().join(' '),
          imageUrl: user?.imageUrl,
          sessionToken: token,
        );
      } else if (!authState.isNotAvailable) {
        AuthService.instance.onAuthStateChanged(isSignedIn: false);
      }
    });
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
