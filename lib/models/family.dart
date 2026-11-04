class Family {
  final String id;
  final String name;
  final DateTime? createdAt;

  Family({required this.id, required this.name, this.createdAt});

  factory Family.fromJson(Map<String, dynamic> json) {
    var dateString = json['createdAt'];

    return Family(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unnamed Family',
      createdAt: dateString != null
          ? DateTime.tryParse(dateString.toString())
          : null,
    );
  }
}
