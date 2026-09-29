import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';

/// White rounded card used for all dialogs in the designs.
class AppDialog extends StatelessWidget {
  const AppDialog({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// Green title, centred message and one action, e.g. "Verification
/// Successful → Proceed".
class AppStatusDialog extends StatelessWidget {
  const AppStatusDialog({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AppDialog(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          size: 56,
          color: AppPalette.brand,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: textTheme.titleLarge?.copyWith(
            color: AppPalette.brand,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppPalette.ink),
        ),
        const SizedBox(height: Spacing.lg),
        AppButton(label: actionLabel, onPressed: onAction),
      ],
    );
  }
}
