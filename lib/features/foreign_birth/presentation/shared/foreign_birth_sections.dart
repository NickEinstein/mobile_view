import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_draft.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_form.dart';
import 'package:vital_reg_mobile/features/foreign_birth/domain/entities/foreign_birth_reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Every section of a foreign birth notification as cards: the form's
/// review (with Edit) and, later, its details (read-only).
class ForeignBirthSections extends StatelessWidget {
  const ForeignBirthSections({
    required this.draft,
    required this.data,
    required this.stateName,
    required this.lgaName,
    this.onEdit,
    this.isIncomplete,
    super.key,
  });

  final ForeignBirthDraft draft;
  final ForeignBirthReferenceData data;

  /// A state's name, from its country's places loaded so far.
  final String? Function(String? countryId, String? stateId) stateName;

  /// A Nigerian LGA's name.
  final String? Function(String? stateId, String? lgaId) lgaName;

  /// Null hides the Edit links.
  final void Function(ForeignBirthStep step)? onEdit;

  /// Outlines a section in red.
  final bool Function(ForeignBirthStep step)? isIncomplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();

    String text(String? value) => value ?? '-';
    String option(List<Option> options, String? id) {
      for (final o in options) {
        if (o.id == id) return o.label;
      }
      return text(id);
    }

    String date(DateTime? value) =>
        value == null ? '-' : DateFormat.yMMMMd(locale).format(value);

    Widget card(ForeignBirthStep step, String title, List<Widget> rows) =>
        AppReviewCard(
          title: title,
          rows: rows,
          incomplete: isIncomplete?.call(step) ?? false,
          editLabel: onEdit == null ? null : l10n.brEdit,
          onEdit: onEdit == null ? null : () => onEdit!(step),
        );

    Widget status(String label, {required bool provided, String? detail}) =>
        AppReviewStatus(
          label,
          provided: provided,
          providedLabel: l10n.brProvided,
          notProvidedLabel: l10n.brNotProvided,
          detail: detail,
        );

    final child = draft.child;
    final informant = draft.informant;

    List<Widget> parentRows(Parent parent) {
      final p = draft.parent(parent);
      return [
        AppReviewEntry(l10n.srNinLabel, text(p[ParentField.nin])),
        AppReviewEntry(l10n.brSurname, text(p[ParentField.surname])),
        AppReviewEntry(l10n.brFirstName, text(p[ParentField.firstName])),
        AppReviewEntry(l10n.brMiddleName, text(p[ParentField.middleName])),
        if (p.applies(ParentField.maidenName, parent))
          AppReviewEntry(l10n.brMaidenName, text(p[ParentField.maidenName])),
        AppReviewEntry(
          l10n.brMaritalStatus,
          option(data.maritalStatuses, p[ParentField.maritalStatus]),
        ),
        AppReviewEntry(
          parent == Parent.mother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
          text(p[ParentField.age]),
        ),
        AppReviewEntry(
          l10n.brNationality,
          option(data.nationalities, p[ParentField.nationality]),
        ),
        AppReviewEntry(
          l10n.fbStateOfOrigin,
          text(
            stateName(p[ParentField.nationality], p[ParentField.stateOfOrigin]),
          ),
        ),
        if (p.applies(ParentField.lgaOfOrigin, parent)) ...[
          AppReviewEntry(
            l10n.brLgaOfOrigin,
            text(
              lgaName(p[ParentField.stateOfOrigin], p[ParentField.lgaOfOrigin]),
            ),
          ),
          AppReviewEntry(
            l10n.brEthnicGroup,
            option(data.ethnicGroups, p[ParentField.ethnicGroup]),
          ),
        ],
        if (p.applies(ParentField.occupation, parent))
          AppReviewEntry(
            l10n.brOccupation,
            option(data.occupations, p[ParentField.occupation]),
          ),
        AppReviewSubheading(l10n.brPlaceOfResidence),
        AppReviewEntry(
          l10n.srCountryOfResidence,
          option(data.countryOptions, p[ParentField.country]),
        ),
        AppReviewEntry(
          l10n.srStateOfResidence,
          text(stateName(p[ParentField.country], p[ParentField.state])),
        ),
        if (p.applies(ParentField.lga, parent))
          AppReviewEntry(
            l10n.srLgaOfResidence,
            text(lgaName(p[ParentField.state], p[ParentField.lga])),
          ),
        AppReviewEntry(l10n.brAddress, text(p[ParentField.address])),
        AppReviewEntry(
          l10n.brLiteracy,
          option(data.literacyLevels, p[ParentField.literacy]),
        ),
        if (p.applies(ParentField.educationLevel, parent))
          AppReviewEntry(
            l10n.brEducationLevel,
            option(data.educationLevels, p[ParentField.educationLevel]),
          ),
        AppReviewEntry(l10n.brPhoneNumber, text(p[ParentField.phone])),
      ];
    }

