part of 'still_birth_form_page.dart';

/// Step 4, "Information Preview": every answer by step, each with "Edit",
/// then the declaration.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<StillBirthFormCubit>();
    final state = context.watch<StillBirthFormCubit>().state;
    final today = cubit.today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brReviewTitle, hint: l10n.brReviewHint),
        const SizedBox(height: Spacing.lg),
        StillBirthSections(
          draft: state.draft!,
          data: state.referenceData!,
          onEdit: cubit.editStep,
          isComplete: (step) => state.isComplete(step, today),
        ),
        if (!state.isComplete(StillBirthStep.review, today) &&
            state.showErrors) ...[
          Text(
            l10n.brSectionIncomplete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: Spacing.md),
        ],
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
