import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_button.dart';
import 'package:vital_reg_mobile/design_system/widgets/app_dialog.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// "NOTICE" after payment: the particulars must come from the court
/// order.
Future<void> showSurrogacyNoticeDialog(BuildContext context) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        final textTheme = Theme.of(dialogContext).textTheme;
        return PopScope(
          canPop: false,
          child: AppDialog(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(dialogContext).colorScheme.error,
                size: 28,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.srNoticeTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: AppPalette.inkStrong,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                l10n.srNoticeMessage,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
              ),
              const SizedBox(height: Spacing.lg),
              AppButton(
                label: l10n.brProceed,
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
        );
      },
    );
