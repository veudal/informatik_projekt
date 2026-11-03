import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Familienname')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Account(name: 'Familie', balance: '300 €'),
          SizedBox(height: 12),
          Account(name: 'Username', balance: '45 €'),
        ],
      ),
    );
  }
}

class Account extends StatelessWidget {
  final String name;
  final String balance;

  const Account({required this.name, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(name),
        trailing: Text(balance),
        onTap: () {},
      ),
    );
  }
}
