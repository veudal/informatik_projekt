import 'package:flutter/material.dart';

import '../models/family.dart';
import 'wallet_details_screen.dart';
import '../services/api_service.dart';

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
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  void _loadData() {
    setState(() {
      _familiesFuture = _apiService.getFamilies();
    });
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
        title: const Text('Family App Hub'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.group), text: 'Families'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Families List Tab
          RefreshIndicator(
            onRefresh: () async => _loadData(),
            child: FutureBuilder<List<Family>>(
              future: _familiesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Error connecting to Spring Boot API:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No families found in database.'),
                  );
                }

                final families = snapshot.data!;
                return ListView.builder(
                  itemCount: families.length,
                  itemBuilder: (context, index) {
                    final family = families[index];

                    // Format the DateTime nicely if it exists
                    String formattedDate = 'Unknown date';
                    if (family.createdAt != null) {
                      formattedDate = '${family.createdAt!.toLocal()}'.split(
                        '.',
                      )[0]; // Shows YYYY-MM-DD HH:MM:SS
                    }

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.home)),
                        title: Text(
                          family.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        // Displaying both ID and the formatted timestamp in the subtitle
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${family.id}'),
                            const SizedBox(height: 4),
                            Text(
                              'Created: $formattedDate',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => WalletDetailsScreen(
                                walletId: 'd2952f75-2f91-4a00-bb54-d061a4705fdf',
                                familyWalletId: 'b36bf7bb-e4d5-49eb-97a9-5c4b90bb6ecf',
                                token: 'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0QHRlc3QuZGUiLCJpYXQiOjE3OTM1NDgwMjEsImV4cCI6MTc5MzYzNDQyMX0.21yc1uS-ihsYRyDrUqjQlkp0E4kzzM7YIvomx2R6mH0',
                                userName: 'selim',
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Tab 2: Settings / Placeholder Tab
          const Center(
            child: Text(
              'Settings & Configuration Panel',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
