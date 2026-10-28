import 'package:flutter/material.dart';

import 'screens/families_screen.dart'; // Make sure this matches your folder name!
import 'screens/login/scanner_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Finance & Chores',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      // home: const FamiliesScreen(),
      home: const ScannerScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
