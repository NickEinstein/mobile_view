part of 'registration_form_page.dart';

/// Step 4 "Particulars of Informant": who is reporting the birth, and their
/// signature or face as proof of identity.
class _InformantStep extends StatelessWidget {
  const _InformantStep();

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final cubit = context.read<RegistrationFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await cubit.signatureDrawn(png);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brSignatureFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
    final formState = context.watch<RegistrationFormCubit>().state;
    final draft = formState.draft!;
    final data = formState.referenceData!;
    final informant = draft.informant;

    final f = _Fields<InformantField>(
      l10n: l10n,
      valueOf: (field) => informant[field],
      errorOf: (field) => _personError(
        l10n,
        informant.errorOf(field, parentsGaveNin: draft.parentsGaveNin),
        showRequired: formState.showErrors,
      ),
      onChanged: cubit.informantChanged,
    );
    bool shown(InformantField field) => informant.applies(field);
    final idNote = draft.parentsGaveNin
        ? l10n.brIfAvailable
        : l10n.brInformantNinNote;
    final signature = informant[InformantField.signature];

    return _FieldColumn(
      header: _StepTitle(
        title: l10n.brStepInformant,
        hint: l10n.brStepInformantHint,
      ),
      fields: [
        f.select(
          InformantField.relationship,
          l10n.brRelationship,
          data.relationships,
        ),
        f.name(InformantField.surname, l10n.brSurname, l10n.brSurnameHint),
        f.name(
          InformantField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
        ),
        f.name(
          InformantField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
        ),
        _SectionTitle(l10n.brPlaceOfResidence),
        f.yesNo(InformantField.sameResidenceAsMother, l10n.brSameAsMother),
        if (shown(InformantField.country))
          f.select(InformantField.country, l10n.brCountry, data.countries),
        if (shown(InformantField.state))
          f.select(InformantField.state, l10n.brState, data.stateOptions),
        if (shown(InformantField.lga))
          _lgaField(
            formState,
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
            l10n.brAddress,
            l10n.brAddressHint,
            textCapitalization: TextCapitalization.sentences,
          ),
        if (shown(InformantField.settlement))
          f.select(
            InformantField.settlement,
            l10n.brSettlement,
            data.localityTypes,
          ),
        f.phone(InformantField.phone),
        f.digits(
          InformantField.nin,
          l10n.brNin,
          l10n.brNinHint,
          maxLength: 11,
          note: idNote,
        ),
        f.text(
          InformantField.trackingId,
          l10n.brTrackingId,
          l10n.brTrackingIdHint,
          note: l10n.brIfAvailable,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(15)],
        ),
        AppRadioGroup<IdentityMode>(
          key: const ValueKey(InformantField.identityMode),
          label: l10n.brIdentityMode,
          options: {
            IdentityMode.signature: l10n.brModeSignature,
            IdentityMode.face: l10n.brModeFace,
          },
          value: informant.identityMode,
          onChanged: (mode) =>
              cubit.informantChanged(InformantField.identityMode, mode.name),
        ),
        if (shown(InformantField.signature))
          AppSignaturePad(
            key: const ValueKey(InformantField.signature),
            label: l10n.brInformantSignature,
            hint: l10n.brSignHere,
            clearTooltip: l10n.brClearSignature,
            saved: signature == null ? null : FileImage(File(signature)),
            onSigned: (png) => unawaited(_saveSignature(context, png)),
            onCleared: () => unawaited(cubit.signatureCleared()),
            errorText: f.errorOf(InformantField.signature),
          ),
        if (shown(InformantField.facePhoto))
          _FaceCaptureField(
            key: const ValueKey(InformantField.facePhoto),
            photoPath: informant[InformantField.facePhoto],
            errorText: f.errorOf(InformantField.facePhoto),
            onCaptured: cubit.informantPhotoCaptured,
          ),
      ],
    );
  }
}
