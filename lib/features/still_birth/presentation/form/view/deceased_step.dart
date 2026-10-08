part of 'still_birth_form_page.dart';

/// Step 1, "Particulars of Deceased".
class _DeceasedStep extends StatelessWidget {
  const _DeceasedStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StillBirthFormCubit>();
    final state = context.watch<StillBirthFormCubit>().state;
    final data = state.referenceData!;
    final deceased = state.draft!.deceased;
    final today = cubit.today;
    final f = _Fields<DeceasedField>(
      l10n: l10n,
      valueOf: (field) => deceased[field],
      errorOf: (field) => _errorText(
        l10n,
        deceased.errorOf(field, today: today),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.deceasedChanged,
    );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.sbStepDeceased,
        hint: l10n.sbStepDeceasedHint,
      ),
      fields: [
        f.select(
          DeceasedField.placeOfOccurrence,
          l10n.brPlaceOfOccurrence,
          data.placesOfOccurrence,
        ),
        f.text(
          DeceasedField.village,
          l10n.sbVillage,
          l10n.sbVillageHint,
          note: l10n.sbRegistrationArea,
          inputFormatters: [
            ..._Fields.plain,
            LengthLimitingTextInputFormatter(100),
          ],
        ),
        AppDateField(
          key: const ValueKey(DeceasedField.dateOfDelivery),
          label: l10n.sbDateOfDelivery,
          value: deceased.dateOfDelivery,
          firstDate: DeceasedParticulars.earliestDelivery,
          lastDate: today,
          errorText: f.errorOf(DeceasedField.dateOfDelivery),
          onChanged: cubit.dateOfDeliveryChanged,
        ),
        f.select(DeceasedField.sex, l10n.brSex, data.sexes),
        f.select(
          DeceasedField.typeOfDelivery,
          l10n.sbTypeOfDelivery,
          data.typesOfDelivery,
        ),
      ],
    );
  }
}
