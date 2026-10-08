part of 'adoption_form_page.dart';

/// Step 5, "Particulars of Informant". The informant consents by drawing a
/// signature or by a face capture.
class _InformantStep extends StatelessWidget {
  const _InformantStep();

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final cubit = context.read<AdoptionFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await cubit.informantSignatureDrawn(png);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brSignatureFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AdoptionFormCubit>();
    final state = context.watch<AdoptionFormCubit>().state;
    final data = state.referenceData!;
    final draft = state.draft!;
    final informant = draft.informant;
    String? error(InformantField field) => _errorText(
      l10n,
      informant.errorOf(field),
      showRequired: state.showErrors,
    );
    final f = _Fields<InformantField>(
      l10n: l10n,
      valueOf: (field) => informant[field],
      errorOf: error,
      onChanged: cubit.informantChanged,
      // Remount when the NIN or "same residence" fills fields in.
      generation: (
        informant[InformantField.verifiedNin],
        informant[InformantField.sameResidence],
      ),
    );
    bool shown(InformantField field) => informant.applies(field);
    final signature = informant[InformantField.signature];

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepInformant,
        hint: l10n.acInformantHint,
      ),
      fields: [
        _NinField(
          fieldKey: AdoptionStep.informant,
          nin: informant[InformantField.nin],
          verified: informant.isNinVerified,
          checking: state.informantNinChecking,
          onValidate: cubit.validateInformantNin,
          errorText: _ninErrorText(
            l10n,
            failure: state.informantNinFailure,
            fieldError: informant.errorOf(InformantField.nin),
            showRequired: state.showErrors,
          ),
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
        const SizedBox(height: Spacing.sm),
        _GroupTitle(l10n.brPlaceOfResidence),
        AppRadioGroup<String>(
          key: const ValueKey(InformantField.sameResidence),
          label: l10n.acSameResidenceAsAdopter,
          options: {Answer.yes: l10n.yes, Answer.no: l10n.no},
          value: informant[InformantField.sameResidence],
          onChanged: (value) =>
              cubit.informantChanged(InformantField.sameResidence, value),
        ),
        f.select(
          InformantField.country,
          l10n.srCountryOfResidence,
          data.countries,
        ),
        if (shown(InformantField.state))
          f.select(
            InformantField.state,
            l10n.srStateOfResidence,
            data.stateOptions,
          ),
        if (shown(InformantField.lga))
          _lgaField(
            state,
            informant[InformantField.state],
            f.select(
              InformantField.lga,
              l10n.srLgaOfResidence,
              data.lgasOf(informant[InformantField.state]),
            ),
          ),
        f.text(
          InformantField.address,
          l10n.brAddress,
          l10n.brAddressHint,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: _Fields.plain,
        ),
        f.select(
          InformantField.nationality,
          l10n.brNationality,
          data.nationalities,
        ),
        f.select(
          InformantField.countryOfOrigin,
          l10n.srCountryOfOrigin,
          data.countries,
        ),
        if (shown(InformantField.stateOfOrigin))
          f.select(
            InformantField.stateOfOrigin,
            l10n.srStateOfOriginLong,
            data.stateOptions,
          ),
        if (shown(InformantField.lgaOfOrigin))
          _lgaField(
            state,
            informant[InformantField.stateOfOrigin],
            f.select(
              InformantField.lgaOfOrigin,
              l10n.brLgaOfOrigin,
              data.lgasOf(informant[InformantField.stateOfOrigin]),
            ),
          ),
        f.select(
          InformantField.relationship,
          l10n.srRelationshipToChild,
          data.relationships,
        ),
        f.text(
          InformantField.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        f.text(
          InformantField.passportNumber,
          l10n.srPassportNumber,
          l10n.srPassportNumberHint,
          note: l10n.brOptional,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        _PhotoUpload(
          label: l10n.srPassportUpload,
          required: false,
          file: draft.informantPassport,
          onPicked: cubit.passportPicked,
          onRemove: () => unawaited(cubit.passportRemoved()),
        ),
        AppRadioGroup<String>(
          key: const ValueKey(InformantField.consentType),
          label: l10n.srConsentType,
          inline: true,
          options: {
            ConsentType.signature: l10n.srDrawSignature,
            ConsentType.faceCapture: l10n.srCaptureFace,
          },
          value: informant[InformantField.consentType],
          errorText: error(InformantField.consentType),
          onChanged: (value) =>
              cubit.informantChanged(InformantField.consentType, value),
        ),
        if (shown(InformantField.signature))
          AppSignaturePad(
            key: const ValueKey(InformantField.signature),
            label: l10n.brInformantSignature,
            hint: l10n.brSignHere,
            clearTooltip: l10n.brClearSignature,
            saved: signature == null ? null : FileImage(File(signature)),
            onSigned: (png) => unawaited(_saveSignature(context, png)),
            onCleared: () => unawaited(cubit.informantSignatureCleared()),
            errorText: error(InformantField.signature),
          ),
        if (shown(InformantField.face))
          _FaceField(
            label: l10n.srInformantFace,
            optional: false,
            photoPath: informant[InformantField.face],
            onCaptured: cubit.informantFaceCaptured,
            errorText: error(InformantField.face),
          ),
      ],
    );
  }
}
