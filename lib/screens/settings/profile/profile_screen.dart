import 'package:flutter/material.dart';
import 'package:informatik_projekt/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _me;
  String? _familyName;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final me = await _apiService.getMe();
      String? familyName;
      if (me['familyId'] != null) {
        familyName = (await _apiService.getFamily())?.name;
      }
      if (!mounted) return;
      setState(() {
        _me = me;
        _familyName = familyName;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return '–';
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  int? _age(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso);
    if (d == null) return null;
    final now = DateTime.now();
    var age = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) age--;
    return age;
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Admin';
      case 'child':
        return 'Kind';
      case 'parent':
        return 'Elternteil';
      default:
        return role ?? '–';
    }
  }

  String _val(String? s) => (s == null || s.trim().isEmpty) ? '–' : s;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    final me = _me!;
    final displayName = _val(me['displayName']?.toString());
    final age = _age(me['birthDate']?.toString());

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                displayName == '–' ? '?' : displayName[0].toUpperCase(),
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              displayName,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(child: Chip(label: Text(_roleLabel(me['role']?.toString()))))
          ,
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                _row(Icons.email_outlined, 'E-Mail', _val(me['email']?.toString())),
                const Divider(height: 1),
                _row(Icons.badge_outlined, 'Vorname', _val(me['firstName']?.toString())),
                const Divider(height: 1),
                _row(Icons.badge_outlined, 'Nachname', _val(me['lastName']?.toString())),
                const Divider(height: 1),
                _row(Icons.person_outline, 'Anzeigename', displayName),
                const Divider(height: 1),
                _row(
                  Icons.cake_outlined,
                  'Geburtsdatum',
                  age == null
                      ? _formatDate(me['birthDate']?.toString())
                      : '${_formatDate(me['birthDate']?.toString())} ($age Jahre)',
                ),
                const Divider(height: 1),
                _row(Icons.family_restroom, 'Familie', _val(_familyName)),
                const Divider(height: 1),
                _row(Icons.fingerprint, 'Nutzer-ID', _val(me['id']?.toString())),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}