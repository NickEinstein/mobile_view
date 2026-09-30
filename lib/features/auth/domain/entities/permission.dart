/// Capabilities, not screens: one screen adapts to what the user may do.
enum Permission {
  registerBirth,
  registerDeath,
  modifyRecords,
  reissueCertificates,
  approveRecords,
  viewReports,
}

/// The roles this app serves. Client checks are only for UX.
enum UserRole {
  registrar({
    Permission.registerBirth,
    Permission.registerDeath,
    Permission.modifyRecords,
    Permission.reissueCertificates,
  }),
  supervisor({
    Permission.registerBirth,
    Permission.registerDeath,
    Permission.modifyRecords,
    Permission.reissueCertificates,
    Permission.approveRecords,
    Permission.viewReports,
  }),
  auditor({Permission.viewReports});

  const UserRole(this.permissions);

  final Set<Permission> permissions;

  /// The role for `Role_ID`: registrars (3), sub-registrars (4) and
  /// hospitals (7); null for roles this app doesn't serve.
  static UserRole? fromRoleId(Object? roleId) => switch ('$roleId') {
    '3' || '4' || '7' => registrar,
    _ => null,
  };

  /// Unknown roles are rejected, never mapped to a default role.
  static UserRole? tryParse(String value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
