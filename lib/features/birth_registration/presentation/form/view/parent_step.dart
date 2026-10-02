part of 'registration_form_page.dart';

/// Steps 2 and 3, the mother and the father.
class _ParentStep extends StatelessWidget {
  const _ParentStep({required this.role});

  final ParentRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
    final formState = context.watch<RegistrationFormCubit>().state;
    final draft = formState.draft!;
    final data = formState.referenceData!;
    final isMother = role == ParentRole.mother;
    final parent = isMother ? draft.mother : draft.father;

    final f = _Fields<ParentField>(
      l10n: l10n,
      valueOf: (field) => parent[field],
      errorOf: (field) => _personError(
        l10n,
        parent.errorOf(field, role),
        showRequired: formState.showErrors,
      ),
      onChanged: (field, value) => cubit.parentChanged(role, field, value),
    );
    bool shown(ParentField field) => parent.applies(field, role);

    return _FieldColumn(
      header: _StepTitle(
        title: isMother ? l10n.brStepMother : l10n.brStepFather,
        hint: isMother ? l10n.brStepMotherHint : l10n.brStepFatherHint,
      ),
      fields: [
        f.digits(
          ParentField.nin,
          l10n.brNin,
          l10n.brNinHint,
          maxLength: 11,
          note: l10n.brIfAvailable,
        ),
        f.name(ParentField.surname, l10n.brSurname, l10n.brSurnameHint),
        f.name(ParentField.firstName, l10n.brFirstName, l10n.brFirstNameHint),
        if (shown(ParentField.maidenName))
          f.name(
            ParentField.maidenName,
            l10n.brMaidenName,
            l10n.brMaidenNameHint,
          ),
        f.name(
          ParentField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
        ),
        _SectionTitle(l10n.brPlaceOfResidence),
        if (shown(ParentField.sameResidenceAsMother))
          f.yesNo(ParentField.sameResidenceAsMother, l10n.brSameAsMother),
        if (shown(ParentField.country))
          f.select(ParentField.country, l10n.brCountry, data.countries),
        if (shown(ParentField.state))
          f.select(ParentField.state, l10n.brState, data.stateOptions),
        if (shown(ParentField.lga))
          _lgaField(
            formState,
            parent[ParentField.state],
            f.select(
              ParentField.lga,
              l10n.brLga,
              data.lgasOf(parent[ParentField.state]),
            ),
          ),
        if (shown(ParentField.address))
          f.text(
            ParentField.address,
            l10n.brAddress,
            l10n.brAddressHint,
            textCapitalization: TextCapitalization.sentences,
          ),
        if (shown(ParentField.settlement))
          f.select(
            ParentField.settlement,
            isMother ? l10n.brLocalityType : l10n.brPlaceOfSettlement,
            data.localityTypes,
          ),
        f.digits(
          ParentField.age,
          isMother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
          l10n.brAgeHint,
          maxLength: 2,
        ),
        f.select(
          ParentField.maritalStatus,
          l10n.brMaritalStatus,
          data.maritalStatuses,
        ),
        f.select(
          ParentField.nationality,
          l10n.brNationality,
          data.nationalityOptions,
        ),
        if (shown(ParentField.stateOfOrigin))
          f.select(
            ParentField.stateOfOrigin,
            l10n.brStateOfOrigin,
            data.stateOptions,
          ),
        if (shown(ParentField.lgaOfOrigin))
          _lgaField(
            formState,
            parent[ParentField.stateOfOrigin],
            f.select(
              ParentField.lgaOfOrigin,
              l10n.brLgaOfOrigin,
              data.lgasOf(parent[ParentField.stateOfOrigin]),
            ),
          ),
        if (shown(ParentField.ethnicGroup))
          f.select(
            ParentField.ethnicGroup,
            l10n.brEthnicGroup,
            data.ethnicGroups,
          ),
        f.select(ParentField.literacy, l10n.brLiteracy, data.literacyLevels),
        if (shown(ParentField.educationLevel))
          f.select(
            ParentField.educationLevel,
            l10n.brEducationLevel,
            data.educationLevels,
          ),
        f.select(ParentField.occupation, l10n.brOccupation, data.occupations),
        f.phone(ParentField.phone, note: l10n.brIfAvailable),
      ],
    );
  }
}
