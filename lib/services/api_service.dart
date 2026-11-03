import 'dart:convert';
import '../models/transaction.dart';

import 'package:http/http.dart' as http;

import '../models/family.dart';

class ApiService {
  // Use 10.0.2.2:1337 for Android Emulator, localhost:1337 for iOS/Web/Desktop
  //static const String baseUrl = 'https://informatik-projekt-backend.onrender.com/api';
  static const String baseUrl = 'http://localhost:1337/api';



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

  Future<List<Transaction>> getTransactionsByWallet(String walletId, String token) async {
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

  Future<void> createTransaction(String walletId, String familyWalletId, int amountCents, String kind, String note, String token) async {
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
    throw Exception('Fehler beim Erstellen der Transaktion (Status: ${response.statusCode})');
  }
 }
}
