import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

<<<<<<< HEAD
import 'firebase_options.dart';
import 'screens/families_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Added iOS support so your iOS builds get initialized too!
  final isSupportedPlatform = kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (isSupportedPlatform) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Request permissions and capture user authorization status
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Only fetch the token if permission is granted
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      try {
        final token = await FirebaseMessaging.instance.getToken(
          vapidKey: kIsWeb
              ? 'BJVJQ06DQ1EfLmp139h21lWR7Sjga7o0iNAoIbeeh2BIqEwsVU_xlGIvaXCxGZ4jwzJkeNyqrHNhUkzsMxZRVhM'
              : null,
        );
        debugPrint('FCM TOKEN: $token');
      } catch (e) {
        debugPrint('FCM ERROR fetching token: $e');
      }
    } else {
      debugPrint('FCM Note: User declined push notification permissions.');
    }
  }
=======
import 'screens/splash/splash_screen.dart';
>>>>>>> origin/login

  runApp(const MyApp());
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
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}