import 'package:uuid/uuid.dart';

class JoinRequest {
  final String name;
  final UuidValue requesterId;

  new({required this.name, required this.requesterId});
}