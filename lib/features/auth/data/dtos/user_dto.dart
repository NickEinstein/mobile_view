import 'package:vital_reg_mobile/core/network/json.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/user.dart';

/// Wire format, kept separate from the domain [User] so API changes don't
/// ripple into the UI. All validation happens here, at the boundary.
final class UserDto {
  const UserDto({
    required this.id,
    required this.fullName,
    required this.role,
    required this.login,
  });

  /// The `user` object of the backend's sign-in response. Null when the
  /// account's role isn't one this app serves.
  static UserDto? fromSignIn(Object? json) {
    final map = json.asJsonMap();
    final role = UserRole.fromRoleId(map['Role_ID']);
    if (role == null) return null;
    final id = map['User_ID'];
    if (id is! int && id is! String) {
      throw const FormatException('Expected "User_ID".');
    }
    String? text(String key) => switch (map[key]) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    final login = text('UserName') ?? text('Email') ?? text('Phone_No');
    if (login == null) throw const FormatException('Expected a user name.');
    final name = [
      text('First_Name') ?? text('Firstname'),
      text('Last_Name') ?? text('Surname'),
    ].nonNulls.join(' ');
    return UserDto(
      id: '$id',
      fullName: name.isEmpty ? login : name,
      role: role,
      login: login,
    );
  }

  /// The copy kept on the device (see [toJson]).
  factory UserDto.fromJson(Object? json) {
    final map = json.asJsonMap();
    final rawRole = map.requireString('role');
    final role = UserRole.tryParse(rawRole);
    if (role == null) throw FormatException('Unknown role "$rawRole".');
    return UserDto(
      id: map.requireString('id'),
      fullName: map.requireString('fullName'),
      role: role,
      login: map.requireString('login'),
    );
  }

  final String id;
  final String fullName;
  final UserRole role;

  /// What the backend knows the account by (user name, else email or
  /// phone). Sign-out sends it back.
  final String login;

  JsonMap toJson() => {
    'id': id,
    'fullName': fullName,
    'role': role.name,
    'login': login,
  };

  User toDomain() => User(id: id, fullName: fullName, role: role);
}
