part of 'attestation_reissuance_form_page.dart';

/// Step 1, "Particulars of Applicant", prefilled from the NIN; the email
/// is confirmed by code.
class _ApplicantStep extends StatelessWidget {
  const _ApplicantStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final state = context.watch<AttestationReissuanceFormCubit>().state;
    final options = state.options!;
    final applicant = state.form!.applicant;
    String? error(ApplicantDetail field) => reissuanceErrorText(
      context,
      applicant.errorOf(field, today: cubit.today),
      showRequired: state.showErrors,
    );
    final f = ReissuanceFields<ApplicantDetail>(
      l10n: l10n,
      valueOf: (field) => applicant[field],
      errorOf: error,
      onChanged: cubit.applicantChanged,
    );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepApplicant,
        hint: l10n.baStepApplicantHint,
      ),
      fields: [
        f.text(
          ApplicantDetail.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        f.text(
          ApplicantDetail.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: ReissuanceFields.name,
        ),
        f.text(
          ApplicantDetail.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
          inputFormatters: ReissuanceFields.name,
        ),
        f.select(
          ApplicantDetail.sex,
          l10n.brSex,
          options.sexes,
          enabled: !state.sexLocked,
        ),
        AppDateField(
          label: l10n.brDateOfBirth,
          value: applicant.dateOfBirth,
          firstDate: DateTime(1900),
          lastDate: ReissuanceCodes.latestBirthDate,
          errorText: error(ApplicantDetail.dateOfBirth),
          onChanged: cubit.dateOfBirthChanged,
        ),
        f.select(
          ApplicantDetail.maritalStatus,
          l10n.baMaritalStatus,
          options.maritalStatuses,
        ),
        f.select(
          ApplicantDetail.stateOfOrigin,
          l10n.brStateOfOrigin,
          state.nigeria,
        ),
        f.select(
          ApplicantDetail.lgaOfOrigin,
          l10n.brLgaOfOrigin,
          state.lgasOf(applicant[ApplicantDetail.stateOfOrigin]),
        ),
        f.text(
          ApplicantDetail.town,
          l10n.baTownOfOrigin,
          l10n.baTownHint,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(50),
          ],
        ),
        f.select(ApplicantDetail.idType, l10n.baIdType, options.identityTypes),
        f.text(
          ApplicantDetail.idNumber,
          l10n.baIdNumber,
          l10n.baIdNumberHint,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [LengthLimitingTextInputFormatter(30)],
        ),
        EmailCodeField(
          label: l10n.crApplicantEmail,
          showErrors: state.showErrors,
          notVerifiedText: l10n.crApplicantEmailNotVerified,
          onChanged: (value) =>
              cubit.applicantChanged(ApplicantDetail.email, value),
        ),
        f.digits(
          ApplicantDetail.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          maxLength: 15,
        ),
      ],
    );
  }
}

