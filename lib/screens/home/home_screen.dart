import '../wallet_details_screen.dart';
import 'package:flutter/material.dart';


// Test-Werte von Selim, bis es Login und echte Daten vom Backend gibt.
const String familyWalletId = 'b36bf7bb-e4d5-49eb-97a9-5c4b90bb6ecf';
const String testToken =
    'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ0ZXN0QHRlc3QuZGUiLCJpYXQiOjE3OTM3Mjg1NTQsImV4cCI6MTc5MzgxNDk1NH0.WmzOafC46Ckc2PA8tsEfQTFHuLMltEJ6RsOVgWJmXvo';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familienname')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          // Ohne walletId -> Karte ist (noch) nicht klickbar.
          Account(name: 'Familie', balance: '300 €'),
          SizedBox(height: 12),
          Account(
            name: 'Username',
            balance: '45 €',
            walletId: 'd2952f75-2f91-4a00-bb54-d061a4705fdf',
          ),
        ],
      ),
    );
  }
}

class Account extends StatelessWidget {
  final String name;
  final String balance;
  // Optional: welches Konto beim Antippen geöffnet wird.
  final String? walletId;

  const Account({
    super.key,
    required this.name,
    required this.balance,
    this.walletId,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(name),
        trailing: Text(balance),
        // Mit walletId: Selims Kontoansicht als neue Seite öffnen.
        onTap: walletId == null
            ? null
            : () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WalletDetailsScreen(
                      walletId: walletId!,
                      familyWalletId: familyWalletId,
                      token: testToken,
                      userName: name,
                    ),
                  ),
                );
              },
      ),
    );
  }
}