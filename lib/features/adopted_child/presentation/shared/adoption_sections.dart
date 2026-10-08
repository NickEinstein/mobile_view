import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_draft.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_form.dart';
import 'package:vital_reg_mobile/features/adopted_child/domain/entities/adoption_reference_data.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Every section of an adoption application as cards: the form's review
/// (with Edit) and Certificate Details (read-only).
class AdoptionSections extends StatelessWidget {
  const AdoptionSections({
    required this.draft,
    required this.data,
    this.onEdit,
    this.isIncomplete,
    super.key,
  });

  final AdoptionDraft draft;
  final AdoptionReferenceData data;

  /// Null hides the Edit links.
  final void Function(AdoptionStep step)? onEdit;

  /// Outlines a section in red.
  final bool Function(AdoptionStep step)? isIncomplete;

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

    Widget card(AdoptionStep step, String title, List<Widget> rows) =>
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
    final details = draft.details;
    final informant = draft.informant;

    List<Widget> adopterRows(AdopterParticulars a) => [
      AppReviewEntry(l10n.srNinLabel, text(a[AdopterField.nin])),
      AppReviewEntry(l10n.brSurname, text(a[AdopterField.surname])),
      AppReviewEntry(l10n.brFirstName, text(a[AdopterField.firstName])),
      AppReviewEntry(l10n.brMiddleName, text(a[AdopterField.middleName])),
      AppReviewEntry(
        l10n.srMaritalStatus,
        option(data.maritalStatuses, a[AdopterField.maritalStatus]),
      ),
      AppReviewEntry(
        l10n.brNationality,
        option(data.nationalities, a[AdopterField.nationality]),
      ),
      AppReviewEntry(l10n.srAddress, text(a[AdopterField.address])),
      AppReviewEntry(
        l10n.brOccupation,
        option(data.occupations, a[AdopterField.occupation]),
      ),
      AppReviewSubheading(l10n.brPlaceOfResidence),
      AppReviewEntry(
        l10n.srCountryOfResidence,
        option(data.countries, a[AdopterField.country]),
      ),
      if (a.applies(AdopterField.state)) ...[
        AppReviewEntry(
          l10n.srStateOfResidence,
          option(data.stateOptions, a[AdopterField.state]),
        ),
        AppReviewEntry(
          l10n.srLgaOfResidence,
          option(data.lgasOf(a[AdopterField.state]), a[AdopterField.lga]),
        ),
      ],
      AppReviewEntry(
        l10n.brLocalityType,
        option(data.localityTypes, a[AdopterField.localityType]),
      ),
      AppReviewEntry(
        l10n.brLiteracy,
        option(data.literacyLevels, a[AdopterField.literacy]),
      ),
      if (a.applies(AdopterField.educationLevel))
        AppReviewEntry(
          l10n.brEducationLevel,
          option(data.educationLevels, a[AdopterField.educationLevel]),
        ),
      AppReviewEntry(l10n.brPhoneNumber, text(a[AdopterField.phone])),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(AdoptionStep.child, l10n.brStepChild, [
          AppReviewEntry(l10n.brSurname, text(child[ChildField.surname])),
          AppReviewEntry(l10n.brFirstName, text(child[ChildField.firstName])),
          AppReviewEntry(l10n.brMiddleName, text(child[ChildField.middleName])),
          AppReviewEntry(l10n.brDateOfBirth, date(child.dateOfBirth)),
          AppReviewEntry(l10n.brSex, option(data.sexes, child[ChildField.sex])),
          AppReviewEntry(
            l10n.acPreviousFullName,
            text(child[ChildField.previousFullName]),
          ),
          AppReviewEntry(
            l10n.srPlaceOfBirth,
            option(data.placesOfBirth, child[ChildField.placeOfBirth]),
          ),
          AppReviewEntry(
            l10n.acOrderOfChild,
            option(data.birthOrders, child[ChildField.birthOrder]),
          ),
          AppReviewEntry(
            l10n.brStateOfBirth,
            option(data.stateOptions, child[ChildField.stateOfBirth]),
          ),
          AppReviewEntry(
            l10n.brLgaOfBirth,
            option(
              data.lgasOf(child[ChildField.stateOfBirth]),
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
        card(
          AdoptionStep.adopter1,
          l10n.acAdopter1Title,
          adopterRows(draft.adopter1),
        ),
        const SizedBox(height: Spacing.md),
        card(
          AdoptionStep.adopter2,
          l10n.acAdopter2Title,
          draft.hasAdopter2
              ? adopterRows(draft.adopter2)
              : [AppReviewEntry(l10n.acAdopter2Title, l10n.acNotGiven)],
        ),
        const SizedBox(height: Spacing.md),
        card(AdoptionStep.adoptionDetails, l10n.acStepAdoptionDetails, [
          AppReviewEntry(
            l10n.acAdoptionType,
            switch (details[AdoptionDetailsField.adoptionType]) {
              AdoptionCodes.domestic => l10n.acAdoptionDomestic,
              AdoptionCodes.interCountry => l10n.acAdoptionInterCountry,
              final other => text(other),
            },
          ),
          AppReviewEntry(
            l10n.srCourtName,
            text(details[AdoptionDetailsField.courtName]),
          ),
          AppReviewEntry(
            l10n.srOrderReference,
            text(details[AdoptionDetailsField.orderReference]),
          ),
          AppReviewEntry(l10n.acOrderDate, date(details.orderDate)),
        ]),
        const SizedBox(height: Spacing.md),
        card(AdoptionStep.informant, l10n.brStepInformant, [
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
            option(data.countries, informant[InformantField.country]),
          ),
          if (informant.applies(InformantField.state)) ...[
            AppReviewEntry(
              l10n.srStateOfResidence,
              option(data.stateOptions, informant[InformantField.state]),
            ),
            AppReviewEntry(
              l10n.srLgaOfResidence,
              option(
                data.lgasOf(informant[InformantField.state]),
                informant[InformantField.lga],
              ),
            ),
          ],
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
        card(AdoptionStep.documents, l10n.acDocumentsReviewTitle, [
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

extension AdoptionDocumentLabel on AdoptionDocument {
  String label(AppLocalizations l10n) => switch (this) {
    AdoptionDocument.courtOrder => l10n.acDocCourtOrder,
    AdoptionDocument.adoptionCertificate => l10n.acDocAdoptionCertificate,
    AdoptionDocument.adopter1Identity => l10n.acDocAdopter1Identity,
    AdoptionDocument.adopter2Identity => l10n.acDocAdopter2Identity,
  };
}
