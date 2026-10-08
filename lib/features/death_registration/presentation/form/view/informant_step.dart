part of 'death_form_page.dart';

/// Step 2, "Particulars of Informant".
class _InformantStep extends StatelessWidget {
  const _InformantStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DeathFormCubit>();
    final state = context.watch<DeathFormCubit>().state;
    final data = state.referenceData!;
    final informant = state.draft!.informant;
    final f = _Fields<InformantField>(
      l10n: l10n,
      valueOf: (field) => informant[field],
      errorOf: (field) => _errorText(
        l10n,
        informant.errorOf(field),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.informantChanged,
      isLocked: state.isInformantLocked,
    );
    bool shown(InformantField field) => informant.applies(field);
    final same = informant[InformantField.sameAddress];

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepInformant,
        hint: l10n.brStepInformantHint,
      ),
      fields: [
        _NinField(
          owner: NinOwner.informant,
          value: informant[InformantField.nin],
          verified: informant.ninVerified,
          errorText: f.errorOf(InformantField.nin),
          onChanged: (value) =>
              cubit.informantChanged(InformantField.nin, value),
        ),
        f.text(
          InformantField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          InformantField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: _Fields.name,
        ),
        f.text(
          InformantField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: _Fields.name,
        ),
        f.select(
          InformantField.relationship,
          l10n.sbRelationship,
          data.relationships,
        ),
        AppSectionTitle(l10n.brPlaceOfResidence),
        AppRadioGroup<String>(
          key: const ValueKey(InformantField.sameAddress),
          label: l10n.drSameAsDeceased,
          inline: true,
          options: {DeathCodes.yes: l10n.yes, DeathCodes.no: l10n.no},
          value: same,
          errorText: f.errorOf(InformantField.sameAddress),
          onChanged: (value) =>
              cubit.informantChanged(InformantField.sameAddress, value),
        ),
        f.select(InformantField.country, l10n.brCountry, data.countries),
        if (shown(InformantField.state))
          f.select(InformantField.state, l10n.brState, data.stateOptions),
        if (shown(InformantField.lga))
          _lgaField(
            state,
            informant[InformantField.state],
            f.select(
              InformantField.lga,
              l10n.brLga,
              data.lgasOf(informant[InformantField.state]),
            ),
          ),
        if (shown(InformantField.address))
          f.text(
            InformantField.address,
            l10n.drStreetName,
            l10n.brAddressHint,
            // A copied address replaces what was typed.
            key: ValueKey((InformantField.address, same)),
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: _Fields.plain,
          ),
        if (shown(InformantField.settlement))
          f.select(
            InformantField.settlement,
            l10n.sbSettlement,
            data.settlements,
          ),
        f.text(
          InformantField.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: _Fields.digits(11),
        ),
      ],
    );
  }
}
