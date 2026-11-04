import 'package:flutter/material.dart';
import 'package:informatik_projekt/models/family.dart';

class FamilyCard extends StatelessWidget {
  final Family family;

  const FamilyCard({super.key, required this.family});

  @override
  Widget build(BuildContext context) {
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
        subtitle: Text('UUID: ${family.id}'),
      ),
    );
  }
}