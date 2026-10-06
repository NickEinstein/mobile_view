import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/app_palette.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_form.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/birth_reissuance_record.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/domain/entities/reissuance_options.dart';
import 'package:vital_reg_mobile/features/certificate_reissuance/presentation/shared/reissuance_labels.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// A birth reissuance request by section (with "Edit" on the preview).
class BirthReissuanceSections extends StatelessWidget {
  const BirthReissuanceSections({
    required this.certificate,
    required this.form,
    required this.options,
    required this.statesOf,
    required this.lgasOf,
    this.face,
    this.onEdit,
    this.showErrors = false,
    super.key,
  });

  final CertificateFacts certificate;
  final BirthReissuanceForm form;
  final ReissuanceOptions options;

  /// A country's states and a state's LGAs, as loaded so far.
  final List<Option> Function(String? countryCode) statesOf;
  final List<Option> Function(String? stateId) lgasOf;

  /// The child's face photo, if there is one to show.
  final ImageProvider? face;

  /// Null hides the "Edit" links.
  final ValueChanged<BirthReissuanceStep>? onEdit;

  /// Outlines incomplete sections in red.
  final bool showErrors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final child = form.child;
    final onEdit = this.onEdit;
    VoidCallback? edit(BirthReissuanceStep step) =>
        onEdit == null ? null : () => onEdit(step);
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

    final nigeria = statesOf(ReissuanceCodes.nigeria);

