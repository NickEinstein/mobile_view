part of 'death_form_page.dart';

/// Step 4, "Information Preview": every answer by step, each with "Edit",
/// then the informant's signature and the declaration.
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  Future<void> _saveSignature(BuildContext context, Uint8List png) async {
    final cubit = context.read<DeathFormCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await cubit.signatureDrawn(png);
    } on Exception {
      messenger.showSnackBar(SnackBar(content: Text(l10n.brSignatureFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DeathFormCubit>();
    final state = context.watch<DeathFormCubit>().state;
    final draft = state.draft!;
    final today = cubit.today;
    final signature = draft.signature;
    final stepsComplete = DeathStep.values
        .where((s) => s != DeathStep.review)
        .every((s) => state.isComplete(s, today));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppStepTitle(title: l10n.brReviewTitle, hint: l10n.brReviewHint),
        const SizedBox(height: Spacing.lg),
        DeathSections(
          draft: draft,
          data: state.referenceData!,
          onEdit: cubit.editStep,
          isComplete: (step) => state.isComplete(step, today),
        ),
        if (!stepsComplete && state.showErrors) ...[
          Text(
            l10n.brSectionIncomplete,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: Spacing.md),
        ],
        AppSignaturePad(
          label: l10n.brInformantSignature,
          hint: l10n.brSignHere,
          clearTooltip: l10n.brClearSignature,
          saved: signature == null ? null : FileImage(File(signature)),
          onSigned: (png) => unawaited(_saveSignature(context, png)),
          onCleared: () => unawaited(cubit.signatureCleared()),
          errorText: state.showErrors && !draft.hasSignature
              ? l10n.brRequired
              : null,
        ),
        // A recorded signature stays unless the informant signs again.
        if (signature == null && draft.hasSignature)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              l10n.drSignatureOnFile,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppPalette.muted),
            ),
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
