import 'dart:async';

import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/auth/login/login_screen.dart';
import 'package:informatik_projekt/screens/family/setup_screen.dart';
import 'package:informatik_projekt/screens/main_navigation.dart';
import 'package:informatik_projekt/services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

enum _Destination { login, setup, mainNavigation }

class _SplashScreenState extends State<SplashScreen> {
  final ApiService _apiService = ApiService();
  late Future<_Destination> destinationFuture;

  @override
  void initState() {
    super.initState();
    destinationFuture = _determineDestination();
  }

  Future<_Destination> _determineDestination() async {
    final bool authenticated = await _apiService.isAuthenticated();

    if (!authenticated) {
      return _Destination.login;
    }

    try {
      final families = await _apiService.getFamily();

      if (families == null) {
        return _Destination.setup;
      } else {
        return _Destination.mainNavigation;
      }
    } on SessionExpiredException {
      return _Destination.login;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder(
        future: destinationFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasData) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  switch (snapshot.data) {
                    case _Destination.login:
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                      break;
                    case _Destination.setup:
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const SetupScreen()),
                      );
                      break;
                    case _Destination.mainNavigation:
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => const MainNavigation(),
                        ),
                      );
                      break;
                    case null:
                  }
                }
              });
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 48,
                  children: [
                    Icon(Icons.wifi_off, size: 48),
                    Text(
                      'Bitte prüfen Sie Ihre Internetverbindung oder warten Sie, bis die Serverwartung abgeschlossen ist.',
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          destinationFuture = Future.delayed(
                            Duration(milliseconds: 250),
                          ).then((_) => _determineDestination());
                        });
                      },
                      icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                      label: const Text(
                        'Refresh',
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueGrey,
                        side: const BorderSide(color: Colors.blueGrey),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          }

          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
