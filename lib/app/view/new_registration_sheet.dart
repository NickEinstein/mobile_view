import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vital_reg_mobile/app/di/injector.dart';
import 'package:vital_reg_mobile/app/router/app_module.dart';
import 'package:vital_reg_mobile/core/feature_flags/feature_flags.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Services: slides up the "New registration" list, then opens the chosen
/// module full-screen (Back returns to where the user was).
Future<void> openNewRegistration(BuildContext context) async {
  final module = await showModalBottomSheet<AppModule>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const NewRegistrationSheet(),
  );
  if (module != null && context.mounted) context.go(module.path);
}

/// Lists the registration services this user may open AND that are enabled
/// in this build, in the designed order.
class NewRegistrationSheet extends StatelessWidget {
  const NewRegistrationSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final user = context.select(
      (AuthBloc bloc) => switch (bloc.state) {
        AuthAuthenticated(:final user) => user,
        AuthUnknown() || AuthUnauthenticated() => null,
      },
    );
    final featureFlags = getIt<FeatureFlags>();
    final modules = [
      for (final module in AppModule.newRegistration)
        if (user != null &&
            featureFlags.isEnabled(module.feature) &&
            user.can(module.permission))
          module,
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.lg,
          Spacing.lg,
          Spacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.newRegistrationTitle,
              style: textTheme.headlineSmall?.copyWith(
                color: AppPalette.inkStrong,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              l10n.newRegistrationSubtitle,
              style: textTheme.bodyLarge?.copyWith(color: AppPalette.ink),
            ),
            const SizedBox(height: Spacing.lg),
            if (modules.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                child: Text(l10n.noModulesAvailable),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: modules.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppPalette.cardBorder),
                  itemBuilder: (context, index) =>
                      _ServiceTile(module: modules[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final (icon, color) = module.visual;

    return InkWell(
      onTap: () => Navigator.of(context).pop(module),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm + Spacing.xs,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.1),
              child: AppIcon(icon, size: 22, color: color),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.title(l10n),
                    style: textTheme.titleMedium?.copyWith(
                      color: AppPalette.inkStrong,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    module.subtitle(l10n),
                    style: textTheme.bodySmall?.copyWith(
                      color: AppPalette.inkStrong,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppPalette.ink),
          ],
        ),
      ),
    );
  }
}

extension on AppModule {
  (AppIcons, Color) get visual => switch (this) {
    AppModule.birthRegistration => (AppIcons.user, AppPalette.accentGreen),
    AppModule.birthAttestation ||
    AppModule.modifications ||
    AppModule.foreignBirthNotification => (
      AppIcons.document,
      AppPalette.accentPurple,
    ),
    AppModule.stillBirthRegistration => (
      AppIcons.heart,
      AppPalette.accentYellow,
    ),
    AppModule.deathRegistration => (
      AppIcons.laurelWreath,
      AppPalette.accentBlue,
    ),
    AppModule.surrogacyBirthRegistration => (
      AppIcons.originHealth,
      AppPalette.accentTeal,
    ),
    AppModule.adoptedChildRegistration => (
      AppIcons.childProgram,
      AppPalette.accentRed,
    ),
    AppModule.singleParentBirthRegistration => (
      AppIcons.parent,
      AppPalette.accentPlum,
    ),
    AppModule.reissuance => (AppIcons.redo, AppPalette.accentGreen),
    AppModule.approvals ||
    AppModule.reports => (AppIcons.document, AppPalette.ink),
  };
}
