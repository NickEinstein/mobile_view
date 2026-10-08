part of 'surrogacy_form_page.dart';

/// Step 8, "Information Review": every section as entered, each with Edit,
/// then the declaration.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final state = context.watch<SurrogacyFormCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brStepReview, hint: l10n.brReviewHint),
        if (state.queryReason case final reason?) ...[
          const SizedBox(height: Spacing.md),
          _QueryBanner(reason),
        ],
        const SizedBox(height: Spacing.lg),
        SurrogacySections(
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

/// "Queried: …", in red, while correcting a queried application.
class _QueryBanner extends StatelessWidget {
  const _QueryBanner(this.reason);

  final String reason;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: error),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.sm + Spacing.xs),
        child: Text(
          context.l10n.srQueriedBecause(reason),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: error),
        ),
      ),
    );
  }
}
