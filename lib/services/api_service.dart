import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/family.dart';

class ApiService {
  // Use 10.0.2.2:1337 for Android Emulator, localhost:1337 for iOS/Web/Desktop
  static const String baseUrl =
      'https://informatik-projekt-backend.onrender.com/api';
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

  /// Joins the family with the given [familyId] (a UUID scanned from a
  /// family invite QR code).
  ///
  /// Expects the backend to provide: `POST /api/families/{familyId}/join`.
  Future<void> joinFamily(String familyId) async {
    final Uri uri = Uri.parse('$baseUrl/families/$familyId/join');

    try {
      final http.Response response = await http.post(uri);

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
}

/// Thrown when joining a family via a scanned invite code fails.
class FamilyJoinException implements Exception {
  FamilyJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
