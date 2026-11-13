import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/auth/login/login_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/widgets/family_setup_button.dart';
import 'package:informatik_projekt/screens/family/qr_scanner_screen.dart';
import 'package:informatik_projekt/widgets/logout_button.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Starte dein Familienleben')),
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
                'Um anzufangen musst du Teil einer Familie sein. Du kannst eine Familie erstellen oder einer bereits bestehenden beitreten.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FamilySetupButton(
                title: 'QR-Code scannen, um beizutreten',
                description: 'Richte die Kamera auf einen Einladungscode',
                icon: Icons.chevron_right_rounded,
                onPressed: () => _openQrScanner(context)
              ),
              const SizedBox(height: 16),
              FamilySetupButton(
                title: 'Neue Familie erstellen',
                description: 'Erstelle deine eigene Familie',
                icon: Icons.chevron_right_rounded,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CreateFamilyScreen(),
                    ),
                  );
                }
              ),
              const SizedBox(height: 40),
              const LogoutButton()
            ],
          ),
        ),
      ),
    );
  }
}
