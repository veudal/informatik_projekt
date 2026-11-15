import 'package:uuid/uuid.dart';

class JoinRequest {
  final String displayName;
  final UuidValue id;

  new({required this.displayName, required this.id});

  factory JoinRequest.fromJson(dynamic json) {
    return JoinRequest(
      displayName: json['display_name'] as String,
      id: UuidValue.fromString(json['id'] as String),
    );
  }
}
