import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/trips_screen.dart';

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
      home: const TripsScreen(),
    );
  }
}
