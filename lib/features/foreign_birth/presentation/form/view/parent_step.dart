part of 'foreign_birth_form_page.dart';

/// Steps 2 and 3, the mother and the father.
class _ParentStep extends StatelessWidget {
  const _ParentStep(this.parent);

  final Parent parent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;
    final data = state.referenceData!;
    final draft = state.draft!;
    final person = draft.parent(parent);
    final isMother = parent == Parent.mother;
    final f = _Fields<ParentField>(
      l10n: l10n,
      valueOf: (field) => person[field],
      errorOf: (field) => _errorText(
        l10n,
        person.errorOf(field, parent),
        showRequired: state.showErrors,
        ages: (parent.minAge, parent.maxAge),
      ),
      onChanged: (field, value) => cubit.parentChanged(parent, field, value),
      isLocked: person.isLocked,
      // A validated NIN fills the name from outside.
      generation: person[ParentField.verifiedNin],
    );
    bool shown(ParentField field) => person.applies(field, parent);
    final ninFailure = state.ninFailure;

    return AppFieldColumn(
      header: AppStepTitle(
        title: isMother ? l10n.brStepMother : l10n.brStepFather,
        hint: isMother ? l10n.brStepMotherHint : l10n.brStepFatherHint,
      ),
      fields: [
        _NinField(
          // A new nationality clears the NIN.
          fieldKey: (parent, person[ParentField.nationality]),
          nin: person[ParentField.nin],
          verified: person.isNinVerified,
          checking: state.ninChecking == parent,
          onValidate: () => cubit.validateNin(parent),
          note: person.isRequired(ParentField.nin, parent)
              ? null
              : l10n.brOptional,
          errorText: _ninErrorText(
            l10n,
            failure: ninFailure?.$1 == parent ? ninFailure!.$2 : null,
            fieldError: person.errorOf(ParentField.nin, parent),
            showRequired: state.showErrors,
          ),
          onChanged: (value) =>
              cubit.parentChanged(parent, ParentField.nin, value),
        ),
        f.text(
          ParentField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          ParentField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          ParentField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        if (shown(ParentField.maidenName))
          f.text(
            ParentField.maidenName,
            l10n.brMaidenName,
            l10n.brMaidenNameHint,
            inputFormatters: _Fields.name,
          ),
        f.select(
          ParentField.maritalStatus,
          l10n.brMaritalStatus,
          data.maritalStatuses,
        ),
        f.text(
          ParentField.age,
          isMother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
          l10n.brAgeHint,
          keyboardType: TextInputType.number,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        f.select(
          ParentField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        f.select(
          ParentField.stateOfOrigin,
          l10n.fbStateOfOrigin,
          state.statesOf(person[ParentField.nationality]),
        ),
        if (shown(ParentField.lgaOfOrigin))
          f.select(
            ParentField.lgaOfOrigin,
            l10n.brLgaOfOrigin,
            state.lgasOf(person[ParentField.stateOfOrigin]),
          ),
        if (shown(ParentField.ethnicGroup))
          f.select(
            ParentField.ethnicGroup,
            l10n.brEthnicGroup,
            data.ethnicGroups,
          ),
        if (shown(ParentField.occupation))
          f.select(ParentField.occupation, l10n.brOccupation, data.occupations),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.brPlaceOfResidence),
        if (shown(ParentField.sameResidence))
          AppRadioGroup<String>(
            key: const ValueKey(ParentField.sameResidence),
            label: l10n.fbSameResidenceAsMother,
            options: {Answer.yes: l10n.yes, Answer.no: l10n.no},
            value: person[ParentField.sameResidence],
            onChanged: (value) =>
                cubit.parentChanged(parent, ParentField.sameResidence, value),
          ),
        f.select(
          ParentField.country,
          l10n.srCountryOfResidence,
          data.countryOptions,
        ),
        f.select(
          ParentField.state,
          l10n.srStateOfResidence,
          state.statesOf(person[ParentField.country]),
        ),
        if (shown(ParentField.lga))
          f.select(
            ParentField.lga,
            l10n.srLgaOfResidence,
            state.lgasOf(person[ParentField.state]),
          ),
        f.text(
          ParentField.address,
          l10n.brAddress,
          l10n.brAddressHint,
          inputFormatters: _Fields.plain,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.srAdditionalFields),
        f.select(ParentField.literacy, l10n.brLiteracy, data.literacyLevels),
        if (shown(ParentField.educationLevel))
          f.select(
            ParentField.educationLevel,
            l10n.brEducationLevel,
            data.educationLevels,
          ),
        f.text(
          ParentField.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          note: l10n.brOptional,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(15),
          ],
        ),
        // The backend refuses a notification without a Nigerian parent.
        if (!isMother && state.showErrors && !draft.hasNigerianParent)
          Text(
            l10n.fbNigerianParentRequired,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
  }
}
