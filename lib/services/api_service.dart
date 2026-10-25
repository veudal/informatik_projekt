import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/family.dart';

class ApiService {
  // Use 10.0.2.2:1337 for Android Emulator, localhost:1337 for iOS/Web/Desktop
  static const String baseUrl = 'https://informatik-projekt-backend.onrender.com/api';
  //static const String baseUrl = 'http://localhost:1337/api';



  Future<List<Family>> getFamilies() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/families'));

      if (response.statusCode == 200) {
        Iterable data = jsonDecode(response.body);
        return data.map((json) => Family.fromJson(json)).toList();
      } else {
        throw Exception(
          'Failed to load families (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
