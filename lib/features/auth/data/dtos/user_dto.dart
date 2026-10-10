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
    this.stateId,
    this.lgaId,
    this.userName,
    this.email,
    this.phone,
    this.roleName,
    this.centreName,
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
    String? textOf(Object? value) => switch (value) {
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    String? text(String key) => textOf(map[key]);
    // Joined records: the role (`roles`) and centre (`Registration_Centres`).
    String? joined(String record, String key) => switch (map[record]) {
      final Map<String, Object?> joined => textOf(joined[key]),
      _ => null,
    };
    final login = text('UserName') ?? text('Email') ?? text('Phone_No');
    if (login == null) throw const FormatException('Expected a user name.');
    final name = [
      text('First_Name') ?? text('Firstname'),
      text('Last_Name') ?? text('Surname'),
    ].nonNulls.join(' ');
    String? optionalId(String key) => switch (map[key]) {
      final int value => '$value',
      final String value when value.trim().isNotEmpty => value.trim(),
      _ => null,
    };
    return UserDto(
      id: '$id',
      fullName: name.isEmpty ? login : name,
      role: role,
      login: login,
      stateId: optionalId('State_ID'),
      lgaId: optionalId('LGA_ID'),
      userName: text('UserName'),
      email: text('Email'),
      phone: text('Phone_No'),
      roleName: joined('roles', 'name') ?? text('RoleName'),
      centreName: joined('Registration_Centres', 'Reg_Center_Name'),
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
      // Absent from copies saved before they were kept.
      stateId: map['stateId'] as String?,
      lgaId: map['lgaId'] as String?,
      userName: map['userName'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      roleName: map['roleName'] as String?,
      centreName: map['centreName'] as String?,
    );
  }

  final String id;
  final String fullName;
  final UserRole role;

  /// What the backend knows the account by (user name, else email or
  /// phone). Sign-out sends it back.
  final String login;

  /// The account's `State_ID` and `LGA_ID`.
  final String? stateId;
  final String? lgaId;

  /// For the profile.
  final String? userName;
  final String? email;
  final String? phone;
  final String? roleName;
  final String? centreName;

  JsonMap toJson() => {
    'id': id,
    'fullName': fullName,
    'role': role.name,
    'login': login,
    'stateId': ?stateId,
    'lgaId': ?lgaId,
    'userName': ?userName,
    'email': ?email,
    'phone': ?phone,
    'roleName': ?roleName,
    'centreName': ?centreName,
  };

  User toDomain() => User(
    id: id,
    fullName: fullName,
    role: role,
    stateId: stateId,
    lgaId: lgaId,
    userName: userName,
    email: email,
    phone: phone,
    roleName: roleName,
    centreName: centreName,
  );
}
