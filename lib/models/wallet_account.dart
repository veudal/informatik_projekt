// lib/models/wallet_account.dart
class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.kind,
    this.balanceCents,
  });

  final String id;
  final String name;
  final String kind;
  final int? balanceCents;

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Konto',
      kind: json['kind']?.toString() ?? '',
    );
  }

  factory WalletAccount.fromFamilyWalletJson(Map<String, dynamic> json) {
    final balance = json['balanceCents'] ?? json['balance_cents'];
    return WalletAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Familienkonto',
      kind: 'family',
      balanceCents: balance is num ? balance.toInt() : int.tryParse('$balance'),
    );
  }
}