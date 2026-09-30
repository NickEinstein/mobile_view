import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Full-screen side menu from the designs.
class AppDrawer extends StatelessWidget {
  const AppDrawer({required this.onHome, required this.onServices, super.key});

  final VoidCallback onHome;
  final VoidCallback onServices;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final itemStyle = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(color: AppPalette.inkStrong);

    void closeThen(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    return Drawer(
      width: MediaQuery.sizeOf(context).width,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const SizedBox(width: Spacing.sm),
                  Image.asset(
                    'assets/images/branding/logo_full.png',
                    height: 22,
                    semanticLabel: l10n.appTitle,
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: l10n.closeMenu,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.xl),
              ListTile(
                title: Text(l10n.navHome, style: itemStyle),
                onTap: () => closeThen(onHome),
              ),
              ListTile(
                title: Text(l10n.navServices, style: itemStyle),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => closeThen(onServices),
              ),
              const SizedBox(height: Spacing.xl * 2),
              ListTile(
                title: Text(
                  l10n.logOut,
                  style: itemStyle?.copyWith(color: AppPalette.danger),
                ),
                trailing: const AppIcon(
                  AppIcons.logOut,
                  color: AppPalette.danger,
                ),
                onTap: () async {
                  // Logging out deletes this user's drafts, so confirm.
                  if (!await _confirmLogOut(context) || !context.mounted) {
                    return;
                  }
                  closeThen(
                    () => context.read<AuthBloc>().add(
                      const AuthLogoutRequested(),
                    ),
                  );
                },
              ),
              const SizedBox(height: Spacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _confirmLogOut(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.logOutConfirmTitle),
      content: Text(l10n.logOutConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.logOutCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppPalette.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.logOut),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
