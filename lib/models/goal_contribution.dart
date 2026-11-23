/// Eine Einzahlung eines Familienmitglieds in ein Sparziel.
class GoalContribution {
  final String id;
  final String goalId;
  final String userId;
  final int amountCents;
  final DateTime? createdAt;

  const GoalContribution({
    required this.id,
    required this.goalId,
    required this.userId,
    required this.amountCents,
    this.createdAt,
  });

  factory GoalContribution.fromJson(Map<String, dynamic> json) {
    final createdAt = json['createdAt'];
    return GoalContribution(
      id: json['id']?.toString() ?? '',
      goalId: json['goalId']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      amountCents: (json['amountCents'] as num?)?.toInt() ?? 0,
      createdAt:
          createdAt != null ? DateTime.tryParse(createdAt.toString()) : null,
    );
  }
}
