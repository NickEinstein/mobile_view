part of 'attestation_form_page.dart';

/// Step 2, "Additional Information".
class _AdditionalStep extends StatelessWidget {
  const _AdditionalStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationFormCubit>();
    final state = context.watch<AttestationFormCubit>().state;
    final draft = state.draft!;
    final data = state.referenceData!;
    final info = draft.additional;
    final fields = _Fields<AdditionalField>(
      l10n: l10n,
      valueOf: (field) => info[field],
      errorOf: (field) => _errorText(
        l10n,
        info.errorOf(field, correction: state.isCorrection),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.additionalChanged,
    );
    final registrationState = info[AdditionalField.registrationState];

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepAdditional,
        hint: l10n.baStepAdditionalHint,
      ),
      fields: [
        _DocumentTile(
          document: AttestationDocument.affidavit,
          label: l10n.baAffidavit,
        ),
        fields.select(
          AdditionalField.placeOfBirth,
          l10n.baPlaceOfBirth,
          data.placesOfBirth,
        ),
        fields.select(
          AdditionalField.stateOfBirth,
          l10n.brStateOfBirth,
          data.stateOptions,
        ),
        _lgaField(
          state,
          info[AdditionalField.stateOfBirth],
          fields.select(
            AdditionalField.lgaOfBirth,
            l10n.brLgaOfBirth,
            data.lgasOf(info[AdditionalField.stateOfBirth]),
          ),
        ),
        fields.text(
          AdditionalField.localityOfBirth,
          l10n.brLocalityOfBirth,
          l10n.brLocalityHint,
          note: l10n.brLocalityOfBirthNote,
        ),
        if (!state.isCorrection) ...[
          AppSectionTitle(l10n.baRegistrationSection),
          fields.select(
            AdditionalField.registrationState,
            l10n.brRegistrationState,
            data.stateOptions,
          ),
          _lgaField(
            state,
            registrationState,
            fields.select(
              AdditionalField.registrationLga,
              l10n.brRegistrationLga,
              data.lgasOf(registrationState),
            ),
          ),
          fields.select(
            AdditionalField.registrationCenter,
            l10n.brRegistrationCenter,
            data.centersOf(
              registrationState,
              info[AdditionalField.registrationLga],
            ),
          ),
        ],
        fields.text(
          AdditionalField.currentAddress,
          l10n.baCurrentAddress,
          l10n.brAddressHint,
        ),
        fields.select(
          AdditionalField.educationLevel,
          l10n.baEducationLevel,
          data.educationLevels,
        ),
        fields.select(
          AdditionalField.occupation,
          l10n.brOccupation,
          data.occupations,
        ),
        fields.text(
          AdditionalField.workAddress,
          l10n.baWorkAddress,
          l10n.brAddressHint,
        ),
        fields.select(
          AdditionalField.requestReason,
          l10n.baRequestReason,
          data.requestReasons,
        ),
        fields.select(
          AdditionalField.requiredFor,
          l10n.baRequiredFor,
          data.requirements,
        ),
        if (info.applies(AdditionalField.requiredForCountry))
          fields.select(
            AdditionalField.requiredForCountry,
            l10n.baRequiredForCountry,
            data.countries,
          ),
        fields.text(
          AdditionalField.requesterAddress,
          l10n.baRequesterAddress,
          l10n.brAddressHint,
          note: l10n.baRequesterAddressNote,
        ),
      ],
    );
  }
}
