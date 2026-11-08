import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/auth/login/login_screen.dart';
import 'package:informatik_projekt/screens/splash_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/widgets/create_family_button.dart';
import 'package:informatik_projekt/widgets/join_family_button.dart';
import 'package:informatik_projekt/screens/family/qr_scanner_screen.dart';

import 'create_family_screen.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  Future<void> _openQrScanner(BuildContext context) async {
    if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
      final String? familyId = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
      );

      if (familyId != null) {
        // TODO: Implement joining logic
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plattform is not supporting QR scanning.'),
        ),
      );
    }
  }

  Future<void> _logout(BuildContext context) async {
    ApiService apiService = ApiService();
    await apiService.logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen()
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Get Started')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.family_restroom, size: 80, color: Colors.indigo),
              const SizedBox(height: 24),
              const Text(
                'Welcome to Spargel!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'To get started, you need to be part of a family. You can create a new one or join an existing one.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              JoinFamilyButton(onPressed: () => _openQrScanner(context)),
              const SizedBox(height: 16),
              CreateFamilyButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateFamilyScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'Log out',
                      style: TextStyle(color: Colors.blue),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          _logout(context);
                        },
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
