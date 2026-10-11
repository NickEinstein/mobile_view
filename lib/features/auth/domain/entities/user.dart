import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';

final class User extends Equatable {
  const User({
    required this.id,
    required this.fullName,
    required this.role,
    this.stateId,
    this.lgaId,
    this.userName,
    this.email,
    this.phone,
    this.roleName,
    this.centreName,
  });

  final String id;
  final String fullName;
  final UserRole role;

  /// The account's own state and LGA (`State_ID`, `LGA_ID`), where its
  /// registrations take place. Null if the backend didn't give them.
  final String? stateId;
  final String? lgaId;

  /// As the backend describes the account, for the profile. Any may be
  /// missing.
  final String? userName;
  final String? email;
  final String? phone;
  final String? roleName;

  /// The registration centre the account works at.
  final String? centreName;

  bool can(Permission permission) => role.permissions.contains(permission);

  @override
  List<Object?> get props => [
    id,
    fullName,
    role,
    stateId,
    lgaId,
    userName,
    email,
    phone,
    roleName,
    centreName,
  ];
}
