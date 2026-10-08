import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/attestation_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// An attestation reissuance request by section (with "Edit" on the
/// preview).
class AttestationReissuanceSections extends StatelessWidget {
  const AttestationReissuanceSections({
    required this.certificate,
    required this.form,
    required this.options,
    required this.nigeria,
    required this.lgasOf,
    required this.today,
    this.face,
    this.onEdit,
    this.showErrors = false,
    super.key,
  });

  final CertificateFacts certificate;
  final AttestationReissuanceForm form;
  final ReissuanceOptions options;

  /// Nigeria's states, and a state's LGAs as loaded so far.
  final List<Option> nigeria;
  final List<Option> Function(String? stateId) lgasOf;

  /// For the age check that marks the applicant incomplete.
  final DateTime today;
  final ImageProvider? face;

  /// Null hides the "Edit" links.
  final ValueChanged<AttestationReissuanceStep>? onEdit;

  /// Outlines incomplete sections in red.
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    String date(DateTime? value) =>
        value == null ? '–' : DateFormat('dd/MM/yyyy', locale).format(value);
    String text(String? value) => value ?? '–';
    String pick(List<Option> options, String? id) {
      for (final option in options) {
        if (option.id == id) return option.label;
      }
      return '–';
    }

    final onEdit = this.onEdit;
    VoidCallback? edit(AttestationReissuanceStep step) =>
        onEdit == null ? null : () => onEdit(step);
    bool incomplete(AttestationReissuanceStep step) =>
        showErrors && !form.isComplete(step, today: today);
    final applicant = form.applicant;
    final additional = form.additional;

    List<Widget> parentRows(ParentRole role) {
      final parent = form.parent(role);
      return [
        AppReviewSubheading(
          role == ParentRole.mother
              ? l10n.baMotherSection
              : l10n.baFatherSection,
        ),
        AppReviewEntry(
          l10n.brSurname,
          text(parent[AttestationParentDetail.surname]),
        ),
        AppReviewEntry(
          l10n.brFirstName,
          text(parent[AttestationParentDetail.firstName]),
        ),
        if (role == ParentRole.mother)
          AppReviewEntry(
            l10n.brMaidenName,
            text(parent[AttestationParentDetail.maidenName]),
          ),
        AppReviewEntry(
          l10n.brStateOfOrigin,
          pick(nigeria, parent[AttestationParentDetail.state]),
        ),
        AppReviewEntry(
          l10n.brLgaOfOrigin,
          pick(
            lgasOf(parent[AttestationParentDetail.state]),
            parent[AttestationParentDetail.lga],
          ),
        ),
        AppReviewEntry(l10n.baTown, text(parent[AttestationParentDetail.town])),
      ];
    }

