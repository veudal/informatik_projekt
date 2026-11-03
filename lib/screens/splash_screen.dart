import 'dart:async';
import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/family/families_screen.dart';
import 'package:informatik_projekt/screens/auth/login/login_screen.dart';
import 'package:informatik_projekt/screens/family/setup_screen.dart';
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
  Timer? _retryTimer;
  DateTime? _firstErrorTime;
  bool _snackbarShowing = false;

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
    // 1. Check for valid authentication session (Reads from secure storage, no API call)
    final bool authenticated = await _apiService.isAuthenticated();

    if (!authenticated) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
      return;
    }

    // 2. Check if user belongs to any family
    try {
      final families = await _apiService.getFamily();
      
      // Reset error tracking on success
      _firstErrorTime = null;
      _snackbarShowing = false;
      _retryTimer?.cancel();

      if (mounted) {
        if (families.isEmpty) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const SetupScreen()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const FamiliesScreen()),
          );
        }
      }
    } catch (e) {
      // Server or Network Error
      _handleNetworkError();
    }
  }

  void _handleNetworkError() {
    final now = DateTime.now();
    if (_firstErrorTime == null) {
      _firstErrorTime = now;
    }

    // Show snackbar after 5 seconds of continuous errors
    if (now.difference(_firstErrorTime!) >= const Duration(seconds: 5) && !_snackbarShowing) {
      _showErrorSnackbar();
    }

    // Retry after 3 seconds
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _determineDestination();
      }
    });
  }

  void _showErrorSnackbar() {
    _snackbarShowing = true;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Bitte prüfen Sie Ihre Internetverbindung oder warten Sie, bis die Serverwartung abgeschlossen ist.',
          textAlign: TextAlign.center,
        ),
        duration: Duration(seconds: 4),
      ),
    );

    // Allow snackbar to be shown again after some time if error persists
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        _snackbarShowing = false;
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    _retryTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

