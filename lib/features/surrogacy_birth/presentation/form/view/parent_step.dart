part of 'surrogacy_form_page.dart';

/// Steps 3 and 4, the legal parents (the father only if the order names
/// one).
class _LegalParentStep extends StatelessWidget {
  const _LegalParentStep(this.person);

  final SurrogacyPerson person;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final data = state.referenceData!;
    final draft = state.draft!;
    final isFather = person == SurrogacyPerson.legalFather;
    final parent = isFather ? draft.legalFather : draft.legalMother;
    final f = _Fields<ParentField>(
      l10n: l10n,
      valueOf: (field) => parent[field],
      errorOf: (field) => _errorText(
        l10n,
        parent.errorOf(field),
        showRequired: state.showErrors,
      ),
      onChanged: (field, value) =>
          cubit.legalParentChanged(person, field, value),
      generation: parent[ParentField.verifiedNin],
    );
    bool shown(ParentField field) => parent.applies(field);

    final header = AppStepTitle(
      title: isFather ? l10n.srLegalFatherTitle : l10n.srLegalMotherTitle,
      hint: isFather ? l10n.srLegalFatherHint : l10n.srLegalMotherHint,
    );
    final question = isFather
        ? AppRadioGroup<bool>(
            key: const ValueKey('hasLegalFather'),
            label: l10n.srHasLegalFather,
            inline: true,
            options: {true: l10n.yes, false: l10n.no},
            value: draft.hasLegalFather,
            errorText: state.showErrors && draft.hasLegalFather == null
                ? l10n.brRequired
                : null,
            onChanged: (named) => cubit.hasLegalFatherChanged(named: named),
          )
        : null;
    if (isFather && draft.hasLegalFather != true) {
      return AppFieldColumn(header: header, fields: [?question]);
    }

    return AppFieldColumn(
      header: header,
      fields: [
        ?question,
        _NinField(
          person: person,
          nin: parent[ParentField.nin],
          verified: parent.isNinVerified,
          errorText: _ninErrorText(
            l10n,
            state,
            person,
            parent.errorOf(ParentField.nin),
          ),
          onChanged: (value) =>
              cubit.legalParentChanged(person, ParentField.nin, value),
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
        f.select(
          ParentField.maritalStatus,
          l10n.srMaritalStatus,
          data.maritalStatuses,
        ),
        f.text(
          ParentField.address,
          l10n.srAddress,
          l10n.brAddressHint,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: _Fields.plain,
        ),
        f.select(ParentField.occupation, l10n.brOccupation, data.occupations),
        f.select(
          ParentField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.brPlaceOfResidence),
        f.select(
          ParentField.country,
          l10n.srCountryOfResidence,
          data.countries,
        ),
        if (shown(ParentField.state))
          f.select(
            ParentField.state,
            l10n.srStateOfResidence,
            data.stateOptions,
          ),
        if (shown(ParentField.lga))
          _lgaField(
            state,
            parent[ParentField.state],
            f.select(
              ParentField.lga,
              l10n.srLgaOfResidence,
              data.lgasOf(parent[ParentField.state]),
            ),
          ),
        f.select(
          ParentField.localityType,
          l10n.brLocalityType,
          data.localityTypes,
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
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
      ],
    );
  }
}
