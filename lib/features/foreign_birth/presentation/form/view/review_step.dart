part of 'foreign_birth_form_page.dart';

/// Step 6, "Information Review", then the declaration.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ForeignBirthFormCubit>();
    final state = context.watch<ForeignBirthFormCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brStepReview, hint: l10n.brReviewHint),
        if (state.record?.queryReason case final reason?) ...[
          const SizedBox(height: Spacing.md),
          AppReviewEntry(l10n.acQueryReason, reason),
        ],
        const SizedBox(height: Spacing.lg),
        ForeignBirthSections(
          draft: state.draft!,
          data: state.referenceData!,
          stateName: (countryId, stateId) =>
              _label(state.statesOf(countryId), stateId),
          lgaName: (stateId, lgaId) => _label(state.lgasOf(stateId), lgaId),
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

String? _label(List<Option> options, String? id) {
  for (final option in options) {
    if (option.id == id) return option.label;
  }
  return null;
}
