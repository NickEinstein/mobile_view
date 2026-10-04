import 'package:flutter/material.dart';
import 'package:vital_reg_mobile/design_system/icons/app_icons.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_options.dart';
import 'package:vital_reg_mobile/features/modifications/domain/entities/modification_summary.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

extension ModificationKindLabels on ModificationKind {
  /// "Birth Modifications": the card label and the request screen title.
  String title(AppLocalizations l10n) => switch (this) {
    ModificationKind.birth => l10n.modKindBirth,
    ModificationKind.attestation => l10n.modKindAttestation,
    ModificationKind.death => l10n.modKindDeath,
  };

  (AppIcons, Color) get visual => switch (this) {
    ModificationKind.birth => (
      AppIcons.birthRegistration,
      AppPalette.accentBlue,
    ),
    ModificationKind.attestation => (
      AppIcons.birthAttestation,
      AppPalette.accentGreen,
    ),
    ModificationKind.death => (
      AppIcons.deathRegistration,
      AppPalette.accentYellow,
    ),
  };
}

extension ModificationTypeLabel on ModificationType {
  String label(AppLocalizations l10n) => switch (this) {
    ModificationType.childParticulars => l10n.modTypeChildParticulars,
    ModificationType.applicantParticulars => l10n.modTypeApplicantParticulars,
    ModificationType.motherName ||
    ModificationType.applicantMotherName => l10n.modTypeMotherName,
    ModificationType.fatherName ||
    ModificationType.applicantFatherName => l10n.modTypeFatherName,
    ModificationType.deceasedName => l10n.modTypeDeceasedName,
    ModificationType.deceasedSex => l10n.modTypeDeceasedSex,
    ModificationType.deceasedAgeAtDeath => l10n.modTypeDeceasedAgeAtDeath,
    ModificationType.deceasedDateOfDeath => l10n.modTypeDeceasedDateOfDeath,
  };
}

extension ModificationFieldLabel on ModificationField {
  String label(AppLocalizations l10n) => switch (this) {
    ModificationField.childName ||
    ModificationField.applicantName => l10n.modFieldName,
    ModificationField.childDateOfBirth ||
    ModificationField.applicantDateOfBirth => l10n.modFieldDateOfBirth,
    ModificationField.childSex ||
    ModificationField.applicantSex => l10n.modFieldSex,
    ModificationField.childPlaceOfBirth ||
    ModificationField.applicantPlaceOfBirth => l10n.modFieldPlaceOfBirth,
    ModificationField.applicantStateOfOrigin => l10n.modFieldStateOfOrigin,
  };
}

extension ModificationReasonLabel on ModificationReason {
  String label(AppLocalizations l10n) => switch (this) {
    ModificationReason.incorrectAge => l10n.modReasonIncorrectAge,
    ModificationReason.misspelledName => l10n.modReasonMisspelledName,
    ModificationReason.switchedNameOrder => l10n.modReasonSwitchedNameOrder,
    ModificationReason.changeOfSex => l10n.modReasonChangeOfSex,
    ModificationReason.incorrectPlaceOfBirth =>
      l10n.modReasonIncorrectPlaceOfBirth,
    ModificationReason.wrongStateOfBirth => l10n.modReasonWrongStateOfBirth,
    ModificationReason.incorrectStateOfOrigin =>
      l10n.modReasonIncorrectStateOfOrigin,
    ModificationReason.incorrectAgeAtDeath => l10n.modReasonIncorrectAgeAtDeath,
    ModificationReason.incorrectDateOfDeath =>
      l10n.modReasonIncorrectDateOfDeath,
  };
}

extension ModificationStatusStyle on ModificationStatus {
  String label(AppLocalizations l10n) => switch (this) {
    ModificationStatus.pending => l10n.modStatusPending,
    ModificationStatus.approved => l10n.modStatusApproved,
    ModificationStatus.queried => l10n.modStatusQueried,
  };

  Color get color => switch (this) {
    ModificationStatus.pending => AppPalette.accentYellow,
    ModificationStatus.approved => AppPalette.accentGreen,
    ModificationStatus.queried => AppPalette.accentRed,
  };
}

/// A small tinted label such as "Pending".
class ModificationStatusChip extends StatelessWidget {
  const ModificationStatusChip({required this.status, super.key});

  final ModificationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status.color;
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
          status.label(context.l10n),
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color, fontSize: 9),
        ),
      ),
    );
  }
}
