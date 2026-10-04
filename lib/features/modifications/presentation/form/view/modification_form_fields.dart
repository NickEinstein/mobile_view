part of 'modification_form_page.dart';

/// The record, in the designs' sections: the child (or applicant, or the
/// deceased), then the parents. Only the requested change can be edited.
class _RecordFields extends StatelessWidget {
  const _RecordFields();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ModificationFormCubit>();
    final state = context.watch<ModificationFormCubit>().state;
    final sexes = {'1': l10n.modSexMale, '2': l10n.modSexFemale};
    final states = {for (final o in state.states) o.id: o.label};
    Map<String, String> lgas(RecordField field) => {
      for (final o in state.lgasFor(field)) o.id: o.label,
    };
    // A queried request shows only what it changes.
    bool shown(RecordField field) =>
        !cubit.isQueried || state.edit.editable.contains(field);

    List<Widget> section(String title, Map<RecordField, Widget> fields) {
      final visible = [
        for (final MapEntry(key: field, value: widget) in fields.entries)
          if (shown(field)) widget,
      ];
      return [
        if (visible.isNotEmpty) ...[
          _SectionTitle(title),
          ...visible,
          const SizedBox(height: Spacing.lg),
        ],
      ];
    }

    Map<RecordField, Widget> names(List<RecordField> fields) => {
      for (final (i, field) in fields.indexed)
        field: _TextField(
          field: field,
          label: [l10n.brSurname, l10n.brFirstName, l10n.brMiddleName][i],
          isName: true,
        ),
    };

    final person = names(const [
      RecordField.surname,
      RecordField.firstName,
      RecordField.middleName,
    ]);
    final sex = {
      RecordField.sex: _SelectField(
        field: RecordField.sex,
        label: l10n.brSex,
        items: sexes,
      ),
    };
    final dateOfBirth = {
      RecordField.dateOfBirth: _DateField(
        field: RecordField.dateOfBirth,
        label: l10n.brDateOfBirth,
      ),
    };
    Map<RecordField, Widget> place({
      required RecordField state,
      required RecordField lga,
      required RecordField town,
      required List<String> labels,
    }) => {
      state: _SelectField(field: state, label: labels[0], items: states),
      lga: _SelectField(field: lga, label: labels[1], items: lgas(lga)),
      town: _TextField(field: town, label: labels[2]),
    };
    final placeOfBirth = place(
      state: RecordField.birthState,
      lga: RecordField.birthLga,
      town: RecordField.birthTown,
      labels: [
        l10n.brStateOfBirth,
        l10n.brLgaOfBirth,
        if (cubit.request.kind == ModificationKind.birth)
          l10n.brLocalityOfBirth
        else
          l10n.modTownOfBirth,
      ],
    );
    final mother = names(const [
      RecordField.motherSurname,
      RecordField.motherFirstName,
      RecordField.motherMiddleName,
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: switch (cubit.request.kind) {
        ModificationKind.birth => [
          ...section(l10n.brStepChild, {
            ...person,
            ...dateOfBirth,
            ...sex,
            ...placeOfBirth,
          }),
          ...section(l10n.brStepMother, mother),
          ...section(
            l10n.brStepFather,
            names(const [
              RecordField.fatherSurname,
              RecordField.fatherFirstName,
              RecordField.fatherMiddleName,
            ]),
          ),
        ],
        ModificationKind.attestation => [
          ...section(l10n.baStepApplicant, {
            ...person,
            ...sex,
            ...dateOfBirth,
            ...placeOfBirth,
            ...place(
              state: RecordField.originState,
              lga: RecordField.originLga,
              town: RecordField.originTown,
              labels: [
                l10n.brStateOfOrigin,
                l10n.brLgaOfOrigin,
                l10n.baTownOfOrigin,
              ],
            ),
          }),
          ...section(l10n.brStepMother, mother),
          ...section(
            l10n.brStepFather,
            names(const [
              RecordField.fatherSurname,
              RecordField.fatherFirstName,
            ]),
          ),
        ],
        ModificationKind.death => [
          ...section(l10n.modStepDeceased, {
            ...person,
            ...sex,
            RecordField.dateOfDeath: _DateField(
              field: RecordField.dateOfDeath,
              label: l10n.modDateOfDeath,
            ),
            RecordField.ageAtDeath: _TextField(
              field: RecordField.ageAtDeath,
              label: l10n.modAgeAtDeath,
              isNumber: true,
            ),
          }),
        ],
      },
    );
  }
}

/// "| Particulars of Child", with the designs' green bar.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Spacing.sm),
    child: Row(
      children: [
        Container(width: 2, height: 18, color: AppPalette.brand),
        const SizedBox(width: Spacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

String? _errorText(BuildContext context, RecordField field) {
  final cubit = context.read<ModificationFormCubit>();
  final state = context.watch<ModificationFormCubit>().state;
  if (!state.showErrors) return null;
  final l10n = context.l10n;
  return switch (state.edit.errorOf(field, today: cubit.today)) {
    RecordEditError.required => l10n.brRequired,
    RecordEditError.invalidName => l10n.modInvalidName,
    RecordEditError.invalidAge => l10n.modInvalidAge,
    RecordEditError.futureDate => l10n.modFutureDate,
    RecordEditError.unchanged || null => null,
  };
}

class _TextField extends StatelessWidget {
  const _TextField({
    required this.field,
    required this.label,
    this.isName = false,
    this.isNumber = false,
  });

  final RecordField field;
  final String label;
  final bool isName;
  final bool isNumber;

  static final _nameCharacters = FilteringTextInputFormatter.allow(
    RegExp(r"[A-Za-z '\-]"),
  );

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModificationFormCubit>();
    final edit = context.select(
      (ModificationFormCubit cubit) => cubit.state.edit,
    );
    final editable = edit.editable.contains(field);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: AppTextField(
        key: ValueKey(field),
        label: label,
        optionalLabel: field.isOptional ? context.l10n.brOptional : null,
        initialValue: edit[field],
        enabled: editable,
        textCapitalization: TextCapitalization.words,
        keyboardType: isNumber ? TextInputType.number : null,
        inputFormatters: isName
            ? [_nameCharacters]
            : isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        errorText: _errorText(context, field),
        onChanged: (value) => unawaited(cubit.valueChanged(field, value)),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.field,
    required this.label,
    required this.items,
  });

  final RecordField field;
  final String label;
  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModificationFormCubit>();
    final edit = context.select(
      (ModificationFormCubit cubit) => cubit.state.edit,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: AppSelectField<String>(
        label: label,
        hint: context.l10n.brSelectOption,
        items: items,
        value: edit[field],
        errorText: _errorText(context, field),
        onChanged: edit.editable.contains(field)
            ? (value) => unawaited(cubit.valueChanged(field, value))
            : null,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.field, required this.label});

  final RecordField field;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ModificationFormCubit>();
    final edit = context.select(
      (ModificationFormCubit cubit) => cubit.state.edit,
    );
    final value = edit[field];
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: AppDateField(
        label: label,
        value: value == null ? null : DateTime.tryParse(value),
        firstDate: DateTime(1900),
        lastDate: cubit.today,
        enabled: edit.editable.contains(field),
        errorText: _errorText(context, field),
        onChanged: (date) => unawaited(
          cubit.valueChanged(field, DateFormat('yyyy-MM-dd').format(date)),
        ),
      ),
    );
  }
}
