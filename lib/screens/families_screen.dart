import 'package:flutter/material.dart';
import 'package:informatik_projekt/widgets/create_family_button.dart';

import '../models/family.dart';
import '../services/api_service.dart';
import '../widgets/join_family_button.dart';
import 'qr_scanner_screen.dart';

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

  /// Opens the QR scanner and handles the scanned family invite code.
  Future<void> _openQrScanner() async {
    final String? familyId = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrScannerScreen()),
    );

    if (familyId == null || !mounted) {
      return;
    }

    await _confirmJoinFamily(familyId);
  }

    Future<void> _openCreateFamilyDialog() async {
      showDialog(context: context, builder: (_) => AlertDialog(content: SelectableText('Mock up lol')));
  }

  /// Asks the user to confirm joining the scanned family.
  Future<void> _confirmJoinFamily(String familyId) async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        icon: Icon(Icons.family_restroom, size: 40, color: colorScheme.primary),
        title: const Text('Join this family?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This QR code contains a family invite ID:'),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                familyId,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.group_add_rounded),
            label: const Text('Join family'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await _joinFamily(familyId);
  }

  /// Calls the join endpoint and shows feedback for the result.
  Future<void> _joinFamily(String familyId) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await _apiService.joinFamily(familyId);

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Close the loading indicator.

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('You joined the family! 🎉'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );

      _loadData();
    } on FamilyJoinException catch (e) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(); // Close the loading indicator.

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
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
          Column(
            children: [
              JoinFamilyButton(onPressed: _openQrScanner),
              CreateFamilyButton(onPressed: _openCreateFamilyDialog),
              Expanded(
                child: RefreshIndicator(
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
                            formattedDate = '${family.createdAt!.toLocal()}'
                                .split('.')[0]; // Shows YYYY-MM-DD HH:MM:SS
                          }

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
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
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
