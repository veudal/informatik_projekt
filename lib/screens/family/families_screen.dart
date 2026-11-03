import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:informatik_projekt/models/family.dart';
import 'package:informatik_projekt/services/api_service.dart';
import 'package:informatik_projekt/screens/settings/settings_screen.dart';


class FamiliesScreen extends StatefulWidget {
  const FamiliesScreen({super.key});

  @override
  State<FamiliesScreen> createState() => _FamiliesScreenState();
}

class _FamiliesScreenState extends State<FamiliesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Family>> _familiesFuture;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabSelection);
    _loadData();
  }

  void _handleTabSelection() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _familiesFuture = _apiService
          .authGet('/family')
          .then(
            (res) => res.body.isEmpty
                ? <Family>[]
                : [Family.fromJson(jsonDecode(res.body))],
          );
    });
    await _familiesFuture;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FamiGo - Wir-Spar - Spargel - Sparnest'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabController.index,
        onDestinationSelected: (i) {
          _tabController.animateTo(i);
          setState(() {});
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.group_outlined),
            label: 'Familie',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Aufgaben',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            label: 'Ziele',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            label: 'Aktivität',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: 'Einstellungen',
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadData,
                  child: FutureBuilder<List<Family>>(
                    future: _familiesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      } else if (snapshot.hasError) {
                        return Center(child: Text('Fehler: ${snapshot.error}'));
                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text('Keine Familien in der Datenbank gefunden.'),
                        );
                      } else {
                        final families = snapshot.data!;
                        return ListView.builder(
                          itemCount: families.length,
                          itemBuilder: (context, index) {
                            final family = families[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.home),
                                ),
                                title: Text(
                                  family.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                ),
                                ),
                                subtitle: Text('ID: ${family.id}'),
                              ),
                            );
                          },
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const Center(
            child: Text('Aufgaben-Panel', style: TextStyle(fontSize: 16)),
          ),
          const Center(
            child: Text('Ziele-Panel', style: TextStyle(fontSize: 16)),
          ),
          const Center(
            child: Text('Benachrichtigungs-Panel', style: TextStyle(fontSize: 16)),
          ),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