/// Step 2, "Additional Information": where the applicant was born and
/// registers, and why the attestation is needed.
class _AdditionalStep extends StatelessWidget {
  const _AdditionalStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final state = context.watch<AttestationReissuanceFormCubit>().state;
    final options = state.options!;
    final additional = state.form!.additional;
    final f = ReissuanceFields<AdditionalDetail>(
      l10n: l10n,
      valueOf: (field) => additional[field],
      errorOf: (field) => reissuanceErrorText(
        context,
        additional.errorOf(field),
        showRequired: state.showErrors,
      ),
      onChanged: cubit.additionalChanged,
    );
    Widget address(AdditionalDetail field, String label, {String? note}) =>
        f.text(
          field,
          label,
          l10n.brAddressHint,
          note: note,
          textCapitalization: TextCapitalization.sentences,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(100),
          ],
        );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepAdditional,
        hint: l10n.baStepAdditionalHint,
      ),
      fields: [
        f.select(
          AdditionalDetail.placeOfBirth,
          l10n.baPlaceOfBirth,
          options.placesOfOccurrence,
        ),
        f.select(
          AdditionalDetail.typeOfBirth,
          l10n.brTypeOfBirth,
          options.typesOfBirth,
        ),
        f.select(
          AdditionalDetail.stateOfBirth,
          l10n.brStateOfBirth,
          state.nigeria,
        ),
        f.select(
          AdditionalDetail.lgaOfBirth,
          l10n.brLgaOfBirth,
          state.lgasOf(additional[AdditionalDetail.stateOfBirth]),
        ),
        f.text(
          AdditionalDetail.townOfBirth,
          l10n.brLocalityOfBirth,
          l10n.brLocalityHint,
          note: l10n.crLocalityOfBirthNote,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(50),
          ],
        ),
        f.select(
          AdditionalDetail.registrationState,
          l10n.brRegistrationState,
          state.nigeria,
        ),
        f.select(
          AdditionalDetail.registrationLga,
          l10n.brRegistrationLga,
          state.lgasOf(additional[AdditionalDetail.registrationState]),
        ),
        f.select(
          AdditionalDetail.registrationCenter,
          l10n.brRegistrationCenter,
          options.centresIn(additional[AdditionalDetail.registrationLga]),
        ),
        address(AdditionalDetail.currentAddress, l10n.baCurrentAddress),
        f.select(
          AdditionalDetail.educationLevel,
          l10n.baEducationLevel,
          options.educationLevels,
        ),
        f.select(
          AdditionalDetail.occupation,
          l10n.brOccupation,
          options.occupations,
        ),
        address(AdditionalDetail.workAddress, l10n.baWorkAddress),
        f.select(
          AdditionalDetail.requestReason,
          l10n.baRequestReason,
          options.requestReasons,
        ),
        f.select(
          AdditionalDetail.requiredFor,
          l10n.baRequiredFor,
          options.requirements,
        ),
        if (additional.applies(AdditionalDetail.country))
          f.select(
            AdditionalDetail.country,
            l10n.baRequiredForCountry,
            options.countries,
          ),
        address(
          AdditionalDetail.requesterAddress,
          l10n.baRequesterAddress,
          note: l10n.baRequesterAddressNote,
        ),
      ],
    );
  }
}

/// Step 3, "Parent's Information": each parent's names and origin
/// (Nigerian states and LGAs).
class _ParentsStep extends StatelessWidget {
  const _ParentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final state = context.watch<AttestationReissuanceFormCubit>().state;
    final form = state.form!;

    List<Widget> fields(ParentRole role) {
      final parent = form.parent(role);
      final f = ReissuanceFields<AttestationParentDetail>(
        l10n: l10n,
        valueOf: (field) => parent[field],
        errorOf: (field) => reissuanceErrorText(
          context,
          parent.errorOf(field, role),
          showRequired: state.showErrors,
        ),
        onChanged: (field, value) => cubit.parentChanged(role, field, value),
      );
      return [
        ReissuanceSectionTitle(
          role == ParentRole.father
              ? l10n.baFatherSection
              : l10n.baMotherSection,
        ),
        f.text(
          AttestationParentDetail.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
          inputFormatters: ReissuanceFields.name,
          version: role,
        ),
        f.text(
          AttestationParentDetail.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
          inputFormatters: ReissuanceFields.name,
          version: role,
        ),
        if (role == ParentRole.mother)
          f.text(
            AttestationParentDetail.maidenName,
            l10n.brMaidenName,
            l10n.brMaidenNameHint,
            inputFormatters: ReissuanceFields.name,
            version: role,
          ),
        f.select(
          AttestationParentDetail.state,
          l10n.brStateOfOrigin,
          state.nigeria,
          version: role,
        ),
        f.select(
          AttestationParentDetail.lga,
          l10n.brLgaOfOrigin,
          state.lgasOf(parent[AttestationParentDetail.state]),
          version: role,
        ),
        f.text(
          AttestationParentDetail.town,
          l10n.baTown,
          l10n.baTownHint,
          inputFormatters: [
            ...ReissuanceFields.plain,
            LengthLimitingTextInputFormatter(50),
          ],
          version: role,
        ),
      ];
    }

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepParents,
        hint: l10n.baStepParentsHint,
      ),
      fields: [...fields(ParentRole.father), ...fields(ParentRole.mother)],
    );
  }
}

