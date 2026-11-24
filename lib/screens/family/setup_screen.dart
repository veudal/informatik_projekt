import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/family/join_family_screen.dart';
import 'package:informatik_projekt/widgets/family_setup_button.dart';
import 'package:informatik_projekt/widgets/logout_button.dart';

import 'create_family_screen.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Starte dein Familienleben')),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.family_restroom,
                  size: 80,
                  color: Colors.indigo,
                ),
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
                  title: 'Einer Familie beitreten',
                  description: 'Per Einladungscode in eine familie eintreten',
                  icon: Icons.group_add,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const JoinFamilyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                FamilySetupButton(
                  title: 'Neue Familie erstellen',
                  description: 'Erstelle deine eigene Familie',
                  icon: Icons.add_sharp,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateFamilyScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 40),
                const LogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
