import 'package:flutter/material.dart';
import 'package:informatik_projekt/screens/settings/profile/profile_screen.dart';
import 'package:informatik_projekt/screens/settings/family/invitation_screen.dart';
import 'package:informatik_projekt/widgets/logout_button.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Konto'),
          _buildSettingsTile(
            icon: Icons.person_outline,
            title: 'Profil',
            subtitle: 'Kontodetails verwalten',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
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
            subtitle: 'Erweitere deine Armee',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const InvitationScreen(),
                ),
              );
            },
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
            child: LogoutButton(),
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
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
