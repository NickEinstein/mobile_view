part of 'birth_reissuance_form_page.dart';

/// Step 1, "Particulars of Child". The names and
/// sex come from the NIN; the sex can't be changed when the NIN gave one.
class _ChildStep extends StatelessWidget {
  const _ChildStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
    final state = context.watch<BirthReissuanceFormCubit>().state;
    final options = state.options!;
    final child = state.form!.child;
    String? error(ChildField field) => reissuanceErrorText(
      context,
      child.errorOf(field),
      showRequired: state.showErrors,
    );
    final f = ReissuanceFields<ChildField>(
      l10n: l10n,
      valueOf: (field) => child[field],
      errorOf: error,
      onChanged: cubit.childChanged,
    );
    final nigeria = state.statesOf(ReissuanceCodes.nigeria);

    return AppFieldColumn(
      header: AppStepTitle(title: l10n.brStepChild, hint: l10n.brStepChildHint),
      fields: [
        f.text(
          ChildField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        f.text(
          ChildField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        f.text(
          ChildField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: ReissuanceFields.name,
        ),
        AppDateField(
          label: l10n.brDateOfBirth,
          value: child.dateOfBirth,
          firstDate: DateTime(1900),
          lastDate: ReissuanceCodes.latestBirthDate,
          errorText: error(ChildField.dateOfBirth),
          onChanged: cubit.dateOfBirthChanged,
        ),
        f.select(
          ChildField.typeOfBirth,
          l10n.brTypeOfBirth,
          options.typesOfBirth,
        ),
        f.select(ChildField.birthOrder, l10n.brBirthOrder, options.birthOrders),
        f.select(
          ChildField.sex,
          l10n.brSex,
          options.sexes,
          enabled: !state.sexLocked,
        ),
        f.select(
          ChildField.placeOfOccurrence,
          l10n.brPlaceOfOccurrence,
          options.placesOfOccurrence,
        ),
        f.select(ChildField.stateOfBirth, l10n.brStateOfBirth, nigeria),
        f.select(
          ChildField.lgaOfBirth,
          l10n.brLgaOfBirth,
          state.lgasOf(child[ChildField.stateOfBirth]),
        ),
        f.text(
          ChildField.townOfBirth,
          l10n.brLocalityOfBirth,
          l10n.brLocalityHint,
          note: l10n.crLocalityOfBirthNote,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(50),
          ],
        ),
        f.text(
          ChildField.townOfOrigin,
          l10n.brTownOfOrigin,
          l10n.crTownOfOriginHint,
          note: l10n.brOptional,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(50),
          ],
        ),
        f.select(
          ChildField.locality,
          l10n.brLocalityType,
          options.localityTypes,
        ),
        f.select(
          ChildField.registrationState,
          l10n.brRegistrationState,
          nigeria,
        ),
        f.select(
          ChildField.registrationLga,
          l10n.brRegistrationLga,
          state.lgasOf(child[ChildField.registrationState]),
        ),
        f.select(
          ChildField.registrationCenter,
          l10n.brRegistrationCenter,
          options.centresIn(child[ChildField.registrationLga]),
        ),
      ],
    );
  }
}
