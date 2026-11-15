class Goal {
  final String id;
  final String familyId;
  final String? ownerId;
  final String name;
  final int targetCents;
  final int currentCents;
  final String status;
  final DateTime? deadline;
  final List<String> participantIds;
  final DateTime? createdAt;

  const Goal({
    required this.id,
    required this.familyId,
    required this.name,
    required this.targetCents,
    this.ownerId,
    this.currentCents = 0,
    this.status = 'active',
    this.deadline,
    this.participantIds = const [],
    this.createdAt,
  });

  /// Fortschritt zwischen 0.0 und 1.0.
  double get progress {
    if (targetCents <= 0) return 0;
    return (currentCents / targetCents).clamp(0.0, 1.0);
  }

  factory Goal.fromJson(Map<String, dynamic> json) {
    final deadline = json['deadline'];
    final createdAt = json['createdAt'];
    final participants = json['participantIds'];
    return Goal(
      id: json['id']?.toString() ?? '',
      familyId: json['familyId']?.toString() ?? '',
      ownerId: json['ownerId']?.toString(),
      name: json['goalName']?.toString() ?? '',
      targetCents: (json['targetCents'] as num?)?.toInt() ?? 0,
      currentCents: (json['currentCents'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'active',
      deadline: deadline != null ? DateTime.tryParse(deadline.toString()) : null,
      participantIds: participants is List
          ? participants.map((p) => p.toString()).toList()
          : const [],
      createdAt:
          createdAt != null ? DateTime.tryParse(createdAt.toString()) : null,
    );
  }
}
