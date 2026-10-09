import 'package:equatable/equatable.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';

final class User extends Equatable {
  const User({
    required this.id,
    required this.fullName,
    required this.role,
    this.stateId,
    this.lgaId,
  });

  final String id;
  final String fullName;
  final UserRole role;

  /// The account's own state and LGA (`State_ID`, `LGA_ID`), where its
  /// registrations take place. Null if the backend didn't give them.
  final String? stateId;
  final String? lgaId;

  bool can(Permission permission) => role.permissions.contains(permission);

  @override
  List<Object?> get props => [id, fullName, role, stateId, lgaId];
}