    final cards = <Widget>[
      AppReviewCard(
        title: l10n.crReviewCertificate,
        rows: [
          AppReviewEntry(
            l10n.crCertificateType,
            certificate.kind.certificate(l10n),
          ),
          AppReviewEntry(l10n.crCertificateNumber, certificate.number),
          AppReviewEntry(l10n.crIssuedDate, date(certificate.issuedOn)),
          AppReviewEntry(l10n.crNinLabelShort, certificate.nin),
        ],
      ),
      AppReviewCard(
        title: l10n.baStepApplicant,
        incomplete: incomplete(AttestationReissuanceStep.applicant),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(AttestationReissuanceStep.applicant),
        rows: [
          if (face case final face?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image(
                  image: face,
                  height: 180,
                  fit: BoxFit.cover,
                  semanticLabel: l10n.baApplicantFace,
                  // Missing in tests and if the file was cleared.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          AppReviewEntry(
            l10n.brSurname,
            text(applicant[ApplicantDetail.surname]),
          ),
          AppReviewEntry(
            l10n.brFirstName,
            text(applicant[ApplicantDetail.firstName]),
          ),
          AppReviewEntry(
            l10n.brMiddleName,
            text(applicant[ApplicantDetail.middleName]),
          ),
          AppReviewEntry(
            l10n.brSex,
            pick(options.sexes, applicant[ApplicantDetail.sex]),
          ),
          AppReviewEntry(l10n.brDateOfBirth, date(applicant.dateOfBirth)),
          AppReviewEntry(
            l10n.baMaritalStatus,
            pick(
              options.maritalStatuses,
              applicant[ApplicantDetail.maritalStatus],
            ),
          ),
          AppReviewEntry(
            l10n.brStateOfOrigin,
            pick(nigeria, applicant[ApplicantDetail.stateOfOrigin]),
          ),
          AppReviewEntry(
            l10n.brLgaOfOrigin,
            pick(
              lgasOf(applicant[ApplicantDetail.stateOfOrigin]),
              applicant[ApplicantDetail.lgaOfOrigin],
            ),
          ),
          AppReviewEntry(
            l10n.baTownOfOrigin,
            text(applicant[ApplicantDetail.town]),
          ),
          AppReviewEntry(
            l10n.baIdType,
            pick(options.identityTypes, applicant[ApplicantDetail.idType]),
          ),
          AppReviewEntry(
            l10n.baIdNumber,
            text(applicant[ApplicantDetail.idNumber]),
          ),
          AppReviewEntry(
            l10n.crApplicantEmail,
            text(applicant[ApplicantDetail.email]),
          ),
          AppReviewEntry(
            l10n.brPhoneNumber,
            text(applicant[ApplicantDetail.phone]),
          ),
        ],
      ),
      AppReviewCard(
        title: l10n.baStepAdditional,
        incomplete: incomplete(AttestationReissuanceStep.additional),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(AttestationReissuanceStep.additional),
        rows: [
          AppReviewEntry(
            l10n.baPlaceOfBirth,
            pick(
              options.placesOfOccurrence,
              additional[AdditionalDetail.placeOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.brTypeOfBirth,
            pick(
              options.typesOfBirth,
              additional[AdditionalDetail.typeOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.brStateOfBirth,
            pick(nigeria, additional[AdditionalDetail.stateOfBirth]),
          ),
          AppReviewEntry(
            l10n.brLgaOfBirth,
            pick(
              lgasOf(additional[AdditionalDetail.stateOfBirth]),
              additional[AdditionalDetail.lgaOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.brLocalityOfBirth,
            text(additional[AdditionalDetail.townOfBirth]),
          ),
          AppReviewEntry(
            l10n.brRegistrationState,
            pick(nigeria, additional[AdditionalDetail.registrationState]),
          ),
          AppReviewEntry(
            l10n.brRegistrationLga,
            pick(
              lgasOf(additional[AdditionalDetail.registrationState]),
              additional[AdditionalDetail.registrationLga],
            ),
          ),
          AppReviewEntry(
            l10n.brRegistrationCenter,
            pick(
              options.centresIn(additional[AdditionalDetail.registrationLga]),
              additional[AdditionalDetail.registrationCenter],
            ),
          ),
          AppReviewEntry(
            l10n.baCurrentAddress,
            text(additional[AdditionalDetail.currentAddress]),
          ),
          AppReviewEntry(
            l10n.baEducationLevel,
            pick(
              options.educationLevels,
              additional[AdditionalDetail.educationLevel],
            ),
          ),
          AppReviewEntry(
            l10n.brOccupation,
            pick(options.occupations, additional[AdditionalDetail.occupation]),
          ),
          AppReviewEntry(
            l10n.baWorkAddress,
            text(additional[AdditionalDetail.workAddress]),
          ),
          AppReviewEntry(
            l10n.baRequestReason,
            pick(
              options.requestReasons,
              additional[AdditionalDetail.requestReason],
            ),
          ),
          AppReviewEntry(
            l10n.baRequiredFor,
            pick(
              options.requirements,
              additional[AdditionalDetail.requiredFor],
            ),
          ),
          if (additional.applies(AdditionalDetail.country))
            AppReviewEntry(
              l10n.baRequiredForCountry,
              pick(options.countries, additional[AdditionalDetail.country]),
            ),
          AppReviewEntry(
            l10n.baRequesterAddress,
            text(additional[AdditionalDetail.requesterAddress]),
          ),
        ],
      ),
      AppReviewCard(
        title: l10n.baStepParents,
        incomplete: incomplete(AttestationReissuanceStep.parents),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(AttestationReissuanceStep.parents),
        rows: [
          ...parentRows(ParentRole.father),
          ...parentRows(ParentRole.mother),
        ],
      ),
      AppReviewCard(
        title: l10n.crStepDocuments,
        incomplete: incomplete(AttestationReissuanceStep.documents),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(AttestationReissuanceStep.documents),
        rows: [
          AppReviewStatus(
            l10n.baAffidavit,
            provided: form.hasAffidavit,
            providedLabel: l10n.brProvided,
            notProvidedLabel: l10n.brNotProvided,
            detail: form.affidavit?.name,
          ),
          AppReviewStatus(
            l10n.crApplicantSignature,
            provided: form.hasSignature,
            providedLabel: l10n.brProvided,
            notProvidedLabel: l10n.brNotProvided,
          ),
        ],
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, card) in cards.indexed) ...[
          if (i > 0) const SizedBox(height: Spacing.md),
          card,
        ],
      ],
    );
  }
}
