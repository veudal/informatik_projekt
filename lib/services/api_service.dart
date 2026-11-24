import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:informatik_projekt/services/structs/invitation_response.dart';
import 'package:informatik_projekt/services/structs/invitation_status.dart';

import '../config/app_config.dart';
import '../models/calendar_entry.dart';
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
    String firstName,
    String lastName,
    String displayName,
    DateTime birthDate,
  ) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
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

  Future<List<CalendarEntry>> getCalendarEntries(String familyId) async {
    final response = await authGet('/users/family/$familyId');
    if (response.statusCode != 200) {
      throw Exception(
        'Kalender konnte nicht geladen werden (Status: ${response.statusCode})',
      );
    }

    final members = jsonDecode(response.body) as List<dynamic>;
    return members
        .where((member) => member['birthDate'] != null)
        .map((member) => CalendarEntry.fromMember(member))
        .toList();
  }

  Future<Family?> getFamily() async {
    final response = await http.get(
      Uri.parse('${AppConfig.apiBaseUrl}/family'),
      headers: await _authorizationHeaders(),
    );

    if (response.statusCode == 204 || response.statusCode == 404) return null;
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
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
      throw SessionExpiredException();
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
      throw SessionExpiredException();
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
      throw SessionExpiredException();
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

  Future<Family> createFamily(String name, String description) async {
    final response = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/families'),
      headers: await _authorizationHeaders(includeJsonContentType: true),
      body: jsonEncode({'name': name, 'description': description}),
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
      throw SessionExpiredException();
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
      throw SessionExpiredException();
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
      throw SessionExpiredException();
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
      throw SessionExpiredException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Fehler beim Erstellen der Transaktion '
        '(Status: ${response.statusCode})',
      );
    }
  }

  /// Liefert User-ID -> Name (Vorname, sonst Anzeigename) aller Familienmitglieder.
  Future<Map<String, String>> getFamilyMemberNames(String familyId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/family/$familyId'),
      headers: await _authorizationHeaders(),
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Fehler beim Laden der Familienmitglieder (Status: ${response.statusCode})',
      );
    }
    final decoded = jsonDecode(response.body);
    final names = <String, String>{};
    if (decoded is List) {
      for (final user in decoded) {
        if (user is! Map<String, dynamic>) continue;
        final id = user['id']?.toString();
        if (id == null) continue;
        final firstName = user['firstName']?.toString().trim() ?? '';
        final displayName = user['displayName']?.toString().trim() ?? '';
        names[id] = firstName.isNotEmpty ? firstName : displayName;
      }
    }
    return names;
  }

  /// Überweisung zwischen zwei Einzelkonten innerhalb der Familie.
  Future<void> createMemberTransfer(
    String fromWalletId,
    String toWalletId,
    int amountCents,
    String note,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/transactions/member-transfer'),
      headers: await _authorizationHeaders(includeJsonContentType: true),
      body: jsonEncode({
        'fromWalletId': fromWalletId,
        'toWalletId': toWalletId,
        'amountCents': amountCents,
        'note': note,
      }),
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Fehler bei der Überweisung (Status: ${response.statusCode})',
      );
    }
  }

  /// Simulierte Ein- ([isDeposit] = true) oder Auszahlung zwischen Familienkonto und externer Bank.
  Future<void> createExternalTransfer(
    String familyWalletId, {
    required bool isDeposit,
    required int amountCents,
    required String bankName,
    String? note,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/family-wallets/$familyWalletId/external-transfer'),
      headers: await _authorizationHeaders(includeJsonContentType: true),
      body: jsonEncode({
        'direction': isDeposit ? 'deposit' : 'withdrawal',
        'amountCents': amountCents,
        'bankName': bankName,
        'note': note,
      }),
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode == 400 && !isDeposit) {
      throw Exception('Nicht genügend Guthaben auf dem Familienkonto');
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        'Fehler bei der ${isDeposit ? 'Einzahlung' : 'Auszahlung'} '
        '(Status: ${response.statusCode})',
      );
    }
  }

  /// Externe Bankbuchungen des Familienkontos. amountCents ist aus Sicht
  /// des Familienkontos vorzeichenbehaftet (+ Einzahlung, - Auszahlung).
  Future<List<Transaction>> getExternalTransfers(String familyWalletId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/external-transfers/family-wallet/$familyWalletId'),
      headers: await _authorizationHeaders(),
    );
    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (response.statusCode != 200) {
      throw Exception(
        'Fehler beim Laden der Bankbuchungen (Status: ${response.statusCode})',
      );
    }
    final data = jsonDecode(response.body) as List;
    return data.map((raw) {
      final json = raw as Map<String, dynamic>;
      final amount = (json['amountCents'] ?? json['amount_cents'] ?? 0) as num;
      final bank = json['bankName']?.toString() ?? 'Externe Bank';
      final note = json['note']?.toString() ?? '';
      final isDeposit = amount >= 0;
      return Transaction(
        id: json['id']?.toString() ?? '',
        amountCents: amount.toInt(),
        kind: isDeposit ? 'external_deposit' : 'external_withdrawal',
        note: '${isDeposit ? 'Von' : 'An'} $bank${note.isEmpty ? '' : ' · $note'}',
        createdAt: DateTime.parse(
          json['createdAt'] ?? DateTime.now().toIso8601String(),
        ),
      );
    }).toList();
  }

  Future<String> createInvitation() {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.post(
            Uri.parse('$baseUrl/family/invite/create-invitation'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        })
        .then((response) {
          if (response.statusCode != HttpStatus.created) {
            throw Exception('HTTP Error ${response.statusCode}');
          }

          return jsonDecode(response.body)['id'] as String;
        });
  }

  Future<String?> pollJoinRequest(String id) {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.get(
            Uri.parse('$baseUrl/family/invite/poll-redeemer/$id'),
            headers: {'Authorization': 'Bearer $token'},
          );
        })
        .then((response) {
          if (response.statusCode == HttpStatus.noContent) {
            return null;
          } else if (response.statusCode == HttpStatus.ok) {
            return jsonDecode(response.body)['display_name'] as String;
          } else {
            throw Exception('HTTP Error ${response.statusCode}');
          }
        });
  }

  Future<void> respondRedeemer(String id, InvitationResponse response) {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.post(
            Uri.parse('$baseUrl/family/invite/respond-redeemer/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'response': response.name.toUpperCase()}),
          );
        })
        .then((response) {
          if (response.statusCode != HttpStatus.ok) {
            throw Exception('HTTP Error ${response.statusCode}');
          }
        });
  }

  Future<void> redeem(String id) {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.post(
            Uri.parse('$baseUrl/family/invite/redeem/$id'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          );
        })
        .then((response) {
          if (response.statusCode != HttpStatus.ok) {
            throw Exception('HTTP Error ${response.statusCode}');
          }
        });
  }

  Future<InvitationStatus> pollStatus(String id) {
    return storage
        .read(key: AppConfig.storageTokenKey)
        .then((token) {
          return http.get(
            Uri.parse('$baseUrl/family/invite/poll-status/$id'),
            headers: {'Authorization': 'Bearer $token'},
          );
        })
        .then((response) {
          if (response.statusCode == HttpStatus.ok) {
            String status = jsonDecode(response.body)['status'] as String;

            return InvitationStatus.fromString(status) ?? InvitationStatus.invalidated;
          } else if (response.statusCode == HttpStatus.badRequest) {
            throw Exception('The Request may be expired or already used by another user.');
          } else {
            throw Exception('HTTP Error ${response.statusCode}');
          }
        });
  }
}

class FamilyJoinException implements Exception {
  FamilyJoinException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SessionExpiredException implements Exception {
  @override
  String toString() => 'Session expired';
}
