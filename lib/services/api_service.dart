import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/calendar_entry.dart';
import '../models/family.dart';
import '../models/goal.dart';
import '../models/goal_contribution.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'structs/join_request.dart';

class ApiService {
  final storage = const FlutterSecureStorage();
  static const String baseUrl = AppConfig.apiBaseUrl;

  static const _jsonHeader = {'Content-Type': 'application/json'};
  static const _okOrCreated = {200, 201};

  Future<Map<String, String>> _authorizationHeaders({
    bool includeJsonContentType = false,
  }) async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    if (token == null || token.isEmpty) throw Exception('Nicht angemeldet');

    return {
      'Authorization': 'Bearer $token',
      if (includeJsonContentType) ..._jsonHeader,
    };
  }

  // Auth request; logs out on 401. ok: null = caller checks status.
  Future<http.Response> _call(
    String method,
    String path, {
    Object? body,
    Set<int>? ok = const {200},
    String error = 'HTTP Error',
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final isPost = method == 'POST';
    final headers = await _authorizationHeaders(includeJsonContentType: isPost);
    final response = isPost
        ? await http.post(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          )
        : await http.get(uri, headers: headers);

    if (response.statusCode == 401) {
      await logout();
      throw SessionExpiredException();
    }
    if (ok != null && !ok.contains(response.statusCode)) {
      throw Exception('$error (Status: ${response.statusCode})');
    }
    return response;
  }

  List<Map<String, dynamic>> _jsonList(
    http.Response response,
    String what, {
    bool lenient = false,
  }) {
    final decoded = jsonDecode(response.body);
    final error = FormatException('Unexpected $what data from server');
    if (decoded is! List) throw error;
    if (lenient) return decoded.whereType<Map<String, dynamic>>().toList();
    return decoded.map((e) => e is Map<String, dynamic> ? e : throw error).toList();
  }

  Map<String, dynamic> _jsonMap(http.Response response) =>
      jsonDecode(response.body) as Map<String, dynamic>;

  Future<bool> isAuthenticated() async {
    final token = await storage.read(key: AppConfig.storageTokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() => storage.delete(key: AppConfig.storageTokenKey);

  Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _jsonHeader,
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

  Future<bool> isEmailRegistered(String email) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/auth/check-email?email=${Uri.encodeQueryComponent(email)}',
      ),
      headers: _jsonHeader,
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
      Uri.parse('$baseUrl/auth/register'),
      headers: _jsonHeader,
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
      'success': _okOrCreated.contains(response.statusCode),
      'statusCode': response.statusCode,
      'body': response.body,
    };
  }

  Future<http.Response> authGet(String path) async => http.get(
        Uri.parse('$baseUrl$path'),
        headers: await _authorizationHeaders(),
      );

  Future<Map<String, dynamic>> getMe() async => _jsonMap(
        await _call('GET', '/users/me', error: 'Fehler beim Laden des Profils'),
      );

  Future<Family?> getFamily() async {
    final response = await _call(
      'GET',
      '/family',
      ok: {200, 204, 404},
      error: 'Failed to load family',
    );
    if (response.statusCode != 200) return null;

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

  Future<Family> createFamily(String name, String description) async {
    final response = await _call(
      'POST',
      '/families',
      body: {'name': name, 'description': description},
      ok: null,
    );
    if (_okOrCreated.contains(response.statusCode)) {
      return Family.fromJson(jsonDecode(response.body));
    }

    var message = 'Failed to create family';
    if (response.body.isNotEmpty) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic> && data['message'] is String) {
        message = data['message'] as String;
      }
    }
    throw Exception('$message (Status: ${response.statusCode})');
  }

  Future<void> joinFamily(String familyId) async {
    final http.Response response;
    try {
      response = await _call('POST', '/families/$familyId/join', ok: null);
    } on SessionExpiredException {
      rethrow;
    } catch (error) {
      throw FamilyJoinException(
        'Network error while joining the family: $error',
      );
    }

    switch (response.statusCode) {
      case 200 || 201 || 204:
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
  }

  Future<List<CalendarEntry>> getCalendarEntries(String familyId) async {
    final response = await _call(
      'GET',
      '/users/family/$familyId',
      error: 'Kalender konnte nicht geladen werden',
    );
    return (jsonDecode(response.body) as List<dynamic>)
        .where((member) => member['birthDate'] != null)
        .map((member) => CalendarEntry.fromMember(member))
        .toList();
  }

  Future<Map<String, String>> getFamilyMemberNames(String familyId) async {
    final response = await _call(
      'GET',
      '/users/family/$familyId',
      error: 'Fehler beim Laden der Familienmitglieder',
    );
    final decoded = jsonDecode(response.body);
    final names = <String, String>{};
    if (decoded is List) {
      for (final user in decoded.whereType<Map<String, dynamic>>()) {
        final id = user['id']?.toString();
        if (id == null) continue;
        final firstName = user['firstName']?.toString().trim() ?? '';
        final displayName = user['displayName']?.toString().trim() ?? '';
        names[id] = firstName.isNotEmpty ? firstName : displayName;
      }
    }
    return names;
  }

  Future<List<WalletAccount>> getWalletsForFamily(String familyId) async {
    final response = await _call(
      'GET',
      '/wallets/family/$familyId',
      error: 'Failed to load wallets',
    );
    return _jsonList(response, 'wallet').map(WalletAccount.fromJson).toList();
  }

  Future<List<WalletAccount>> getFamilyWalletsForFamily(String familyId) async {
    final response = await _call(
      'GET',
      '/family-wallets/family/$familyId',
      error: 'Failed to load family wallets',
    );
    return _jsonList(response, 'family wallet')
        .map(WalletAccount.fromFamilyWalletJson)
        .toList();
  }

  Future<void> createFamilyWallet(String familyId, String name) => _call(
        'POST',
        '/family-wallets',
        body: {
          'familyId': familyId,
          'kind': 'family',
          'name': name,
          'currency': 'EUR',
          'balanceCents': 0,
          'createdAt': DateTime.now().toUtc().toIso8601String(),
        },
        ok: _okOrCreated,
        error: 'Failed to create family wallet',
      );

  Future<int> getWalletBalance(String walletId) async {
    final response = await _call(
      'GET',
      '/wallets/balance/$walletId',
      error: 'Fehler beim Laden des Kontostands',
    );
    return int.parse(response.body.trim());
  }

  Future<List<Transaction>> getTransactionsByWallet(String walletId) async {
    final response = await _call(
      'GET',
      '/transactions/wallet/$walletId',
      error: 'Fehler beim Laden der Transaktionen',
    );
    return _jsonList(response, 'transaction').map(Transaction.fromJson).toList();
  }

  Future<List<Transaction>> getTransactionsByFamilyWallet(
    String familyWalletId,
  ) async {
    final response = await _call(
      'GET',
      '/transactions/family-wallet/$familyWalletId',
      error: 'Fehler beim Laden der Familienkonto-Transaktionen',
    );
    return _jsonList(response, 'transaction').map(Transaction.fromJson).toList();
  }

  Future<void> createTransaction(
    String walletId,
    String familyWalletId,
    int amountCents,
    String kind,
    String note,
  ) =>
      _call(
        'POST',
        '/transactions',
        body: {
          'walletId': walletId,
          'familyWalletId': familyWalletId,
          'amountCents': amountCents,
          'kind': kind,
          'note': note,
        },
        ok: _okOrCreated,
        error: 'Fehler beim Erstellen der Transaktion',
      );

  Future<void> createMemberTransfer(
    String fromWalletId,
    String toWalletId,
    int amountCents,
    String note,
  ) =>
      _call(
        'POST',
        '/transactions/member-transfer',
        body: {
          'fromWalletId': fromWalletId,
          'toWalletId': toWalletId,
          'amountCents': amountCents,
          'note': note,
        },
        ok: _okOrCreated,
        error: 'Fehler bei der Überweisung',
      );

  Future<void> createExternalTransfer(
    String familyWalletId, {
    required bool isDeposit,
    required int amountCents,
    required String bankName,
    String? note,
  }) async {
    final response = await _call(
      'POST',
      '/family-wallets/$familyWalletId/external-transfer',
      body: {
        'direction': isDeposit ? 'deposit' : 'withdrawal',
        'amountCents': amountCents,
        'bankName': bankName,
        'note': note,
      },
      ok: null,
    );
    if (response.statusCode == 400 && !isDeposit) {
      throw Exception('Nicht genügend Guthaben auf dem Familienkonto');
    }
    if (!_okOrCreated.contains(response.statusCode)) {
      throw Exception(
        'Fehler bei der ${isDeposit ? 'Einzahlung' : 'Auszahlung'} '
        '(Status: ${response.statusCode})',
      );
    }
  }

  // amountCents: + deposit, - withdrawal (family wallet view)
  Future<List<Transaction>> getExternalTransfers(String familyWalletId) async {
    final response = await _call(
      'GET',
      '/external-transfers/family-wallet/$familyWalletId',
      error: 'Fehler beim Laden der Bankbuchungen',
    );
    return (jsonDecode(response.body) as List).map((raw) {
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

  Future<List<Goal>> getGoalsForFamily(String familyId) async {
    final response = await _call(
      'GET',
      '/goals/family/$familyId',
      error: 'Fehler beim Laden der Ziele',
    );
    return _jsonList(response, 'goal', lenient: true).map(Goal.fromJson).toList();
  }

  Future<Goal> createGoal({
    required String familyId,
    required String name,
    required int targetCents,
    DateTime? deadline,
    List<String> participantIds = const [],
  }) async {
    final response = await _call(
      'POST',
      '/goals',
      body: {
        'familyId': familyId,
        'goalName': name,
        'targetCents': targetCents,
        if (deadline != null)
          'deadline': deadline.toIso8601String().substring(0, 10),
        'participantIds': participantIds,
      },
      ok: _okOrCreated,
      error: 'Fehler beim Erstellen des Ziels',
    );
    return Goal.fromJson(_jsonMap(response));
  }

  Future<List<GoalContribution>> getContributionsForGoal(String goalId) async {
    final response = await _call(
      'GET',
      '/goal-contributions/goal/$goalId',
      error: 'Fehler beim Laden der Einzahlungen',
    );
    return _jsonList(response, 'contribution', lenient: true)
        .map(GoalContribution.fromJson)
        .toList();
  }

  Future<GoalContribution> createGoalContribution({
    required String goalId,
    required int amountCents,
  }) async {
    final response = await _call(
      'POST',
      '/goal-contributions',
      body: {'goalId': goalId, 'amountCents': amountCents},
      ok: _okOrCreated,
      error: 'Fehler beim Einzahlen ins Ziel',
    );
    return GoalContribution.fromJson(_jsonMap(response));
  }

  Future<String> createInvitation() async {
    final response = await _call(
      'POST',
      '/family/invite/create-invitation',
      ok: {201},
    );
    return _jsonMap(response)['id'] as String;
  }

  Future<JoinRequest?> pollJoinRequest(String id) async {
    final response = await _call(
      'GET',
      '/family/invite/poll-redeemer/$id',
      ok: {200, 204},
    );
    return response.statusCode == 204
        ? null
        : JoinRequest.fromJson(jsonDecode(response.body));
  }

  Future<void> respondRedeemer(String id, bool accept) => _call(
        'POST',
        '/family/invite/respond-redeemer/$id',
        body: {'accept': accept},
      );

  Future<void> redeem(String id) =>
      _call('POST', '/family/invite/redeem/$id');

  Future<String> pollStatus(String id) async {
    final response = await _call('GET', '/family/invite/poll-status/$id');
    final status = _jsonMap(response)['status'] as String;
    if (const {'pending', 'accepted', 'denied'}.contains(status)) return status;
    throw Exception('Unknown status reported: $status');
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