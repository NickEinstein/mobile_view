part of 'still_birth_form_page.dart';

/// Step 2, "Particulars of Mother".
class _MotherStep extends StatelessWidget {
  const _MotherStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StillBirthFormCubit>();
    final state = context.watch<StillBirthFormCubit>().state;
    final data = state.referenceData!;
    final mother = state.draft!.mother;
    final f = _Fields<MotherField>(
      l10n: l10n,
      valueOf: (field) => mother[field],
      errorOf: (field) => _errorText(
        l10n,
        mother.errorOf(field),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.motherChanged,
    );
    bool shown(MotherField field) => mother.applies(field);

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepMother,
        hint: l10n.brStepMotherHint,
      ),
      fields: [
        f.text(
          MotherField.fullName,
          l10n.sbFullName,
          l10n.sbFullNameHint,
          note: l10n.sbSurnameFirst,
          inputFormatters: [
            ..._Fields.name,
            LengthLimitingTextInputFormatter(100),
          ],
        ),
        _ResidenceTitle(l10n.brPlaceOfResidence),
        f.select(MotherField.country, l10n.brCountry, data.countries),
        if (shown(MotherField.state))
          f.select(MotherField.state, l10n.brState, data.stateOptions),
        if (shown(MotherField.lga))
          _lgaField(
            state,
            mother[MotherField.state],
            f.select(
              MotherField.lga,
              l10n.brLga,
              data.lgasOf(mother[MotherField.state]),
            ),
          ),
        if (shown(MotherField.address))
          f.text(
            MotherField.address,
            l10n.sbAddress,
            l10n.brAddressHint,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [
              ..._Fields.plain,
              LengthLimitingTextInputFormatter(100),
            ],
          ),
        if (shown(MotherField.settlement))
          f.select(MotherField.settlement, l10n.sbSettlement, data.settlements),
        f.text(
          MotherField.age,
          l10n.sbAge,
          l10n.brAgeHint,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
        ),
        f.select(
          MotherField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        if (shown(MotherField.stateOfOrigin))
          f.select(
            MotherField.stateOfOrigin,
            l10n.brStateOfOrigin,
            data.stateOptions,
          ),
        if (shown(MotherField.ethnicGroup))
          f.select(
            MotherField.ethnicGroup,
            l10n.brEthnicGroup,
            data.ethnicGroups,
          ),
      ],
    );
  }
}

/// "Place of Residence", in green as the designs draw it.
class _ResidenceTitle extends StatelessWidget {
  const _ResidenceTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.brand,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
