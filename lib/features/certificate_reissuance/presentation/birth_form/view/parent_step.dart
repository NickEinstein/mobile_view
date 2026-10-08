part of 'birth_reissuance_form_page.dart';

/// Steps 2 and 3, the mother and the father.
class _ParentStep extends StatelessWidget {
  const _ParentStep({required this.role});

  final ParentRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BirthReissuanceFormCubit>();
    final state = context.watch<BirthReissuanceFormCubit>().state;
    final options = state.options!;
    final form = state.form!;
    final parent = form.parent(role);
    final isMother = role == ParentRole.mother;
    final birthOrder = form.child.birthOrder;
    final f = ReissuanceFields<ParentDetail>(
      l10n: l10n,
      valueOf: (field) => parent[field],
      errorOf: (field) => reissuanceErrorText(
        context,
        parent.errorOf(field, role, birthOrder: birthOrder),
        showRequired: state.showErrors,
        ageRange: ParentParticulars.ageRange(role, birthOrder: birthOrder),
      ),
      onChanged: (field, value) => cubit.parentChanged(role, field, value),
    );
    bool shown(ParentDetail field) => parent.applies(field, role);
    final same = parent[ParentDetail.sameResidenceAsMother];

    return AppFieldColumn(
      header: AppStepTitle(
        title: isMother ? l10n.brStepMother : l10n.brStepFather,
        hint: isMother ? l10n.brStepMotherHint : l10n.brStepFatherHint,
      ),
      fields: [
        f.text(
          ParentDetail.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        f.text(
          ParentDetail.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        if (shown(ParentDetail.maidenName))
          f.text(
            ParentDetail.maidenName,
            l10n.brMaidenName,
            l10n.brMaidenNameHint,
            inputFormatters: ReissuanceFields.name,
          ),
        ReissuanceSectionTitle(l10n.crPlaceOfUsualResidence),
        if (shown(ParentDetail.sameResidenceAsMother))
          AppRadioGroup<String>(
            key: const ValueKey(ParentDetail.sameResidenceAsMother),
            label: l10n.brSameAsMother,
            inline: true,
            options: {
              ParentParticulars.yes: l10n.yes,
              ParentParticulars.no: l10n.no,
            },
            value: same,
            onChanged: (value) => cubit.sameResidenceAsMother(
              same: value == ParentParticulars.yes,
            ),
          ),
        f.select(ParentDetail.country, l10n.brCountry, options.countries),
        f.select(
          ParentDetail.state,
          l10n.brState,
          state.statesOf(parent[ParentDetail.country]),
        ),
        if (shown(ParentDetail.lga))
          f.select(
            ParentDetail.lga,
            l10n.brLga,
            state.lgasOf(parent[ParentDetail.state]),
          ),
        f.text(
          ParentDetail.address,
          l10n.brAddress,
          l10n.brAddressHint,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(100),
          ],
          // "Same as mother's" fills it in.
          version: same,
        ),
        f.digits(
          ParentDetail.age,
          isMother ? l10n.brAgeOfMother : l10n.brAgeOfFather,
          l10n.brAgeHint,
          maxLength: 2,
        ),
        f.select(
          ParentDetail.maritalStatus,
          l10n.brMaritalStatus,
          options.maritalStatuses,
        ),
        f.select(
          ParentDetail.nationality,
          l10n.brNationality,
          options.nationalities,
        ),
        f.select(
          ParentDetail.stateOfOrigin,
          l10n.brStateOfOrigin,
          state.statesOf(parent[ParentDetail.nationality]),
        ),
        if (shown(ParentDetail.lgaOfOrigin))
          f.select(
            ParentDetail.lgaOfOrigin,
            l10n.brLgaOfOrigin,
            state.lgasOf(parent[ParentDetail.stateOfOrigin]),
          ),
        f.select(
          ParentDetail.ethnicGroup,
          l10n.brEthnicGroup,
          options.ethnicGroups,
        ),
        f.select(
          ParentDetail.literacy,
          l10n.brLiteracy,
          options.literacyLevels,
        ),
        if (shown(ParentDetail.educationLevel))
          f.select(
            ParentDetail.educationLevel,
            l10n.brEducationLevel,
            options.educationLevels,
          ),
        f.select(
          ParentDetail.occupation,
          l10n.brOccupation,
          options.occupations,
        ),
        f.digits(
          ParentDetail.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          maxLength: 15,
        ),
      ],
    );
  }
}
