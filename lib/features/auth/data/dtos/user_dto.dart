import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';

/// Wire format, kept separate from the domain [User] so API changes don't
/// ripple into the UI. All validation happens here, at the boundary.
final class UserDto {
  const UserDto({required this.id, required this.fullName, required this.role});

  factory UserDto.fromJson(Object? json) {
    final map = json.asJsonMap();
    final rawRole = map.requireString('role');
    final role = UserRole.tryParse(rawRole);
    if (role == null) throw FormatException('Unknown role "$rawRole".');
    return UserDto(
      id: map.requireString('id'),
      fullName: map.requireString('fullName'),
      role: role,
    );
  }

  final String id;
  final String fullName;
  final UserRole role;

  JsonMap toJson() => {'id': id, 'fullName': fullName, 'role': role.name};

  User toDomain() => User(id: id, fullName: fullName, role: role);
}
