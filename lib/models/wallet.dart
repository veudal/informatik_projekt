class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.kind,
    this.ownerId,
    this.balanceCents,
  });

  final String id;
  final String name;
  final String kind;
  final String? ownerId;
  final int? balanceCents;

  bool get isFamily => kind.toLowerCase() == 'family';

  factory WalletAccount.fromJson(Map<String, dynamic> json) {
    return WalletAccount(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Konto',
      kind: json['kind']?.toString() ?? '',
      ownerId: (json['ownerId'] ?? json['owner_id'])?.toString(),
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

  /// Anzeigename: `Familienkonto <Familienname>` bzw. `Einzelkonto <Name des Mitglieds>`.
  /// [memberNames] bildet User-ID -> Name ab.
  String displayName({String? familyName, Map<String, String> memberNames = const {}}) {
    if (isFamily) {
      final fam = familyName?.trim() ?? '';
      return fam.isEmpty ? 'Familienkonto' : 'Familienkonto $fam';
    }
    final owner = ownerId != null ? memberNames[ownerId] : null;
    return (owner == null || owner.isEmpty) ? 'Einzelkonto' : 'Einzelkonto $owner';
  }
}
