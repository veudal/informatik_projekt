import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/family.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';

class ApiService {
  final storage = const FlutterSecureStorage();
  static const String baseUrl = AppConfig.apiBaseUrl;

  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await storage.delete(key: AppConfig.storageTokenKey);
  }

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) return false;

    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['token'] is! String ||
        (body['token'] as String).isEmpty) {
      throw const FormatException('Login response does not contain a token');
    }

    await storage.write(
      key: AppConfig.storageTokenKey,
      value: body['token'] as String,
    );
    return true;
  }

  Future<Map<String, String>> _authorizationHeaders({
    bool includeJsonContentType = false,
  }) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    if (token == null || token.isEmpty) {
      throw Exception('Nicht angemeldet');
    }

    return {
      'Authorization': 'Bearer $token',
      if (includeJsonContentType) 'Content-Type': 'application/json',
    };
  }

  Future<bool> isEmailRegistered(String email) async {
    final response = await http.get(
      Uri.parse(
        '${AppConfig.apiBaseUrl}/auth/check-email'
        '?email=${Uri.encodeQueryComponent(email)}',
      ),
      headers: {'Content-Type': 'application/json'},
    );
    return response.statusCode == 200;
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password,
    String displayName,
    DateTime birthDate,
  ) async {
    final response = await http.post(
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
      'success': response.statusCode == 200 || response.statusCode == 201,
      'statusCode': response.statusCode,
      'body': response.body,
    };
  }

  Future<http.Response> authGet(String path) async {
    return http.get(
      Uri.parse('${AppConfig.apiBaseUrl}$path'),
      headers: await _authorizationHeaders(),
    );
  }

  Future<Family?> getFamily() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/family'),
      headers: await _authorizationHeaders(),
    );

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
    throw const FormatException('Unexpected family data from server');
  }

  Future<List<WalletAccount>> getWalletsForFamily(String familyId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/wallets/family/$familyId'),
      headers: await _authorizationHeaders(),
    );

    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load wallets (Status: ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected wallet data from server');
    }
    return decoded.map((wallet) {
      if (wallet is! Map<String, dynamic>) {
        throw const FormatException('Unexpected wallet data from server');
      }
      return WalletAccount.fromJson(wallet);
    }).toList();
  }

  Future<List<WalletAccount>> getFamilyWalletsForFamily(String familyId) async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/family-wallets/family/$familyId'),
      headers: await _authorizationHeaders(),
    );

    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load family wallets (Status: ${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected family wallet data from server');
    }
    return decoded.map((wallet) {
      if (wallet is! Map<String, dynamic>) {
        throw const FormatException(
          'Unexpected family wallet data from server',
        );
      }
      return WalletAccount.fromFamilyWalletJson(wallet);
    }).toList();
  }

  Future<void> createFamilyWallet(String familyId, String name) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/family-wallets'),
      headers: await _authorizationHeaders(includeJsonContentType: true),
      body: jsonEncode({
        'familyId': familyId,
        'kind': 'family',
        'name': name,
        'currency': 'EUR',
        'balanceCents': 0,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    );

    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Failed to create family wallet (Status: ${response.statusCode})',
      );
    }
  }

  Future<void> joinFamily(String familyId) async {
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/families/$familyId/join');
    try {
      final response = await http.post(
        uri,
        headers: await _authorizationHeaders(),
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
            'Diese Familie konnte nicht beigetreten werden '
            '(Status: ${response.statusCode}).',
          );
      }
    } on FamilyJoinException {
      rethrow;
    } catch (error) {
      throw FamilyJoinException(
        'Network error while joining the family: $error',
      );
    }
  }

  Future<Family> createFamily(String name) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/families'),
      headers: await _authorizationHeaders(),
      body: {'name': name},
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return Family.fromJson(jsonDecode(response.body));
    }

    var errorMessage = 'Failed to create family';
    if (response.body.isNotEmpty) {
      final errorData = jsonDecode(response.body);
      if (errorData is Map<String, dynamic> && errorData['message'] is String) {
        errorMessage = errorData['message'] as String;
      }
    }
    throw Exception('$errorMessage (Status: ${response.statusCode})');
  }

  Future<int> getWalletBalance(String walletId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/wallets/balance/$walletId'),
      headers: await _authorizationHeaders(),
    );

    if (response.statusCode == 200) {
      return int.parse(response.body.trim());
    }
    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    throw Exception('Fehler beim Laden des Kontostands');
  }

  Future<List<Transaction>> getTransactionsByWallet(String walletId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/wallet/$walletId'),
      headers: await _authorizationHeaders(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((json) => Transaction.fromJson(json)).toList();
    }
    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    throw Exception('Fehler beim Laden der Transaktionen');
  }
  
  Future<List<Transaction>> getTransactionsByFamilyWallet(String familyWalletId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/transactions/family-wallet/$familyWalletId'),
      // HIER IST DER FIX: Wir nutzen die gleiche Methode für die Header wie überall sonst auch!
      headers: await _authorizationHeaders(), 
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Transaction.fromJson(json)).toList();
    } else if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    } else {
      // Mit Statuscode, damit wir beim nächsten Mal sofort wissen, was das Backend sagt
      throw Exception('Fehler beim Laden der Familienkonto-Transaktionen (Status: ${response.statusCode})');
    }
  }
  
  Future<void> createTransaction(
    String walletId,
    String familyWalletId,
    int amountCents,
    String kind,
    String note,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions'),
      headers: await _authorizationHeaders(includeJsonContentType: true),
      body: jsonEncode({
        'walletId': walletId,
        'familyWalletId': familyWalletId,
        'amountCents': amountCents,
        'kind': kind,
        'note': note,
      }),
    );

    if (response.statusCode == 401) {
      await logout();
      throw Exception('Session expired');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Fehler beim Erstellen der Transaktion '
        '(Status: ${response.statusCode})',
      );
    }
  }
}

class FamilyJoinException implements Exception {
  FamilyJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}
