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

  /// Unknown roles are rejected, never mapped to a default role.
  static UserRole? tryParse(String value) {
    for (final role in values) {
      if (role.name == value) return role;
    }
    return null;
  }
}
