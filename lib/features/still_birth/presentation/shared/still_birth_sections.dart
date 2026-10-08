import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vital_reg_mobile/design_system/tokens/spacing.dart';
import 'package:vital_reg_mobile/design_system/widgets/form/app_review.dart';
import 'package:vital_reg_mobile/features/birth_registration/domain/entities/reference_data.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_draft.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_form.dart';
import 'package:vital_reg_mobile/features/still_birth/domain/entities/still_birth_reference_data.dart';
import 'package:vital_reg_mobile/l10n/l10n.dart';

/// A still birth's answers as review cards (with "Edit" on the preview).
class StillBirthSections extends StatelessWidget {
  const StillBirthSections({
    required this.draft,
    required this.data,
    this.onEdit,
    this.isComplete,
    super.key,
  });

  final StillBirthDraft draft;
  final StillBirthReferenceData data;

  /// Null hides the Edit links.
  final ValueChanged<StillBirthStep>? onEdit;

  /// Null marks every section complete.
  final bool Function(StillBirthStep step)? isComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final onEdit = this.onEdit;

    String shown(String? value) => value ?? '-';
    String option(List<Option> options, String? id) =>
        shown(StillBirthReferenceData.labelOf(options, id));

    final d = draft.deceased;
    final m = draft.mother;
    final i = draft.informant;
    final delivery = d.dateOfDelivery;

    Widget card(StillBirthStep step, String title, List<Widget> rows) =>
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card(StillBirthStep.deceased, l10n.sbStepDeceased, [
          AppReviewEntry(
            l10n.brPlaceOfOccurrence,
            option(data.placesOfOccurrence, d[DeceasedField.placeOfOccurrence]),
          ),
          AppReviewEntry(
            '${l10n.sbVillage} ${l10n.sbRegistrationArea}',
            shown(d[DeceasedField.village]),
          ),
          AppReviewEntry(
            l10n.sbDateOfDelivery,
            delivery == null ? '-' : DateFormat.yMMMMd(locale).format(delivery),
          ),
          AppReviewEntry(
            l10n.sbTypeOfDelivery,
            option(data.typesOfDelivery, d[DeceasedField.typeOfDelivery]),
          ),
          AppReviewEntry(
            l10n.sbSexOfChild,
            option(data.sexes, d[DeceasedField.sex]),
          ),
        ]),
        card(StillBirthStep.mother, l10n.brStepMother, [
          AppReviewEntry(
            '${l10n.sbFullName} ${l10n.sbSurnameFirst}',
            shown(m[MotherField.fullName]),
          ),
          AppReviewSubheading(l10n.sbPlaceOfUsualResidence),
          AppReviewEntry(
            l10n.brCountry,
            option(data.countries, m[MotherField.country]),
          ),
          if (m.applies(MotherField.state)) ...[
            AppReviewEntry(
              l10n.brState,
              option(data.stateOptions, m[MotherField.state]),
            ),
            AppReviewEntry(
              l10n.brLga,
              option(data.lgasOf(m[MotherField.state]), m[MotherField.lga]),
            ),
            AppReviewEntry(
              l10n.sbSettlement,
              option(data.settlements, m[MotherField.settlement]),
            ),
            AppReviewEntry(l10n.sbAddress, shown(m[MotherField.address])),
          ],
          AppReviewEntry(l10n.sbAge, shown(m[MotherField.age])),
          AppReviewEntry(
            l10n.brNationality,
            option(data.nationalities, m[MotherField.nationality]),
          ),
          if (m.applies(MotherField.stateOfOrigin)) ...[
            AppReviewEntry(
              l10n.brStateOfOrigin,
              option(data.stateOptions, m[MotherField.stateOfOrigin]),
            ),
            AppReviewEntry(
              l10n.brEthnicGroup,
              option(data.ethnicGroups, m[MotherField.ethnicGroup]),
            ),
          ],
        ]),
        card(StillBirthStep.informant, l10n.brStepInformant, [
          AppReviewEntry(
            l10n.sbRelationship,
            option(data.relationships, i[InformantField.relationship]),
          ),
          AppReviewEntry(
            '${l10n.sbFullName} ${l10n.sbSurnameFirst}',
            shown(i[InformantField.fullName]),
          ),
          AppReviewSubheading(l10n.sbPlaceOfUsualResidence),
          AppReviewEntry(
            l10n.brCountry,
            option(data.countries, i[InformantField.country]),
          ),
          if (i.applies(InformantField.state)) ...[
            AppReviewEntry(
              l10n.brState,
              option(data.stateOptions, i[InformantField.state]),
            ),
            AppReviewEntry(
              l10n.brLga,
              option(
                data.lgasOf(i[InformantField.state]),
                i[InformantField.lga],
              ),
            ),
            AppReviewEntry(
              l10n.sbSettlement,
              option(data.settlements, i[InformantField.settlement]),
            ),
            AppReviewEntry(l10n.sbAddress, shown(i[InformantField.address])),
          ],
          AppReviewStatus(
            l10n.brInformantSignature,
            provided: i[InformantField.signature] != null,
            providedLabel: l10n.brProvided,
            notProvidedLabel: l10n.brNotProvided,
          ),
        ]),
      ],
    );
  }
}
