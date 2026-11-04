import 'package:flutter/material.dart';

import 'shopping_list.dart';
import 'task_list.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Aufgaben'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Aufgaben'),
              Tab(text: 'Einkaufsliste'),
            ],
          ),
        ),
        body: const TabBarView(children: [TaskList(), ShoppingList()]),
      ),
    );
  }
}
