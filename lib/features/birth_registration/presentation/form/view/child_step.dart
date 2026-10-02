part of 'registration_form_page.dart';

/// Step 1: "Particulars of Child".
class _ChildStep extends StatelessWidget {
  const _ChildStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
    final state = context.watch<RegistrationFormCubit>().state;
    final child = state.draft!.child;
    final data = state.referenceData!;
    final today = cubit.today;

    String? error(ChildField field) {
      final error = child.errorOf(field, today: today);
      // "Required" only after trying to continue; invalid values right away.
      if (error == null ||
          (error == ChildFieldError.required && !state.showErrors)) {
        return null;
      }
      return switch (error) {
        ChildFieldError.required => l10n.brRequired,
        ChildFieldError.futureDate => l10n.brFutureDate,
        ChildFieldError.notAChild => l10n.brNotAChild,
      };
    }

    Widget text(
      ChildField field,
      String label,
      String hint, {
      String? note,
      List<TextInputFormatter>? inputFormatters,
    }) => AppTextField(
      label: label,
      optionalLabel: note,
      hintText: hint,
      initialValue: child[field],
      inputFormatters: inputFormatters,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      errorText: error(field),
      onChanged: (value) => cubit.childChanged(field, value),
    );

    Widget select(
      ChildField field,
      String label,
      List<Option> options, {
      String? note,
    }) => AppSelectField<String>(
      label: label,
      optionalLabel: note,
      hint: l10n.brSelectOption,
      items: {for (final o in options) o.id: o.label},
      value: child[field],
      errorText: error(field),
      // Nothing to choose yet (e.g. no state picked for an LGA).
      onChanged: options.isEmpty
          ? null
          : (value) => cubit.childChanged(field, value),
    );

    final fields = <Widget>[
      text(
        ChildField.surname,
        l10n.brSurname,
        l10n.brSurnameHint,
        inputFormatters: nameFormatters,
      ),
      text(
        ChildField.firstName,
        l10n.brFirstName,
        l10n.brFirstNameHint,
        inputFormatters: nameFormatters,
      ),
      text(
        ChildField.middleName,
        l10n.brMiddleName,
        l10n.brMiddleNameHint,
        note: l10n.brOptional,
        inputFormatters: nameFormatters,
      ),
      AppDateField(
        label: l10n.brDateOfBirth,
        value: child.dateOfBirth,
        firstDate: DateTime(today.year - ChildParticulars.maxAgeYears),
        lastDate: today,
        errorText: error(ChildField.dateOfBirth),
        onChanged: (date) => cubit.childChanged(
          ChildField.dateOfBirth,
          DateTime(date.year, date.month, date.day).toIso8601String(),
        ),
      ),
      select(ChildField.typeOfBirth, l10n.brTypeOfBirth, data.typesOfBirth),
      select(
        ChildField.birthOrder,
        l10n.brBirthOrder,
        data.birthOrders,
        note: l10n.brBirthOrderNote,
      ),
      select(ChildField.sex, l10n.brSex, data.sexes),
      select(
        ChildField.placeOfOccurrence,
        l10n.brPlaceOfOccurrence,
        data.placesOfOccurrence,
      ),
      select(ChildField.stateOfBirth, l10n.brStateOfBirth, data.stateOptions),
      _lgaField(
        state,
        child[ChildField.stateOfBirth],
        select(
          ChildField.lgaOfBirth,
          l10n.brLgaOfBirth,
          data.lgasOf(child[ChildField.stateOfBirth]),
        ),
      ),
      text(
        ChildField.localityOfBirth,
        l10n.brLocalityOfBirth,
        l10n.brLocalityHint,
        note: l10n.brLocalityOfBirthNote,
      ),
      select(ChildField.stateOfOrigin, l10n.brStateOfOrigin, data.stateOptions),
      _lgaField(
        state,
        child[ChildField.stateOfOrigin],
        select(
          ChildField.lgaOfOrigin,
          l10n.brLgaOfOrigin,
          data.lgasOf(child[ChildField.stateOfOrigin]),
        ),
      ),
      text(ChildField.townOfOrigin, l10n.brTownOfOrigin, l10n.brLocalityHint),
      select(
        ChildField.registrationState,
        l10n.brRegistrationState,
        data.stateOptions,
      ),
      _lgaField(
        state,
        child[ChildField.registrationState],
        select(
          ChildField.registrationLga,
          l10n.brRegistrationLga,
          data.lgasOf(child[ChildField.registrationState]),
        ),
      ),
      select(
        ChildField.registrationCenter,
        l10n.brRegistrationCenter,
        data.centersOf(
          child[ChildField.registrationState],
          child[ChildField.registrationLga],
        ),
      ),
      select(ChildField.localityType, l10n.brLocalityType, data.localityTypes),
      _FaceCaptureField(
        photoPath: child[ChildField.facePhoto],
        onCaptured: cubit.childPhotoCaptured,
        errorText: error(ChildField.facePhoto),
      ),
    ];

    return _FieldColumn(
      header: _StepTitle(title: l10n.brStepChild, hint: l10n.brStepChildHint),
      fields: fields,
    );
  }
}
