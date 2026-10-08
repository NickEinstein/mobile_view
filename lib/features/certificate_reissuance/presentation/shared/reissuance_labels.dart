import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_draft.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_summary.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

extension ReissuanceKindLabels on ReissuanceKind {
  String tab(AppLocalizations l10n) => switch (this) {
    ReissuanceKind.birth => l10n.crTabBirth,
    ReissuanceKind.attestation => l10n.crTabAttestation,
  };

  String certificate(AppLocalizations l10n) => switch (this) {
    ReissuanceKind.birth => l10n.crBirthCertificate,
    ReissuanceKind.attestation => l10n.crAttestationCertificate,
  };
}

/// Stat card icon and colour, and labels, per card; null is "Total". As
/// Birth Registration draws its cards.
extension ReissuanceStatusStyle on ReissuanceStatus? {
  (AppIcons, Color) get visual => switch (this) {
    null => (AppIcons.birthRegistration, AppPalette.accentBlue),
    ReissuanceStatus.pending => (
      AppIcons.deathRegistration,
      AppPalette.accentYellow,
    ),
    ReissuanceStatus.approved => (
      AppIcons.birthAttestation,
      AppPalette.accentGreen,
    ),
    ReissuanceStatus.queried => (AppIcons.stillBirth, AppPalette.accentRed),
  };

  String cardLabel(AppLocalizations l10n) => switch (this) {
    null => l10n.crStatusTotal,
    ReissuanceStatus.pending => l10n.crStatusPending,
    ReissuanceStatus.approved => l10n.crStatusApproved,
    ReissuanceStatus.queried => l10n.crStatusQueried,
  };
}

extension ValidationModeLabels on ValidationMode {
  String label(AppLocalizations l10n) => switch (this) {
    ValidationMode.nin => l10n.crModeNin,
    ValidationMode.vitalRegPro => l10n.crModeVitalRegPro,
    ValidationMode.legacyCertificate => l10n.crModeLegacyCertificate,
  };
}

/// A small tinted label such as "Approved".
class ReissuanceStatusChip extends StatelessWidget {
  const ReissuanceStatusChip({required this.status, super.key});

  final ReissuanceStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = (status as ReissuanceStatus?).visual.$2;
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
          switch (status) {
            ReissuanceStatus.pending => l10n.brChipPending,
            ReissuanceStatus.approved => l10n.brChipApproved,
            ReissuanceStatus.queried => l10n.brChipQueried,
          },
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
        ),
      ),
    );
  }
}
