import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/features/auth/domain/entities/permission.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/features/dashboard/presentation/view/dashboard_page.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Connects the signed-in user (auth feature) to the dashboard feature, so
/// neither feature imports the other.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final user = context.select(
      (AuthBloc bloc) => switch (bloc.state) {
        AuthAuthenticated(:final user) => user,
        AuthUnknown() || AuthUnauthenticated() => null,
      },
    );
    // Not signed in: the router is already redirecting.
    if (user == null) return const SizedBox.shrink();

    return DashboardPage(
      name: user.fullName,
      roleLabel: switch (user.role) {
        UserRole.registrar => l10n.roleRegistrar,
        UserRole.supervisor => l10n.roleSupervisor,
        UserRole.auditor => l10n.roleAuditor,
      },
    );
  }
}
