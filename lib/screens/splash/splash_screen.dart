import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/families/families_screen.dart';
import 'package:informatik_projekt/screens/login/login_screen.dart';
import 'package:informatik_projekt/screens/family_setup/setup_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController controller;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    controller.forward();
    controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _determineDestination();
      }
    });
  }

  Future<void> _determineDestination() async {
    // 1. Check for valid authentication session
    final bool authenticated = await _apiService.isAuthenticated();

    if (!authenticated) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    // 2. Check if user belongs to any family
    try {
      final families = await _apiService.getFamily();
      if (families.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SetupScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const FamiliesScreen()),
        );
      }
    } catch (e) {
      // On API error, treat as not having a family or needs setup
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const SetupScreen()));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
