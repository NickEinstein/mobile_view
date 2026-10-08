part of 'attestation_form_page.dart';

/// Step 1, "Particulars of Applicant". Prefilled from the NIN record when
/// there is one; the face comes from face validation.
class _ApplicantStep extends StatelessWidget {
  const _ApplicantStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationFormCubit>();
    final state = context.watch<AttestationFormCubit>().state;
    final draft = state.draft!;
    final data = state.referenceData!;
    final applicant = draft.applicant;
    final today = cubit.today;
    String? error(ApplicantField field) => _errorText(
      l10n,
      applicant.errorOf(field, today: today, nin: draft.ninRecord),
      showRequired: state.showErrors,
    );
    final fields = _Fields<ApplicantField>(
      l10n: l10n,
      valueOf: (field) => applicant[field],
      errorOf: error,
      onChanged: cubit.applicantChanged,
      isLocked: state.isLocked,
    );

    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepApplicant,
        hint: l10n.baStepApplicantHint,
      ),
      fields: [
        fields.text(ApplicantField.surname, l10n.brSurname, l10n.brSurnameHint),
        fields.text(
          ApplicantField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
        ),
        fields.text(
          ApplicantField.middleName,
          l10n.brMiddleName,
          l10n.brMiddleNameHint,
          note: l10n.brOptional,
        ),
        fields.select(ApplicantField.sex, l10n.brSex, data.sexes),
        AppDateField(
          label: l10n.brDateOfBirth,
          value: applicant.dateOfBirth,
          firstDate: DateTime(1900),
          lastDate: today,
          errorText: error(ApplicantField.dateOfBirth),
          onChanged: cubit.dateOfBirthChanged,
        ),
        fields.select(
          ApplicantField.maritalStatus,
          l10n.baMaritalStatus,
          data.maritalStatuses,
        ),
        fields.select(
          ApplicantField.stateOfOrigin,
          l10n.brStateOfOrigin,
          data.stateOptions,
        ),
        _lgaField(
          state,
          applicant[ApplicantField.stateOfOrigin],
          fields.select(
            ApplicantField.lgaOfOrigin,
            l10n.brLgaOfOrigin,
            data.lgasOf(applicant[ApplicantField.stateOfOrigin]),
          ),
        ),
        fields.text(
          ApplicantField.townOfOrigin,
          l10n.baTownOfOrigin,
          l10n.baTownHint,
        ),
        fields.select(ApplicantField.idType, l10n.baIdType, data.identityTypes),
        fields.text(
          ApplicantField.idNumber,
          l10n.baIdNumber,
          l10n.baIdNumberHint,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
            LengthLimitingTextInputFormatter(20),
          ],
        ),
        fields.text(
          ApplicantField.email,
          l10n.emailLabel,
          l10n.emailHint,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
        ),
        fields.text(
          ApplicantField.phone,
          l10n.brPhoneNumber,
          l10n.brPhoneHint,
          note: l10n.brOptional,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        const _FaceCaptured(),
      ],
    );
  }
}

/// "Capture Applicant Face" in its captured state: the photo from face
/// validation.
class _FaceCaptured extends StatelessWidget {
  const _FaceCaptured();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.brCaptureFace,
          style: textTheme.bodyMedium?.copyWith(color: AppPalette.inkStrong),
        ),
        const SizedBox(height: Spacing.sm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppPalette.selectedCardFill,
            border: Border.all(color: AppPalette.brand),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.brFaceCaptured,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppPalette.brand,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle, color: AppPalette.brand),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
