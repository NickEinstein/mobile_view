part of 'adoption_form_page.dart';

/// Step 7, "Information Review": every section as entered, each with Edit,
/// then the declaration. A queried application shows why it was queried.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<AdoptionFormCubit>();
    final state = context.watch<AdoptionFormCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brStepReview, hint: l10n.brReviewHint),
        if (state.queryReason case final reason?) ...[
          const SizedBox(height: Spacing.md),
          AppReviewEntry(l10n.acQueryReason, reason),
        ],
        const SizedBox(height: Spacing.lg),
        AdoptionSections(
          draft: state.draft!,
          data: state.referenceData!,
          onEdit: cubit.editStep,
          isIncomplete: (step) =>
              state.showErrors && !state.isComplete(step, cubit.today),
        ),
        const SizedBox(height: Spacing.lg),
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
