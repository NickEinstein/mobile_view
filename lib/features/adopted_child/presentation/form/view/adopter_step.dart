part of 'adoption_form_page.dart';

/// Steps 2 and 3, the adopters. The second is optional, but checked once
/// started.
class _AdopterStep extends StatelessWidget {
  const _AdopterStep(this.adopter);

  final Adopter adopter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AdoptionFormCubit>();
    final state = context.watch<AdoptionFormCubit>().state;
    final data = state.referenceData!;
    final optional = adopter == Adopter.second;
    final particulars = state.draft!.adopter(adopter);
    final f = _Fields<AdopterField>(
      l10n: l10n,
      valueOf: (field) => particulars[field],
      errorOf: (field) => _errorText(
        l10n,
        particulars.errorOf(field, optional: optional),
        showRequired: state.showErrors,
      ),
      onChanged: (field, value) => cubit.adopterChanged(adopter, field, value),
      generation: particulars[AdopterField.verifiedNin],
    );
    bool shown(AdopterField field) => particulars.applies(field);

    return AppFieldColumn(
      header: AppStepTitle(
        title: optional ? l10n.acAdopter2Title : l10n.acAdopter1Title,
        hint: optional ? l10n.acAdopter2Hint : l10n.acAdopter1Hint,
      ),
      fields: [
        _NinField(
          fieldKey: adopter,
          nin: particulars[AdopterField.nin],
          verified: particulars.isNinVerified,
          checking: state.ninChecking == adopter,
          onValidate: () => cubit.validateNin(adopter),
          errorText: _ninErrorText(
            l10n,
            failure: switch (state.ninFailure) {
              (final who, final failure) when who == adopter => failure,
              _ => null,
            },
            fieldError: particulars.errorOf(
              AdopterField.nin,
              optional: optional,
            ),
            showRequired: state.showErrors,
          ),
          onChanged: (value) =>
              cubit.adopterChanged(adopter, AdopterField.nin, value),
        ),
        f.text(
          AdopterField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          AdopterField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          AdopterField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        f.select(
          AdopterField.maritalStatus,
          l10n.srMaritalStatus,
          data.maritalStatuses,
        ),
        f.select(
          AdopterField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        f.text(
          AdopterField.address,
          l10n.srAddress,
          l10n.brAddressHint,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: _Fields.plain,
        ),
        f.select(AdopterField.occupation, l10n.brOccupation, data.occupations),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.brPlaceOfResidence),
        f.select(
          AdopterField.country,
          l10n.srCountryOfResidence,
          data.countries,
        ),
        if (shown(AdopterField.state))
          f.select(
            AdopterField.state,
            l10n.srStateOfResidence,
            data.stateOptions,
          ),
        if (shown(AdopterField.lga))
          _lgaField(
            state,
            particulars[AdopterField.state],
            f.select(
              AdopterField.lga,
              l10n.srLgaOfResidence,
              data.lgasOf(particulars[AdopterField.state]),
            ),
          ),
        f.select(
          AdopterField.localityType,
          l10n.brLocalityType,
          data.localityTypes,
        ),
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.srAdditionalFields),
        f.select(AdopterField.literacy, l10n.brLiteracy, data.literacyLevels),
        if (shown(AdopterField.educationLevel))
          f.select(
            AdopterField.educationLevel,
            l10n.brEducationLevel,
            data.educationLevels,
          ),
        f.text(
          AdopterField.phone,
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
