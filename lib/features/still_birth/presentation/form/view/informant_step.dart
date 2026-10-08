part of 'still_birth_form_page.dart';

/// Step 3, "Particulars of Informant", who signs; "Mother" copies her
/// name and address.
class _InformantStep extends StatelessWidget {
  const _InformantStep();

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final cubit = context.read<StillBirthFormCubit>();
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
    final cubit = context.read<StillBirthFormCubit>();
    final state = context.watch<StillBirthFormCubit>().state;
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
    );
    bool shown(InformantField field) => informant.applies(field);
    final signature = informant[InformantField.signature];
    final relationship = informant[InformantField.relationship];

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.brStepInformant,
        hint: l10n.brStepInformantHint,
      ),
      fields: [
        f.select(
          InformantField.relationship,
          l10n.sbRelationship,
          data.relationships,
        ),
        // Keyed by the relationship too, so text copied from the mother
        // shows up.
        KeyedSubtree(
          key: ValueKey((InformantField.fullName, relationship)),
          child: f.text(
            InformantField.fullName,
            l10n.sbFullName,
            l10n.sbFullNameHint,
            note: l10n.sbSurnameFirst,
            inputFormatters: [
              ..._Fields.name,
              LengthLimitingTextInputFormatter(150),
            ],
          ),
        ),
        _ResidenceTitle(l10n.brPlaceOfResidence),
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
          KeyedSubtree(
            key: ValueKey((InformantField.address, relationship)),
            child: f.text(
              InformantField.address,
              l10n.sbAddress,
              l10n.brAddressHint,
              textCapitalization: TextCapitalization.sentences,
              inputFormatters: [
                ..._Fields.plain,
                LengthLimitingTextInputFormatter(100),
              ],
            ),
          ),
        if (shown(InformantField.settlement))
          f.select(
            InformantField.settlement,
            l10n.sbSettlement,
            data.settlements,
          ),
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
      ],
    );
  }
}
