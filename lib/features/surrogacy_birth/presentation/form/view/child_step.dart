part of 'surrogacy_form_page.dart';

/// Step 1, "Particulars of Child".
class _ChildStep extends StatelessWidget {
  const _ChildStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final data = state.referenceData!;
    final draft = state.draft!;
    final child = draft.child;
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
      isLocked: draft.isLocked,
    );

    return AppFieldColumn(
      header: AppStepTitle(title: l10n.brStepChild, hint: l10n.srStepChildHint),
      fields: [
        _GroupTitle(l10n.srLegallyRequired),
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
          firstDate: DateTime(today.year - 18),
          lastDate: today,
          errorText: f.errorOf(ChildField.dateOfBirth),
          onChanged: (date) =>
              cubit.childDateChanged(ChildField.dateOfBirth, date),
        ),
        f.select(ChildField.birthOrder, l10n.brBirthOrder, data.birthOrders),
        f.select(ChildField.sex, l10n.brSex, data.sexes),
        f.select(ChildField.typeOfBirth, l10n.brTypeOfBirth, data.typesOfBirth),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.srAdditionalFields),
        f.select(
          ChildField.placeOfBirth,
          l10n.srPlaceOfBirth,
          data.placesOfBirth,
        ),
        f.select(
          ChildField.stateOfBirth,
          l10n.brStateOfBirth,
          data.stateOptions,
        ),
        _lgaField(
          state,
          child[ChildField.stateOfBirth],
          f.select(
            ChildField.lgaOfBirth,
            l10n.brLgaOfBirth,
            data.lgasOf(child[ChildField.stateOfBirth]),
          ),
        ),
        f.text(
          ChildField.townOfBirth,
          l10n.srTownVillage,
          l10n.srTownVillageHint,
          inputFormatters: _Fields.plain,
        ),
        f.select(
          ChildField.registrationState,
          l10n.brRegistrationState,
          data.stateOptions,
        ),
        _lgaField(
          state,
          child[ChildField.registrationState],
          f.select(
            ChildField.registrationLga,
            l10n.brRegistrationLga,
            data.lgasOf(child[ChildField.registrationState]),
          ),
        ),
        f.select(
          ChildField.registrationCenter,
          l10n.brRegistrationCenter,
          data.centersOf(
            child[ChildField.registrationState],
            child[ChildField.registrationLga],
          ),
        ),
        f.select(
          ChildField.localityOfBirth,
          l10n.srLocalityOfBirth,
          data.localityTypes,
        ),
        _FaceField(
          photoPath: child[ChildField.facePhoto],
          onCaptured: cubit.childPhotoCaptured,
        ),
      ],
    );
  }
}
