class Transaction {
  final String id;
  final int amountCents;
  final String kind;
  final String note;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.amountCents,
    required this.kind,
    required this.note,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id']?.toString() ?? '',
      // Berücksichtigt camelCase und snake_case
      amountCents: json['amountCents'] ?? json['amount_cents'] ?? 0,
      kind: json['kind']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}