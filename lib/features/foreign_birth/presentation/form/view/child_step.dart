part of 'foreign_birth_form_page.dart';

/// Step 1, "Particulars of Child". The registration place comes from the
/// registrar's account.
class _ChildStep extends StatelessWidget {
  const _ChildStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;
    final data = state.referenceData!;
    final child = state.draft!.child;
    final today = cubit.today;
    final f = _Fields<ChildField>(
      l10n: l10n,
      valueOf: (field) => child[field],
      errorOf: (field) => _errorText(
        l10n,
        child.errorOf(field, today: today),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.childChanged,
    );

    return AppFieldColumn(
      header: AppStepTitle(title: l10n.brStepChild, hint: l10n.brStepChildHint),
      fields: [
        f.text(
          ChildField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          ChildField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          ChildField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        AppDateField(
          key: const ValueKey(ChildField.dateOfBirth),
          label: l10n.brDateOfBirth,
          value: child.dateOfBirth,
          firstDate: DateTime(1900),
          lastDate: today,
          errorText: f.errorOf(ChildField.dateOfBirth),
          onChanged: (date) =>
              cubit.childDateChanged(ChildField.dateOfBirth, date),
        ),
        f.select(ChildField.sex, l10n.brSex, data.sexes),
        f.select(ChildField.typeOfBirth, l10n.brTypeOfBirth, data.typesOfBirth),
        f.select(ChildField.birthOrder, l10n.brBirthOrder, data.birthOrders),
        f.select(
          ChildField.placeOfOccurrence,
          l10n.brPlaceOfOccurrence,
          data.placesOfOccurrence,
        ),
        f.select(
          ChildField.countryOfBirth,
          l10n.fbCountryOfBirth,
          data.birthCountries,
        ),
        f.select(
          ChildField.stateOfBirth,
          l10n.fbStateOfBirth,
          state.statesOf(child[ChildField.countryOfBirth]),
        ),
        _FaceField(
          photoPath: child[ChildField.facePhoto],
          onCaptured: cubit.childPhotoCaptured,
        ),
      ],
    );
  }
}
