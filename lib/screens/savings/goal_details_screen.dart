import 'package:flutter/material.dart';

import '../../models/goal.dart';

/// Detailansicht eines Sparziels.
///
/// Inhalt folgt noch – aktuell nur der Rahmen mit dem Zielnamen als Titel.
/// Über [goal] stehen alle Daten des angeklickten Ziels zur Verfügung
/// (Name, Zielbetrag, erreichter Betrag, Datum, Teilnehmer-IDs).
class GoalDetailsScreen extends StatelessWidget {
  const GoalDetailsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(goal.name)),
      body: const SizedBox.shrink(),
    );
  }
}
