import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';

final class User extends Equatable {
  const User({required this.id, required this.fullName, required this.role});

  final String id;
  final String fullName;
  final UserRole role;

  bool can(Permission permission) => role.permissions.contains(permission);

  @override
  List<Object?> get props => [id, fullName, role];
}
