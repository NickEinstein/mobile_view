part of 'surrogacy_form_page.dart';

/// Step 5, the surrogate mother: optional, but checked once started.
class _SurrogateMotherStep extends StatelessWidget {
  const _SurrogateMotherStep();

  static const _person = SurrogacyPerson.surrogateMother;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;
    final data = state.referenceData!;
    final mother = state.draft!.surrogateMother;
    final f = _Fields<SurrogateField>(
      l10n: l10n,
      valueOf: (field) => mother[field],
      errorOf: (field) => _errorText(
        l10n,
        mother.errorOf(field),
        showRequired: state.showErrors,
        minAge: mother.minAgeForBirthOrder,
      ),
      onChanged: cubit.surrogateMotherChanged,
      generation: mother[SurrogateField.verifiedNin],
    );
    bool shown(SurrogateField field) => mother.applies(field);

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.srSurrogateMotherTitle,
        hint: l10n.srSurrogateMotherHint,
      ),
      fields: [
        _NinField(
          person: _person,
          nin: mother[SurrogateField.nin],
          verified: mother.isNinVerified,
          errorText: _ninErrorText(
            l10n,
            state,
            _person,
            mother.errorOf(SurrogateField.nin),
          ),
          onChanged: (value) =>
              cubit.surrogateMotherChanged(SurrogateField.nin, value),
        ),
        f.text(
          SurrogateField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          SurrogateField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          SurrogateField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        f.text(
          SurrogateField.ageAtBirth,
          l10n.srAgeAtBirth,
          l10n.brAgeHint,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        f.select(
          SurrogateField.birthOrder,
          l10n.brBirthOrder,
          data.birthOrders,
        ),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.srAdditionalFields),
        f.text(
          SurrogateField.address,
          l10n.srAddress,
          l10n.brAddressHint,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: _Fields.plain,
        ),
        f.select(
          SurrogateField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        f.select(
          SurrogateField.countryOfOrigin,
          l10n.srCountryOfOrigin,
          data.countries,
        ),
        if (shown(SurrogateField.stateOfOrigin))
          f.select(
            SurrogateField.stateOfOrigin,
            l10n.brStateOfOrigin,
            data.stateOptions,
          ),
        if (shown(SurrogateField.lgaOfOrigin))
          _lgaField(
            state,
            mother[SurrogateField.stateOfOrigin],
            f.select(
              SurrogateField.lgaOfOrigin,
              l10n.brLgaOfOrigin,
              data.lgasOf(mother[SurrogateField.stateOfOrigin]),
            ),
          ),
        f.text(
          SurrogateField.town,
          l10n.srTownVillage,
          l10n.srTownVillageHint,
          inputFormatters: _Fields.plain,
        ),
        f.select(
          SurrogateField.localityType,
          l10n.brLocalityType,
          data.localityTypes,
        ),
        f.select(SurrogateField.literacy, l10n.brLiteracy, data.literacyLevels),
        if (shown(SurrogateField.educationLevel))
          f.select(
            SurrogateField.educationLevel,
            l10n.brEducationLevel,
            data.educationLevels,
          ),
        f.select(
          SurrogateField.occupation,
          l10n.brOccupation,
          data.occupations,
        ),
        f.text(
          SurrogateField.phone,
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
