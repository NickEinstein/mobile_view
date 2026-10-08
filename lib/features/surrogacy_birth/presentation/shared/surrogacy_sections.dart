import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_draft.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_form.dart';
import 'package:vital_reg_mobile/features/surrogacy_birth/domain/entities/surrogacy_reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Every section of a surrogacy application as cards: the form's review
/// (with Edit) and Certificate Details (read-only).
class SurrogacySections extends StatelessWidget {
  const SurrogacySections({
    required this.draft,
    required this.data,
    this.onEdit,
    this.isIncomplete,
    super.key,
  });

  final SurrogacyDraft draft;
  final SurrogacyReferenceData data;

  /// Null hides the Edit links.
  final void Function(SurrogacyStep step)? onEdit;

  /// Outlines a section in red.
  final bool Function(SurrogacyStep step)? isIncomplete;

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
    List<Option> lgas(String? state) => data.lgasOf(state);

    Widget card(SurrogacyStep step, String title, List<Widget> rows) =>
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
    final details = draft.surrogacy;
    final informant = draft.informant;

    List<Widget> parentRows(ParentParticulars p) => [
      AppReviewEntry(l10n.srNinLabel, text(p[ParentField.nin])),
      AppReviewEntry(l10n.brSurname, text(p[ParentField.surname])),
      AppReviewEntry(l10n.brFirstName, text(p[ParentField.firstName])),
      AppReviewEntry(l10n.brMiddleName, text(p[ParentField.middleName])),
      AppReviewEntry(
        l10n.srMaritalStatus,
        option(data.maritalStatuses, p[ParentField.maritalStatus]),
      ),
      AppReviewEntry(l10n.srAddress, text(p[ParentField.address])),
      AppReviewEntry(
        l10n.brOccupation,
        option(data.occupations, p[ParentField.occupation]),
      ),
      AppReviewEntry(
        l10n.brNationality,
        option(data.nationalities, p[ParentField.nationality]),
      ),
      AppReviewSubheading(l10n.brPlaceOfResidence),
      AppReviewEntry(
        l10n.srCountryOfResidence,
        option(data.countries, p[ParentField.country]),
      ),
      if (p.applies(ParentField.state)) ...[
        AppReviewEntry(
          l10n.srStateOfResidence,
          option(data.stateOptions, p[ParentField.state]),
        ),
        AppReviewEntry(
          l10n.srLgaOfResidence,
          option(lgas(p[ParentField.state]), p[ParentField.lga]),
        ),
      ],
      AppReviewEntry(
        l10n.brLocalityType,
        option(data.localityTypes, p[ParentField.localityType]),
      ),
      AppReviewEntry(
        l10n.brLiteracy,
        option(data.literacyLevels, p[ParentField.literacy]),
      ),
      if (p.applies(ParentField.educationLevel))
        AppReviewEntry(
          l10n.brEducationLevel,
          option(data.educationLevels, p[ParentField.educationLevel]),
        ),
      AppReviewEntry(l10n.brPhoneNumber, text(p[ParentField.phone])),
    ];

