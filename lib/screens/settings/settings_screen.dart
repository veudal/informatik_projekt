import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/auth/login/login_screen.dart';
import 'package:informatik_projekt/screens/settings/family/invitation_screen.dart';
import 'package:informatik_projekt/services/api_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Bist du dir sicher, dass du dich abmelden möchtest?'),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Abbrechen',
                style: TextStyle(color: Colors.indigo),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Abmelden',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () async {
                await ApiService().logout();
                
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Einstellungen',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Konto'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profil',
            subtitle: 'Kontodetails verwalten',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.notifications_none,
            title: 'Benachrichtigungen',
            subtitle: 'Alarme steuern',
            onTap: () {},
          ),
          const Divider(),
          _buildSectionTitle('Familie'),
          _buildSettingsTile(
            icon: Icons.person_add_alt, 
            title: 'Familienmitglied einladen', 
            subtitle: '???', 
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const InvitationScreen()));
            }
          ),
          const Divider(),
          _buildSectionTitle('Anwendung'),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'Über',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'Unterstützung erhalten',
            onTap: () {},
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutConfirmation(context),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Logout',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
