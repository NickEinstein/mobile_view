import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/birth_application.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// How each status looks: stat card icon and colour, and its labels.
extension ApplicationStatusStyle on ApplicationStatus {
  (AppIcons, Color) get visual => switch (this) {
    ApplicationStatus.pending => (
      AppIcons.birthRegistration,
      AppPalette.accentBlue,
    ),
    ApplicationStatus.approved => (
      AppIcons.birthAttestation,
      AppPalette.accentGreen,
    ),
    ApplicationStatus.printed => (
      AppIcons.deathRegistration,
      AppPalette.accentYellow,
    ),
    ApplicationStatus.queried => (AppIcons.stillBirth, AppPalette.accentRed),
  };

  String cardLabel(AppLocalizations l10n) => switch (this) {
    ApplicationStatus.pending => l10n.brStatusPending,
    ApplicationStatus.approved => l10n.brStatusApproved,
    ApplicationStatus.printed => l10n.brStatusPrinted,
    ApplicationStatus.queried => l10n.brStatusQueried,
  };

  String chipLabel(AppLocalizations l10n) => switch (this) {
    ApplicationStatus.pending => l10n.brChipPending,
    ApplicationStatus.approved => l10n.brChipApproved,
    ApplicationStatus.printed => l10n.brChipPrinted,
    ApplicationStatus.queried => l10n.brChipQueried,
  };
}

/// A small tinted label such as "Approved".
class StatusChip extends StatelessWidget {
  const StatusChip({required this.status, this.fontSize = 9, super.key});

  final ApplicationStatus status;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final color = status.visual.$2;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(Spacing.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs + 2,
          vertical: 1,
        ),
        child: Text(
          status.chipLabel(context.l10n),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: fontSize),
        ),
      ),
    );
  }
}