    final surrogate = draft.surrogateMother;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(SurrogacyStep.child, l10n.brStepChild, [
          AppReviewEntry(l10n.brSurname, text(child[ChildField.surname])),
          AppReviewEntry(l10n.brFirstName, text(child[ChildField.firstName])),
          AppReviewEntry(l10n.brMiddleName, text(child[ChildField.middleName])),
          AppReviewEntry(l10n.brDateOfBirth, date(child.dateOfBirth)),
          AppReviewEntry(
            l10n.brBirthOrder,
            option(data.birthOrders, child[ChildField.birthOrder]),
          ),
          AppReviewEntry(l10n.brSex, option(data.sexes, child[ChildField.sex])),
          AppReviewEntry(
            l10n.brTypeOfBirth,
            option(data.typesOfBirth, child[ChildField.typeOfBirth]),
          ),
          AppReviewEntry(
            l10n.srPlaceOfBirth,
            option(data.placesOfBirth, child[ChildField.placeOfBirth]),
          ),
          AppReviewEntry(
            l10n.brStateOfBirth,
            option(data.stateOptions, child[ChildField.stateOfBirth]),
          ),
          AppReviewEntry(
            l10n.brLgaOfBirth,
            option(
              lgas(child[ChildField.stateOfBirth]),
              child[ChildField.lgaOfBirth],
            ),
          ),
          AppReviewEntry(
            l10n.srTownVillage,
            text(child[ChildField.townOfBirth]),
          ),
          AppReviewEntry(
            l10n.brRegistrationCenter,
            option(
              data.centersOf(
                child[ChildField.registrationState],
                child[ChildField.registrationLga],
              ),
              child[ChildField.registrationCenter],
            ),
          ),
          AppReviewEntry(
            l10n.srLocalityOfBirth,
            option(data.localityTypes, child[ChildField.localityOfBirth]),
          ),
          status(
            l10n.brCaptureFace,
            provided: child[ChildField.facePhoto] != null,
          ),
        ]),
        const SizedBox(height: Spacing.md),
        card(SurrogacyStep.surrogacy, l10n.srStepSurrogacy, [
          AppReviewEntry(
            l10n.srArrangementType,
            option(
              data.arrangementTypes,
              details[SurrogacyDetailsField.arrangementType],
            ),
          ),
          AppReviewEntry(
            l10n.srCourtName,
            text(details[SurrogacyDetailsField.courtName]),
          ),
          AppReviewEntry(
            l10n.srOrderReference,
            text(details[SurrogacyDetailsField.orderReference]),
          ),
          AppReviewEntry(l10n.srOrderDate, date(details.orderDate)),
        ]),
        const SizedBox(height: Spacing.md),
        card(
          SurrogacyStep.legalMother,
          l10n.srLegalMotherTitle,
          parentRows(draft.legalMother),
        ),
        const SizedBox(height: Spacing.md),
        card(
          SurrogacyStep.legalFather,
          l10n.srLegalFatherTitle,
          (draft.hasLegalFather ?? false)
              ? parentRows(draft.legalFather)
              : [AppReviewEntry(l10n.srHasLegalFather, l10n.no)],
        ),
        const SizedBox(height: Spacing.md),
        card(
          SurrogacyStep.surrogateMother,
          l10n.srSurrogateMotherReviewTitle,
          surrogate.isEmpty
              ? [AppReviewEntry(l10n.srSurrogateMotherReviewTitle, '-')]
              : [
                  AppReviewEntry(
                    l10n.srNinLabel,
                    text(surrogate[SurrogateField.nin]),
                  ),
                  AppReviewEntry(l10n.srFullName, text(surrogate.fullName)),
                  AppReviewEntry(
                    l10n.srAgeAtBirth,
                    text(surrogate[SurrogateField.ageAtBirth]),
                  ),
                  AppReviewEntry(
                    l10n.brBirthOrder,
                    option(
                      data.birthOrders,
                      surrogate[SurrogateField.birthOrder],
                    ),
                  ),
                  AppReviewEntry(
                    l10n.srAddress,
                    text(surrogate[SurrogateField.address]),
                  ),
                  AppReviewEntry(
                    l10n.brNationality,
                    option(
                      data.nationalities,
                      surrogate[SurrogateField.nationality],
                    ),
                  ),
                  AppReviewEntry(
                    l10n.brPhoneNumber,
                    text(surrogate[SurrogateField.phone]),
                  ),
                ],
        ),
        const SizedBox(height: Spacing.md),
        card(SurrogacyStep.informant, l10n.brStepInformant, [
          AppReviewEntry(
            l10n.srRelationshipToChild,
            option(data.relationships, informant[InformantField.relationship]),
          ),
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
            option(data.countries, informant[InformantField.country]),
          ),
          if (informant.applies(InformantField.state))
            AppReviewEntry(
              l10n.srStateOfResidence,
              option(data.stateOptions, informant[InformantField.state]),
            ),
          AppReviewEntry(
            l10n.brAddress,
            text(informant[InformantField.address]),
          ),
          AppReviewEntry(
            l10n.brPhoneNumber,
            text(informant[InformantField.phone]),
          ),
          status(
            l10n.brInformantSignature,
            provided:
                informant[InformantField.signature] != null &&
                informant.applies(InformantField.signature),
          ),
          status(
            l10n.srInformantFace,
            provided:
                informant[InformantField.face] != null &&
                informant.applies(InformantField.face),
          ),
        ]),
        const SizedBox(height: Spacing.md),
        card(SurrogacyStep.documents, l10n.srDocumentsReviewTitle, [
          for (final document in draft.documentsAsked)
            status(
              document.label(l10n),
              provided: draft.documents[document] != null,
              detail: draft.documents[document]?.name,
            ),
          status(
            l10n.srPassportUpload,
            provided: draft.informantPassport != null,
            detail: draft.informantPassport?.name,
          ),
        ]),
      ],
    );
  }
}

extension SurrogacyDocumentLabel on SurrogacyDocument {
  String label(AppLocalizations l10n) => switch (this) {
    SurrogacyDocument.courtOrder => l10n.srDocCourtOrder,
    SurrogacyDocument.parentalOrder => l10n.srDocParentalOrder,
    SurrogacyDocument.motherIdentity => l10n.srDocMotherIdentity,
    SurrogacyDocument.fatherIdentity => l10n.srDocFatherIdentity,
  };
}
