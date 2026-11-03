import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/family.dart';
import '../config/app_config.dart';

class ApiService {
  final storage = FlutterSecureStorage();

  /// Checks if a token exists in secure storage to determine if the user is logged in.
  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    return token != null;
  }

  Future<void> logout() async {
    await storage.delete(key: AppConfig.storageTokenKey);
  }

  Future<bool> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    print('login: ${res.statusCode} ${res.body}');
    if (res.statusCode != 200) return false;
    await storage.write(key: AppConfig.storageTokenKey, value: jsonDecode(res.body)['token']);
    return true;
  }

  Future<http.Response> authGet(String path) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    return http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<List<Family>> getFamily() async {
    try {
      final token = await storage.read(key: AppConfig.storageTokenKey);
      final response = await http.get(
        Uri.parse('${AppConfig.apiBaseUrl}/family'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final dynamic decodedData = jsonDecode(response.body);

        if (decodedData is List) {
          return decodedData.map((json) => Family.fromJson(json)).toList();
        } else if (decodedData is Map<String, dynamic>) {
          return [Family.fromJson(decodedData)];
        } else {
          throw Exception('Unexpected data format from server');
        }
      } else {
        throw Exception(
          'Failed to load families (Status: ${response.statusCode})',
        );
      }
    } catch (e) {
      print('Error in getFamily: $e');
      throw Exception('Network error: $e');
    }
  }

  /// Joins the family with the given [familyId] (a UUID scanned from a
  /// family invite QR code).
  ///
  /// Expects the backend to provide: `POST /api/families/{familyId}/join`.
  Future<void> joinFamily(String familyId) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    final Uri uri = Uri.parse('${AppConfig.apiBaseUrl}/families/$familyId/join');

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );

      switch (response.statusCode) {
        case 200:
        case 201:
        case 204:
          return;
        case 404:
          throw FamilyJoinException(
            'No family was found for this code. '
            'Please double-check the QR code.',
          );
        case 409:
          throw FamilyJoinException('You are already a member of this family.');
        default:
          throw FamilyJoinException(
            'Could not join this family (Status: ${response.statusCode}).',
          );
      }
    } on FamilyJoinException {
      rethrow;
    } catch (e) {
      throw FamilyJoinException('Network error while joining the family: $e');
    }
  }

  Future<Family> createFamily(String name) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    final Uri uri = Uri.parse('${AppConfig.apiBaseUrl}/families');

    try {
      final http.Response response = await http.post(
        uri,
        headers: {'Authorization': 'Bearer $token'},
        body: {'name': name},
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return Family.fromJson(jsonDecode(response.body));
      } else {
        // Try to parse error message if available, otherwise use status code
        String errorMessage = 'Failed to create family';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception('$errorMessage (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Network error while creating family: $e');
    }
  }

}

/// Thrown when joining a family via a scanned invite code fails.
class FamilyJoinException implements Exception {
  FamilyJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
