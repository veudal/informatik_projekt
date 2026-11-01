import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/splash/splash_screen.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final isSupportedPlatform = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (isSupportedPlatform) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  runApp(const MyApp());

  // Not awaited, so it doesn't block the UI
  if (isSupportedPlatform) _setupPushNotifications();
}

Future<void> _setupPushNotifications() async {
  try {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? 'BJVJQ06DQ1EfLmp139h21lWR7Sjga7o0iNAoIbeeh2BIqEwsVU_xlGIvaXCxGZ4jwzJkeNyqrHNhUkzsMxZRVhM' : null,
      );
      debugPrint('FCM TOKEN: $token');
    } else {
      debugPrint('FCM: user declined push permissions.');
    }
  } catch (e) {
    debugPrint('FCM error: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override

  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance & Chores',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        fontFamily: GoogleFonts.getFont('Plus Jakarta Sans').fontFamily
        // Alternative font: 'Inter'
      ),

      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