/// Step 4: the court affidavit and the applicant's signature, both
/// required.
class _DocumentsStep extends StatelessWidget {
  const _DocumentsStep({required this.pickPhoto});

  final PickPhoto pickPhoto;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final image = await pickPhoto(context);
      if (image == null) return;
      final error = await cubit.affidavitPicked(
        path: image.path,
        name: image.name,
        sizeBytes: await image.length(),
      );
      if (error != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(switch (error) {
              DocumentError.tooLarge => l10n.brDocTooLarge,
              DocumentError.unsupportedType => l10n.brDocUnsupported,
            }),
          ),
        );
      }
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brCameraFailed)));
    }
  }

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l10n.brSignatureFailed;
    try {
      await context.read<AttestationReissuanceFormCubit>().signatureDrawn(png);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final state = context.watch<AttestationReissuanceFormCubit>().state;
    final form = state.form!;
    final affidavit = form.affidavit;
    final signature = form.signature;

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.crStepDocuments,
        hint: l10n.crStepAttestationDocumentsHint,
      ),
      fields: [
        AppUploadTile(
          label: l10n.baAffidavit,
          uploadLabel: l10n.crUploadAffidavit,
          note: l10n.crAffidavitNote,
          removeLabel: l10n.brRemoveDocument(l10n.baAffidavit),
          fileName:
              affidavit?.name ??
              (form.keptAffidavit == null ? null : l10n.baAffidavit),
          fileDetail: affidavit == null
              ? (form.keptAffidavit == null ? null : l10n.crKeptDocument)
              : '${affidavit.name} · ${fileSize(affidavit.sizeBytes)}',
          onPick: () => unawaited(_pick(context)),
          onRemove: form.hasAffidavit
              ? () => unawaited(cubit.affidavitRemoved())
              : null,
          errorText: state.showErrors && !form.hasAffidavit
              ? l10n.crAffidavitRequired
              : null,
        ),
        AppSignaturePad(
          key: const ValueKey('signature'),
          label: l10n.crApplicantSignature,
          hint: l10n.brSignHere,
          clearTooltip: l10n.brClearSignature,
          saved: signature == null ? null : FileImage(File(signature)),
          onSigned: (png) => unawaited(_saveSignature(context, png)),
          onCleared: () => unawaited(cubit.signatureCleared()),
          errorText: state.showErrors && !form.hasSignature
              ? l10n.crApplicantSignatureRequired
              : null,
        ),
        if (signature == null && form.keptSignature != null)
          Text(
            l10n.crKeptSignature,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppPalette.muted),
          ),
      ],
    );
  }
}

/// Step 5, "Information Preview": every answer by step, each with "Edit",
/// then the declaration.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationReissuanceFormCubit>();
    final state = context.watch<AttestationReissuanceFormCubit>().state;
    final facePhoto = state.draft?.facePhoto;
    final faceUrl = state.record?.faceUrl;
    final query = state.record?.query;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brReviewTitle, hint: l10n.brReviewHint),
        const SizedBox(height: Spacing.lg),
        if (query != null) ...[
          ReissuanceQueryNote(query: query),
          const SizedBox(height: Spacing.md),
        ],
        AttestationReissuanceSections(
          certificate: state.certificate!,
          form: state.form!,
          options: state.options!,
          nigeria: state.nigeria,
          lgasOf: state.lgasOf,
          today: cubit.today,
          face: facePhoto != null
              ? FileImage(File(facePhoto))
              : faceUrl != null
              ? NetworkImage(faceUrl.toString())
              : null,
          onEdit: cubit.editStep,
          showErrors: state.showErrors,
        ),
        const SizedBox(height: Spacing.md),
        AppDeclaration(
          text: l10n.brDeclaration,
          declared: state.declared,
          onChanged: (declared) => cubit.declarationChanged(declared: declared),
          errorText: state.showErrors && !state.declared
              ? l10n.brDeclarationRequired
              : null,
        ),
      ],
    );
  }
}