    final consent = informant[InformantField.consentType];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(ForeignBirthStep.child, l10n.brStepChild, [
          AppReviewEntry(l10n.brSurname, text(child[ChildField.surname])),
          AppReviewEntry(l10n.brFirstName, text(child[ChildField.firstName])),
          AppReviewEntry(l10n.brMiddleName, text(child[ChildField.middleName])),
          AppReviewEntry(l10n.brDateOfBirth, date(child.dateOfBirth)),
          AppReviewEntry(l10n.brSex, option(data.sexes, child[ChildField.sex])),
          AppReviewEntry(
            l10n.brTypeOfBirth,
            option(data.typesOfBirth, child[ChildField.typeOfBirth]),
          ),
          AppReviewEntry(
            l10n.brBirthOrder,
            option(data.birthOrders, child[ChildField.birthOrder]),
          ),
          AppReviewEntry(
            l10n.brPlaceOfOccurrence,
            option(
              data.placesOfOccurrence,
              child[ChildField.placeOfOccurrence],
            ),
          ),
          AppReviewEntry(
            l10n.fbCountryOfBirth,
            option(data.countryOptions, child[ChildField.countryOfBirth]),
          ),
          AppReviewEntry(
            l10n.fbStateOfBirth,
            text(
              stateName(
                child[ChildField.countryOfBirth],
                child[ChildField.stateOfBirth],
              ),
            ),
          ),
          status(
            l10n.brCaptureFace,
            provided: child[ChildField.facePhoto] != null,
          ),
        ]),
        const SizedBox(height: Spacing.md),
        card(
          ForeignBirthStep.mother,
          l10n.brStepMother,
          parentRows(Parent.mother),
        ),
        const SizedBox(height: Spacing.md),
        card(
          ForeignBirthStep.father,
          l10n.brStepFather,
          parentRows(Parent.father),
        ),
        const SizedBox(height: Spacing.md),
        card(ForeignBirthStep.informant, l10n.brStepInformant, [
          AppReviewEntry(
            l10n.srRelationshipToChild,
            option(data.relationships, informant[InformantField.relationship]),
          ),
          AppReviewEntry(l10n.srNinLabel, text(informant[InformantField.nin])),
          AppReviewEntry(
            l10n.brSurname,
            text(informant[InformantField.surname]),
          ),
          AppReviewEntry(
            l10n.brFirstName,
            text(informant[InformantField.firstName]),
          ),
          AppReviewEntry(
            l10n.brMiddleName,
            text(informant[InformantField.middleName]),
          ),
          AppReviewSubheading(l10n.brPlaceOfResidence),
          AppReviewEntry(
            l10n.srCountryOfResidence,
            option(data.countryOptions, informant[InformantField.country]),
          ),
          AppReviewEntry(
            l10n.srStateOfResidence,
            text(
              stateName(
                informant[InformantField.country],
                informant[InformantField.state],
              ),
            ),
          ),
          if (informant.applies(InformantField.lga))
            AppReviewEntry(
              l10n.srLgaOfResidence,
              text(
                lgaName(
                  informant[InformantField.state],
                  informant[InformantField.lga],
                ),
              ),
            ),
          AppReviewEntry(
            l10n.brAddress,
            text(informant[InformantField.address]),
          ),
          AppReviewEntry(
            l10n.brNationality,
            option(data.nationalities, informant[InformantField.nationality]),
          ),
          AppReviewEntry(
            l10n.brPhoneNumber,
            text(informant[InformantField.phone]),
          ),
          AppReviewEntry(
            l10n.fbInformantEmail,
            text(informant[InformantField.email]),
          ),
          if (consent == ConsentType.faceCapture)
            status(
              l10n.srInformantFace,
              provided: informant[InformantField.face] != null,
            )
          else
            status(
              l10n.brInformantSignature,
              provided: informant[InformantField.signature] != null,
            ),
        ]),
        const SizedBox(height: Spacing.md),
        card(ForeignBirthStep.documents, l10n.brStepDocuments, [
          status(
            l10n.fbDocCertificate,
            provided: draft.certificate != null,
            detail: draft.certificate?.name,
          ),
        ]),
      ],
    );
  }
}
