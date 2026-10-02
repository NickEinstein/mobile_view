part of 'registration_form_page.dart';

/// Step 6 "Information Review": everything entered, with an Edit link per
/// step, and the declaration to tick before submitting.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
    final formState = context.watch<RegistrationFormCubit>().state;
    final draft = formState.draft!;
    return _FieldColumn(
      header: _StepTitle(title: l10n.brReviewTitle, hint: l10n.brReviewHint),
      fields: [
        ApplicationSections(
          referenceData: formState.referenceData!,
          child: draft.child,
          childNin: draft.childNin,
          mother: draft.mother,
          father: draft.father,
          informant: draft.informant,
          documents: draft.documents,
          onEdit: cubit.editStep,
          isIncomplete: (step) => !formState.isComplete(step, cubit.today),
        ),
        _Declaration(
          declared: formState.declared,
          showError: formState.showErrors && !formState.declared,
          onChanged: (declared) => cubit.declarationChanged(declared: declared),
        ),
      ],
    );
  }
}
