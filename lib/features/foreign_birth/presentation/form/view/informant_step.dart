part of 'foreign_birth_form_page.dart';

/// Step 4, "Particulars of Informant". Father or Mother fills it from that
/// parent; consent is a signature or a face capture.
class _InformantStep extends StatelessWidget {
  const _InformantStep();

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final cubit = context.read<ForeignBirthFormCubit>();
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
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;
    final data = state.referenceData!;
    final informant = state.draft!.informant;
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
      isLocked: informant.isLocked,
      // Remount when the NIN, a parent or "same residence" fills fields in.
      generation: (
        informant[InformantField.verifiedNin],
        informant[InformantField.relationship],
        informant[InformantField.sameResidence],
      ),
    );
    bool shown(InformantField field) => informant.applies(field);
    final signature = informant[InformantField.signature];

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepInformant,
        hint: l10n.brStepInformantHint,
      ),
      fields: [
        f.select(
          InformantField.relationship,
          l10n.srRelationshipToChild,
          data.relationships,
        ),
        _NinField(
          fieldKey: (ForeignBirthStep.informant, f.generation),
          nin: informant[InformantField.nin],
          verified: informant.isNinVerified,
          checking: state.informantNinChecking,
          onValidate: cubit.validateInformantNin,
          note: informant.isRequired(InformantField.nin)
              ? null
              : l10n.brOptional,
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
          label: l10n.fbSameResidenceAsMother,
          options: {Answer.yes: l10n.yes, Answer.no: l10n.no},
          value: informant[InformantField.sameResidence],
          onChanged: (value) =>
              cubit.informantChanged(InformantField.sameResidence, value),
        ),
        f.select(
          InformantField.country,
          l10n.srCountryOfResidence,
          data.countryOptions,
        ),
        f.select(
          InformantField.state,
          l10n.srStateOfResidence,
          state.statesOf(informant[InformantField.country]),
        ),
        if (shown(InformantField.lga))
          f.select(
            InformantField.lga,
            l10n.srLgaOfResidence,
            state.lgasOf(informant[InformantField.state]),
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
          InformantField.stateOfOrigin,
          l10n.fbStateOfOrigin,
          state.statesOf(informant[InformantField.nationality]),
          note: informant.isRequired(InformantField.stateOfOrigin)
              ? null
              : l10n.brOptional,
        ),
        if (shown(InformantField.lgaOfOrigin))
          f.select(
            InformantField.lgaOfOrigin,
            l10n.brLgaOfOrigin,
            state.lgasOf(informant[InformantField.stateOfOrigin]),
          ),
        f.text(
          InformantField.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            ..._Fields.digits,
            LengthLimitingTextInputFormatter(15),
          ],
        ),
        f.text(
          InformantField.email,
          l10n.fbInformantEmail,
          l10n.emailHint,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [LengthLimitingTextInputFormatter(100)],
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
            saved: switch ((signature, state.fileUrl(signature))) {
              (null, _) => null,
              // On record (a queried notification): its stored image.
              (_, final String url) => NetworkImage(url),
              (final String path, null) => FileImage(File(path)),
            },
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
