part of 'death_form_page.dart';

/// Step 1, "Particulars of Deceased".
class _DeceasedStep extends StatelessWidget {
  const _DeceasedStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DeathFormCubit>();
    final state = context.watch<DeathFormCubit>().state;
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
      // The registrar's own state and LGA, while they
      // are among the options (so a bad location can't block the form).
      isLocked: (field) =>
          state.isLocked(field) ||
          cubit.registrarLocation != null &&
              switch (field) {
                DeceasedField.registrationState => data.stateOptions.any(
                  (o) => o.id == deceased[field],
                ),
                DeceasedField.registrationLga =>
                  data
                      .lgasOf(deceased[DeceasedField.registrationState])
                      .any((o) => o.id == deceased[field]),
                _ => false,
              },
    );
    bool shown(DeceasedField field) => deceased.applies(field);

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.sbStepDeceased,
        hint: l10n.drStepDeceasedHint,
      ),
      fields: [
        _NinField(
          owner: NinOwner.deceased,
          value: deceased[DeceasedField.nin],
          verified: deceased.ninVerified,
          note: l10n.brIfAvailable,
          errorText: f.errorOf(DeceasedField.nin),
          onChanged: (value) => cubit.deceasedChanged(DeceasedField.nin, value),
        ),
        if (shown(DeceasedField.noNinReason))
          f.text(
            DeceasedField.noNinReason,
            l10n.drNoNinReason,
            l10n.drNoNinReasonHint,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: _Fields.plain,
          ),
        f.text(
          DeceasedField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          DeceasedField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          DeceasedField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        f.select(DeceasedField.sex, l10n.brSex, data.sexes),
        _GreenTitle(l10n.drResidenceOfDeceased),
        f.select(DeceasedField.country, l10n.brCountry, data.countries),
        if (shown(DeceasedField.state))
          f.select(DeceasedField.state, l10n.brState, data.stateOptions),
        if (shown(DeceasedField.lga))
          _lgaField(
            state,
            deceased[DeceasedField.state],
            f.select(
              DeceasedField.lga,
              l10n.brLga,
              data.lgasOf(deceased[DeceasedField.state]),
            ),
          ),
        if (shown(DeceasedField.address))
          f.text(
            DeceasedField.address,
            l10n.drAddressOfResidence,
            l10n.brAddressHint,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: _Fields.plain,
          ),
        if (shown(DeceasedField.settlement))
          f.select(
            DeceasedField.settlement,
            l10n.sbSettlement,
            data.settlements,
          ),
        f.select(DeceasedField.occupation, l10n.brOccupation, data.occupations),
        AppDateField(
          key: const ValueKey(DeceasedField.dateOfDeath),
          label: l10n.drDateOfDeath,
          value: deceased.dateOfDeath,
          firstDate: DeceasedParticulars.earliestDeath,
          lastDate: today,
          errorText: f.errorOf(DeceasedField.dateOfDeath),
          onChanged: cubit.dateOfDeathChanged,
        ),
        f.select(
          DeceasedField.placeOfDeath,
          l10n.brPlaceOfOccurrence,
          data.placesOfDeath,
        ),
        f.text(
          DeceasedField.village,
          l10n.drVillage,
          l10n.sbVillageHint,
          inputFormatters: _Fields.plain,
        ),
        f.text(
          DeceasedField.ageAtDeath,
          l10n.drAgeAtDeath,
          l10n.brAgeHint,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: _Fields.digits(3),
        ),
        f.select(
          DeceasedField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        if (shown(DeceasedField.stateOfOrigin))
          f.select(
            DeceasedField.stateOfOrigin,
            l10n.brStateOfOrigin,
            data.stateOptions,
          ),
        if (shown(DeceasedField.lgaOfOrigin))
          _lgaField(
            state,
            deceased[DeceasedField.stateOfOrigin],
            f.select(
              DeceasedField.lgaOfOrigin,
              l10n.brLgaOfOrigin,
              data.lgasOf(deceased[DeceasedField.stateOfOrigin]),
            ),
          ),
        if (shown(DeceasedField.ethnicGroup))
          f.select(
            DeceasedField.ethnicGroup,
            l10n.drEthnicOrigin,
            data.ethnicGroups,
          ),
        f.select(
          DeceasedField.maritalStatus,
          l10n.drMaritalStatus,
          data.maritalStatuses,
        ),
        f.select(
          DeceasedField.literacy,
          l10n.brLiteracy,
          data.literacy,
          note: l10n.brOptional,
        ),
        if (shown(DeceasedField.educationLevel))
          f.select(
            DeceasedField.educationLevel,
            l10n.brEducationLevel,
            data.educationLevels,
          ),
        f.select(
          DeceasedField.certifiedByDoctor,
          l10n.drCertifiedByDoctor,
          data.yesNo,
        ),
        f.select(
          DeceasedField.causeOfDeath,
          l10n.drCauseOfDeath,
          data.causesOfDeath,
        ),
        f.select(
          DeceasedField.registrationState,
          l10n.drRegistrationState,
          data.stateOptions,
        ),
        _lgaField(
          state,
          deceased[DeceasedField.registrationState],
          f.select(
            DeceasedField.registrationLga,
            l10n.drRegistrationLga,
            data.lgasOf(deceased[DeceasedField.registrationState]),
          ),
        ),
        f.select(
          DeceasedField.registrationCenter,
          l10n.drRegistrationCenter,
          data.centersOf(
            deceased[DeceasedField.registrationState],
            deceased[DeceasedField.registrationLga],
          ),
        ),
      ],
    );
  }
}
