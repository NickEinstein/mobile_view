import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_reg_mobile/app/di/injector.dart';
import 'package:vital_reg_mobile/app/router/app_module.dart';
import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// One home screen for every role. It lists only the modules this user may
/// open AND that are enabled in this build.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

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

    final featureFlags = getIt<FeatureFlags>();
    final modules = [
      for (final module in AppModule.values)
        if (featureFlags.isEnabled(module.feature) &&
            user.can(module.permission))
          module,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.homeGreeting(user.fullName)),
        actions: [
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthLogoutRequested()),
          ),
        ],
      ),
      body: modules.isEmpty
          ? Center(child: Text(l10n.noModulesAvailable))
          : ListView.separated(
              padding: const EdgeInsets.all(Spacing.md),
              itemCount: modules.length,
              separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
              itemBuilder: (context, index) {
                final module = modules[index];
                return Card(
                  child: ListTile(
                    title: Text(module.title(l10n)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(module.path),
                  ),
                );
              },
            ),
    );
  }
}
