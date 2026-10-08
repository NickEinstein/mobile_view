import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_draft.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_form.dart';
import 'package:vital_reg_mobile/features/death_registration/domain/entities/death_reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// Display names for [DeathDocument].
extension DeathDocumentLabel on DeathDocument {
  String label(AppLocalizations l10n) => switch (this) {
    DeathDocument.policeReport => l10n.drDocPoliceReport,
    DeathDocument.nextOfKinLetter => l10n.drDocNextOfKin,
    DeathDocument.employersReport => l10n.drDocEmployersReport,
    DeathDocument.affidavit => l10n.drDocAffidavit,
    DeathDocument.medicalProofOfDeath => l10n.drDocMedicalProof,
  };
}

/// A death registration's answers as review cards (with "Edit" on the
/// preview).
class DeathSections extends StatelessWidget {
  const DeathSections({
    required this.draft,
    required this.data,
    this.onEdit,
    this.isComplete,
    super.key,
  });

  final DeathDraft draft;
  final DeathReferenceData data;

  /// Null hides the Edit links.
  final ValueChanged<DeathStep>? onEdit;

  /// Null marks every section complete.
  final bool Function(DeathStep step)? isComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final onEdit = this.onEdit;

    String shown(String? value) => value ?? '-';
    String option(List<Option> options, String? id) =>
        shown(DeathReferenceData.labelOf(options, id));

    final d = draft.deceased;
    final i = draft.informant;
    final death = d.dateOfDeath;

    Widget card(DeathStep step, String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: AppReviewCard(
        title: title,
        rows: rows,
        incomplete: !(isComplete?.call(step) ?? true),
        editLabel: l10n.brEdit,
        onEdit: onEdit == null ? null : () => onEdit(step),
      ),
    );
    Widget entry(String label, String value) => AppReviewEntry(label, value);
    Widget deceased(String label, DeceasedField field, [List<Option>? from]) =>
        entry(label, from == null ? shown(d[field]) : option(from, d[field]));
    Widget informant(
      String label,
      InformantField field, [
      List<Option>? from,
    ]) => entry(label, from == null ? shown(i[field]) : option(from, i[field]));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(DeathStep.deceased, l10n.sbStepDeceased, [
          deceased(l10n.brNin, DeceasedField.nin),
          if (d.applies(DeceasedField.noNinReason))
            deceased(l10n.drNoNinReason, DeceasedField.noNinReason),
          deceased(l10n.brSurname, DeceasedField.surname),
          deceased(l10n.brFirstName, DeceasedField.firstName),
          deceased(l10n.brMiddleName, DeceasedField.middleName),
          deceased(l10n.brSex, DeceasedField.sex, data.sexes),
          AppReviewSubheading(l10n.sbPlaceOfUsualResidence),
          deceased(l10n.brCountry, DeceasedField.country, data.countries),
          if (d.applies(DeceasedField.state)) ...[
            deceased(l10n.brState, DeceasedField.state, data.stateOptions),
            deceased(
              l10n.brLga,
              DeceasedField.lga,
              data.lgasOf(d[DeceasedField.state]),
            ),
            deceased(
              l10n.sbSettlement,
              DeceasedField.settlement,
              data.settlements,
            ),
            deceased(l10n.drAddressOfResidence, DeceasedField.address),
          ],
          entry(
            l10n.drDateOfDeath,
            death == null ? '-' : DateFormat.yMMMMd(locale).format(death),
          ),
          deceased(
            l10n.drMaritalStatus,
            DeceasedField.maritalStatus,
            data.maritalStatuses,
          ),
          deceased(
            l10n.brNationality,
            DeceasedField.nationality,
            data.nationalities,
          ),
          if (d.applies(DeceasedField.stateOfOrigin)) ...[
            deceased(
              l10n.brStateOfOrigin,
              DeceasedField.stateOfOrigin,
              data.stateOptions,
            ),
            deceased(
              l10n.brLgaOfOrigin,
              DeceasedField.lgaOfOrigin,
              data.lgasOf(d[DeceasedField.stateOfOrigin]),
            ),
            deceased(
              l10n.drEthnicOrigin,
              DeceasedField.ethnicGroup,
              data.ethnicGroups,
            ),
          ],
          deceased(l10n.brLiteracy, DeceasedField.literacy, data.literacy),
          if (d.applies(DeceasedField.educationLevel))
            deceased(
              l10n.brEducationLevel,
              DeceasedField.educationLevel,
              data.educationLevels,
            ),
          deceased(
            l10n.brOccupation,
            DeceasedField.occupation,
            data.occupations,
          ),
          deceased(
            l10n.brPlaceOfOccurrence,
            DeceasedField.placeOfDeath,
            data.placesOfDeath,
          ),
          deceased(l10n.drAgeAtDeath, DeceasedField.ageAtDeath),
          deceased(l10n.drVillage, DeceasedField.village),
          deceased(
            l10n.drCertifiedByDoctor,
            DeceasedField.certifiedByDoctor,
            data.yesNo,
          ),
          deceased(
            l10n.drCauseOfDeath,
            DeceasedField.causeOfDeath,
            data.causesOfDeath,
          ),
          deceased(
            l10n.drRegistrationCenter,
            DeceasedField.registrationCenter,
            data.centersOf(
              d[DeceasedField.registrationState],
              d[DeceasedField.registrationLga],
            ),
          ),
        ]),
        card(DeathStep.informant, l10n.brStepInformant, [
          informant(l10n.brNin, InformantField.nin),
          informant(l10n.brSurname, InformantField.surname),
          informant(l10n.brFirstName, InformantField.firstName),
          informant(l10n.brMiddleName, InformantField.middleName),
          informant(
            l10n.sbRelationship,
            InformantField.relationship,
            data.relationships,
          ),
          informant(l10n.brPhoneNumber, InformantField.phone),
          AppReviewSubheading(l10n.sbPlaceOfUsualResidence),
          informant(l10n.brCountry, InformantField.country, data.countries),
          if (i.applies(InformantField.state)) ...[
            informant(l10n.brState, InformantField.state, data.stateOptions),
            informant(
              l10n.brLga,
              InformantField.lga,
              data.lgasOf(i[InformantField.state]),
            ),
            informant(
              l10n.sbSettlement,
              InformantField.settlement,
              data.settlements,
            ),
            informant(l10n.drStreetName, InformantField.address),
          ],
        ]),
        card(DeathStep.documents, l10n.drDocumentsUpload, [
          for (final document in DeathDocument.values)
            AppReviewStatus(
              document.label(l10n),
              provided: draft.hasDocument(document),
              providedLabel: l10n.brProvided,
              notProvidedLabel: l10n.brNotProvided,
              detail: draft.documents[document]?.name,
            ),
        ]),
      ],
    );
  }
}