    Widget parentCard(ParentRole role) {
      final p = form.parent(role);
      final isMother = role == ParentRole.mother;
      final step = isMother
          ? BirthReissuanceStep.mother
          : BirthReissuanceStep.father;
      String? shown(ParentDetail field, String value) =>
          p.applies(field, role) ? value : null;
      return AppReviewCard(
        title: isMother ? l10n.brStepMother : l10n.brStepFather,
        incomplete: showErrors && !form.isComplete(step),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(step),
        rows: [
          AppReviewEntry(l10n.brSurname, text(p[ParentDetail.surname])),
          AppReviewEntry(l10n.brFirstName, text(p[ParentDetail.firstName])),
          if (isMother)
            AppReviewEntry(l10n.brMaidenName, text(p[ParentDetail.maidenName])),
          AppReviewSubheading(l10n.crPlaceOfUsualResidence),
          AppReviewEntry(
            l10n.brCountry,
            pick(options.countries, p[ParentDetail.country]),
          ),
          AppReviewEntry(
            l10n.brState,
            pick(statesOf(p[ParentDetail.country]), p[ParentDetail.state]),
          ),
          if (shown(
                ParentDetail.lga,
                pick(lgasOf(p[ParentDetail.state]), p[ParentDetail.lga]),
              )
              case final lga?)
            AppReviewEntry(l10n.brLga, lga),
          AppReviewEntry(l10n.brAddress, text(p[ParentDetail.address])),
          AppReviewEntry(
            isMother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
            text(p[ParentDetail.age]),
          ),
          AppReviewEntry(
            l10n.brMaritalStatus,
            pick(options.maritalStatuses, p[ParentDetail.maritalStatus]),
          ),
          AppReviewEntry(
            l10n.brNationality,
            pick(options.nationalities, p[ParentDetail.nationality]),
          ),
          AppReviewEntry(
            l10n.brStateOfOrigin,
            pick(
              statesOf(p[ParentDetail.nationality]),
              p[ParentDetail.stateOfOrigin],
            ),
          ),
          if (shown(
                ParentDetail.lgaOfOrigin,
                pick(
                  lgasOf(p[ParentDetail.stateOfOrigin]),
                  p[ParentDetail.lgaOfOrigin],
                ),
              )
              case final lga?)
            AppReviewEntry(l10n.brLgaOfOrigin, lga),
          AppReviewEntry(
            l10n.brEthnicGroup,
            pick(options.ethnicGroups, p[ParentDetail.ethnicGroup]),
          ),
          AppReviewEntry(
            l10n.brLiteracy,
            pick(options.literacyLevels, p[ParentDetail.literacy]),
          ),
          if (shown(
                ParentDetail.educationLevel,
                pick(options.educationLevels, p[ParentDetail.educationLevel]),
              )
              case final level?)
            AppReviewEntry(l10n.brEducationLevel, level),
          AppReviewEntry(
            l10n.brOccupation,
            pick(options.occupations, p[ParentDetail.occupation]),
          ),
          AppReviewEntry(l10n.brPhoneNumber, text(p[ParentDetail.phone])),
        ],
      );
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
        title: l10n.brStepChild,
        incomplete: showErrors && !form.isComplete(BirthReissuanceStep.child),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(BirthReissuanceStep.child),
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
                  semanticLabel: l10n.crChildFace,
                  // Missing in tests and if the file was cleared.
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          AppReviewEntry(l10n.brSurname, text(child[ChildField.surname])),
          AppReviewEntry(l10n.brFirstName, text(child[ChildField.firstName])),
          AppReviewEntry(l10n.brMiddleName, text(child[ChildField.middleName])),
          AppReviewEntry(l10n.brDateOfBirth, date(child.dateOfBirth)),
          AppReviewEntry(
            l10n.brTypeOfBirth,
            pick(options.typesOfBirth, child[ChildField.typeOfBirth]),
          ),
          AppReviewEntry(
            l10n.brBirthOrder,
            pick(options.birthOrders, child[ChildField.birthOrder]),
          ),
          AppReviewEntry(
            l10n.brSex,
            pick(options.sexes, child[ChildField.sex]),
          ),
          AppReviewEntry(
            l10n.brPlaceOfOccurrence,
            pick(
              options.placesOfOccurrence,
              child[ChildField.placeOfOccurrence],
            ),
          ),
          AppReviewEntry(
            l10n.brStateOfBirth,
            pick(nigeria, child[ChildField.stateOfBirth]),
          ),
          AppReviewEntry(
            l10n.brLgaOfBirth,
            pick(
              lgasOf(child[ChildField.stateOfBirth]),
              child[ChildField.lgaOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.brLocalityOfBirth,
            text(child[ChildField.townOfBirth]),
          ),
          AppReviewEntry(
            l10n.brTownOfOrigin,
            text(child[ChildField.townOfOrigin]),
          ),
          AppReviewEntry(
            l10n.brLocalityType,
            pick(options.localityTypes, child[ChildField.locality]),
          ),
          AppReviewEntry(
            l10n.brRegistrationState,
            pick(nigeria, child[ChildField.registrationState]),
          ),
          AppReviewEntry(
            l10n.brRegistrationLga,
            pick(
              lgasOf(child[ChildField.registrationState]),
              child[ChildField.registrationLga],
            ),
          ),
          AppReviewEntry(
            l10n.brRegistrationCenter,
            pick(
              options.centresIn(child[ChildField.registrationLga]),
              child[ChildField.registrationCenter],
            ),
          ),
        ],
      ),
      parentCard(ParentRole.mother),
      parentCard(ParentRole.father),
      AppReviewCard(
        title: l10n.crStepDocuments,
        incomplete:
            showErrors && !form.isComplete(BirthReissuanceStep.documents),
        editLabel: onEdit == null ? null : l10n.brEdit,
        onEdit: edit(BirthReissuanceStep.documents),
        rows: [
          AppReviewStatus(
            l10n.crSupportingDocument,
            provided: form.hasDocument,
            providedLabel: l10n.brProvided,
            notProvidedLabel: l10n.brNotProvided,
            detail: form.document?.name,
          ),
          AppReviewStatus(
            l10n.crParentSignature,
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

/// "This request was queried", with the approver's title and reason, in
/// red as the designs mark a query.
class ReissuanceQueryNote extends StatelessWidget {
  const ReissuanceQueryNote({required this.query, super.key});

  final ReissuanceQuery query;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final error = Theme.of(context).colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: error.withValues(alpha: 0.06),
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              query.title ?? l10n.crQueryTitle,
              style: textTheme.titleSmall?.copyWith(
                color: error,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (query.reason case final reason?) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                '${l10n.crQueryReason}: $reason',
                style: textTheme.bodySmall?.copyWith(color: AppPalette.ink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
