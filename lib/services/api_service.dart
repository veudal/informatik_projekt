import 'dart:convert';
import 'dart:io';

import 'package:informatik_projekt/services/structs/join_request.dart';
import 'package:uuid/uuid.dart';

import '../models/transaction.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/family.dart';
import '../config/app_config.dart';

class ApiService {
  final storage = FlutterSecureStorage();
  static const String baseUrl = AppConfig.apiBaseUrl;

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
    await storage.write(
      key: AppConfig.storageTokenKey,
      value: jsonDecode(res.body)['token'],
    );
    return true;
  }

  Future<bool> isEmailRegistered(String email) async {
    final res = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/check-email?email=$email'),
      headers: {'Content-Type': 'application/json'},
    );
    // Assuming 200 means registered, others mean not registered or error
    return res.statusCode == 200;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String displayName,
    DateTime birthDate,
  ) async {
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
        'birthDate': birthDate.toIso8601String(),
        'role': 'admin',
      }),
    );

    return {
      'success': res.statusCode == 200 || res.statusCode == 201,
      'statusCode': res.statusCode,
      'body': res.body,
    };
  }

  Future<http.Response> authGet(String path) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    return http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  /// Returns the user's family, or null if the user has none.
  Future<Family?> getFamily() async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/family'),
      headers: {'Authorization': 'Bearer $token'},
    );

    // No family is a valid state
    if (response.statusCode == 204 || response.statusCode == 404) return null;

    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to load family (Status: ${response.statusCode})');
    }

    final body = response.body.trim();
    if (body.isEmpty || body == 'null') return null;

    final decoded = jsonDecode(body);
    if (decoded == null) return null;
    if (decoded is List) {
      return decoded.isEmpty ? null : Family.fromJson(decoded.first);
    }
    if (decoded is Map<String, dynamic>) return Family.fromJson(decoded);

    throw Exception('Unexpected data format from server');
  }

  /// Joins the family with the given [familyId].
  ///
  /// Expects the backend to provide: `POST /api/families/{familyId}/join`.
  Future<void> joinFamily(String familyId) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    final Uri uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/families/$familyId/join',
    );

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
            'Diese Familie konnte nicht beigetreten werden (Status: ${response.statusCode}).',
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

  Future<int> getWalletBalance(String walletId, String token) async {
    final response = await http.get(
      Uri.parse('$baseUrl/wallets/balance/$walletId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      return int.parse(response.body);
    } else {
      throw Exception('Fehler beim Laden des Kontostands');
    }
  }

  Future<List<Transaction>> getTransactionsByWallet(
    String walletId,
    String token,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/wallet/$walletId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      Iterable data = jsonDecode(response.body);
      return data.map((json) => Transaction.fromJson(json)).toList();
    } else {
      throw Exception('Fehler beim Laden der Transaktionen');
    }
  }

  Future<void> createTransaction(
    String walletId,
    String familyWalletId,
    int amountCents,
    String kind,
    String note,
    String token,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'walletId': walletId,
        'familyWalletId': familyWalletId,
        'amountCents': amountCents,
        'kind': kind,
        'note': note,
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Fehler beim Erstellen der Transaktion (Status: ${response.statusCode})',
      );
    }
  }

  Future<String> requestFamilyInviteCode() async {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.get(
            Uri.parse('$baseUrl/invite/create-code'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        })
        .then((response) {
          if (response.statusCode != 200 || response.statusCode != 201) {
            throw Exception('HTTP Error ${response.statusCode}');
          }

          return jsonDecode(response.body)['code'];
        });
  }

  Future<List<JoinRequest>> pollJoinRequests() async {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.get(
            Uri.parse('$baseUrl/invite/poll-requests'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        })
        .then((response) {
          if (response.statusCode != 200 || response.statusCode != 201) {
            throw Exception('HTTP Error ${response.statusCode}');
          }

          return jsonDecode(response.body)['requests'].map((entry) {
            return JoinRequest(
              name: entry['name'],
              requesterId: UuidValue.fromString(entry['requesterId']),
            );
          });
        });
  }

  Future<bool> sendJoinRequest(String code) {
    return Future.error('Not implemented');
  }

  Future<void> pollJoinRequestStatus() {
    return Future.error('Not implemented');
  }
}

/// Thrown when joining a family via a scanned invite code fails.
class FamilyJoinException implements Exception {
  FamilyJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
