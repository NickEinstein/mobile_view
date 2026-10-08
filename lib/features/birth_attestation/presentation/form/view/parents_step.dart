part of 'attestation_form_page.dart';

/// Step 3, "Parent's Information": mother, then father. A parent of
/// another nationality gives a passport instead of a state of origin.
class _ParentsStep extends StatelessWidget {
  const _ParentsStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppFieldColumn(
      header: AppStepTitle(
        title: l10n.baStepParents,
        hint: l10n.baStepParentsHint,
      ),
      fields: [
        for (final parent in Parent.values) ..._parentFields(context, parent),
      ],
    );
  }

  List<Widget> _parentFields(BuildContext context, Parent parent) {
    final l10n = context.l10n;
    final cubit = context.read<AttestationFormCubit>();
    final state = context.watch<AttestationFormCubit>().state;
    final data = state.referenceData!;
    final info = state.draft!.parent(parent);
    final fields = _Fields<ParentInfoField>(
      l10n: l10n,
      valueOf: (field) => info[field],
      errorOf: (field) => _errorText(
        l10n,
        info.errorOf(field, parent),
        showRequired: state.showErrors,
      ),
      onChanged: (field, value) => cubit.parentChanged(parent, field, value),
    );
    final mother = parent == Parent.mother;

    return [
      if (!mother) const SizedBox(height: Spacing.md),
      AppSectionTitle(mother ? l10n.baMotherSection : l10n.baFatherSection),
      KeyedSubtree(
        key: ValueKey((parent, ParentInfoField.surname)),
        child: fields.text(
          ParentInfoField.surname,
          l10n.brSurname,
          l10n.brSurnameHint,
        ),
      ),
      KeyedSubtree(
        key: ValueKey((parent, ParentInfoField.firstName)),
        child: fields.text(
          ParentInfoField.firstName,
          l10n.brFirstName,
          l10n.brFirstNameHint,
        ),
      ),
      if (info.applies(ParentInfoField.maidenName, parent))
        KeyedSubtree(
          key: ValueKey((parent, ParentInfoField.maidenName)),
          child: fields.text(
            ParentInfoField.maidenName,
            l10n.brMaidenName,
            l10n.brMaidenNameHint,
          ),
        ),
      KeyedSubtree(
        key: ValueKey((parent, ParentInfoField.nationality)),
        child: fields.select(
          ParentInfoField.nationality,
          l10n.brNationality,
          data.nationalityOptions,
        ),
      ),
      if (info.needsPassport)
        _DocumentTile(
          key: ValueKey(parent.passport),
          document: parent.passport,
          label: l10n.baPassport,
        )
      else ...[
        KeyedSubtree(
          key: ValueKey((parent, ParentInfoField.stateOfOrigin)),
          child: fields.select(
            ParentInfoField.stateOfOrigin,
            l10n.brStateOfOrigin,
            data.stateOptions,
          ),
        ),
        KeyedSubtree(
          key: ValueKey((parent, ParentInfoField.lgaOfOrigin)),
          child: _lgaField(
            state,
            info[ParentInfoField.stateOfOrigin],
            fields.select(
              ParentInfoField.lgaOfOrigin,
              l10n.brLgaOfOrigin,
              data.lgasOf(info[ParentInfoField.stateOfOrigin]),
            ),
          ),
        ),
        KeyedSubtree(
          key: ValueKey((parent, ParentInfoField.town)),
          child: fields.text(
            ParentInfoField.town,
            l10n.baTown,
            l10n.baTownHint,
          ),
        ),
      ],
    ];
  }
}
