import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_draft.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_form.dart';
import 'package:vital_reg_mobile/features/birth_attestation/domain/entities/attestation_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// An attestation's answers as review cards, one per section: the form's
/// "Information Preview" (with Edit) and "Certificate Details" (without).
class AttestationSections extends StatelessWidget {
  const AttestationSections({
    required this.draft,
    required this.data,
    this.onEdit,
    this.isComplete,
    super.key,
  });

  final AttestationDraft draft;
  final AttestationReferenceData data;

  /// Null hides the Edit links.
  final ValueChanged<AttestationStep>? onEdit;

  /// Null marks every section complete.
  final bool Function(AttestationStep step)? isComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final draft = this.draft;
    final data = this.data;
    final onEdit = this.onEdit;

    String shown(String? value) => value ?? '-';
    String option(List<Option> options, String? id) =>
        shown(AttestationReferenceData.labelOf(options, id));
    String date(DateTime? value) =>
        value == null ? '-' : DateFormat.yMMMMd(locale).format(value);

    final a = draft.applicant;
    final b = draft.additional;
    Widget card(AttestationStep step, String title, List<Widget> rows) =>
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.md),
          child: AppReviewCard(
            title: title,
            rows: rows,
            incomplete: !(isComplete?.call(step) ?? true),
            editLabel: l10n.brEdit,
            onEdit: onEdit == null ? null : () => onEdit(step),
          ),
        );
    Widget status(String label, AttestationDocument document) =>
        AppReviewStatus(
          label,
          provided: draft.hasDocument(document),
          providedLabel: l10n.brProvided,
          notProvidedLabel: l10n.brNotProvided,
          detail: draft.documents[document]?.name,
        );

    List<Widget> parentRows(Parent parent) {
      final info = draft.parent(parent);
      return [
        AppReviewEntry(l10n.brSurname, shown(info[ParentInfoField.surname])),
        AppReviewEntry(
          l10n.brFirstName,
          shown(info[ParentInfoField.firstName]),
        ),
        if (parent == Parent.mother)
          AppReviewEntry(
            l10n.brMaidenName,
            shown(info[ParentInfoField.maidenName]),
          ),
        AppReviewEntry(
          l10n.brNationality,
          option(data.nationalityOptions, info[ParentInfoField.nationality]),
        ),
        if (info.needsPassport)
          status(l10n.baPassport, parent.passport)
        else ...[
          AppReviewEntry(
            l10n.brStateOfOrigin,
            option(data.stateOptions, info[ParentInfoField.stateOfOrigin]),
          ),
          AppReviewEntry(
            l10n.brLgaOfOrigin,
            option(
              data.lgasOf(info[ParentInfoField.stateOfOrigin]),
              info[ParentInfoField.lgaOfOrigin],
            ),
          ),
          AppReviewEntry(l10n.baTown, shown(info[ParentInfoField.town])),
        ],
      ];
    }

    final registrationState = b[AdditionalField.registrationState];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(AttestationStep.applicant, l10n.baStepApplicant, [
          AppReviewEntry(l10n.brSurname, shown(a[ApplicantField.surname])),
          AppReviewEntry(l10n.brFirstName, shown(a[ApplicantField.firstName])),
          AppReviewEntry(
            l10n.brMiddleName,
            shown(a[ApplicantField.middleName]),
          ),
          AppReviewEntry(l10n.brSex, option(data.sexes, a[ApplicantField.sex])),
          AppReviewEntry(l10n.brDateOfBirth, date(a.dateOfBirth)),
          AppReviewEntry(
            l10n.baMaritalStatus,
            option(data.maritalStatuses, a[ApplicantField.maritalStatus]),
          ),
          AppReviewEntry(
            l10n.brStateOfOrigin,
            option(data.stateOptions, a[ApplicantField.stateOfOrigin]),
          ),
          AppReviewEntry(
            l10n.brLgaOfOrigin,
            option(
              data.lgasOf(a[ApplicantField.stateOfOrigin]),
              a[ApplicantField.lgaOfOrigin],
            ),
          ),
          AppReviewEntry(
            l10n.baTownOfOrigin,
            shown(a[ApplicantField.townOfOrigin]),
          ),
          AppReviewEntry(
            l10n.baIdType,
            option(data.identityTypes, a[ApplicantField.idType]),
          ),
          AppReviewEntry(l10n.baIdNumber, shown(a[ApplicantField.idNumber])),
          AppReviewEntry(l10n.emailLabel, shown(a[ApplicantField.email])),
          AppReviewEntry(l10n.brPhoneNumber, shown(a[ApplicantField.phone])),
          if (draft.ninRecord?.nin ?? draft.queried?.nin case final nin?)
            AppReviewEntry(l10n.brNin, nin),
          AppReviewStatus(
            l10n.baApplicantFace,
            provided: draft.hasFace,
            providedLabel: l10n.brProvided,
            notProvidedLabel: l10n.brNotProvided,
            detail: draft.facePhoto == null ? null : l10n.baFaceFromValidation,
          ),
        ]),
        card(AttestationStep.additional, l10n.baStepAdditional, [
          AppReviewEntry(
            l10n.baPlaceOfBirth,
            option(data.placesOfBirth, b[AdditionalField.placeOfBirth]),
          ),
          AppReviewEntry(
            l10n.brStateOfBirth,
            option(data.stateOptions, b[AdditionalField.stateOfBirth]),
          ),
          AppReviewEntry(
            l10n.brLgaOfBirth,
            option(
              data.lgasOf(b[AdditionalField.stateOfBirth]),
              b[AdditionalField.lgaOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.brLocalityOfBirth,
            shown(b[AdditionalField.localityOfBirth]),
          ),
          // A record doesn't return where it was registered.
          if (registrationState != null) ...[
            AppReviewEntry(
              l10n.brRegistrationState,
              option(data.stateOptions, registrationState),
            ),
            AppReviewEntry(
              l10n.brRegistrationLga,
              option(
                data.lgasOf(registrationState),
                b[AdditionalField.registrationLga],
              ),
            ),
            AppReviewEntry(
              l10n.brRegistrationCenter,
              option(
                data.centersOf(
                  registrationState,
                  b[AdditionalField.registrationLga],
                ),
                b[AdditionalField.registrationCenter],
              ),
            ),
          ],
          AppReviewEntry(
            l10n.baCurrentAddress,
            shown(b[AdditionalField.currentAddress]),
          ),
          AppReviewEntry(
            l10n.baEducationLevel,
            option(data.educationLevels, b[AdditionalField.educationLevel]),
          ),
          AppReviewEntry(
            l10n.brOccupation,
            option(data.occupations, b[AdditionalField.occupation]),
          ),
          AppReviewEntry(
            l10n.baWorkAddress,
            shown(b[AdditionalField.workAddress]),
          ),
          AppReviewEntry(
            l10n.baRequestReason,
            option(data.requestReasons, b[AdditionalField.requestReason]),
          ),
          AppReviewEntry(
            l10n.baRequiredFor,
            option(data.requirements, b[AdditionalField.requiredFor]),
          ),
          if (b.applies(AdditionalField.requiredForCountry))
            AppReviewEntry(
              l10n.baRequiredForCountry,
              option(data.countries, b[AdditionalField.requiredForCountry]),
            ),
          AppReviewEntry(
            l10n.baRequesterAddress,
            shown(b[AdditionalField.requesterAddress]),
          ),
        ]),
        card(
          AttestationStep.parents,
          l10n.baMotherSection,
          parentRows(Parent.mother),
        ),
        card(
          AttestationStep.parents,
          l10n.baFatherSection,
          parentRows(Parent.father),
        ),
        card(AttestationStep.additional, l10n.brSupportingDocuments, [
          status(l10n.baAffidavit, AttestationDocument.affidavit),
          for (final parent in Parent.values)
            if (draft.parent(parent).needsPassport)
              status(
                parent == Parent.mother
                    ? l10n.baMotherPassport
                    : l10n.baFatherPassport,
                parent.passport,
              ),
        ]),
      ],
    );
  }
}
