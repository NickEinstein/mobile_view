part of 'registration_form_page.dart';

/// The buttons under each step, then "Exit Application".
class _FormActions extends StatelessWidget {
  const _FormActions({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<RegistrationFormCubit>();
    final state = context.watch<RegistrationFormCubit>().state;
    final step = state.step;
    final submitting = state.submitStatus == SubmitStatus.submitting;

    // Grey until the step can go on; a tap before then shows what's
    // missing.
    final Widget primary = switch (step) {
      RegistrationStep.review => AppButton(
        label: l10n.brSubmit,
        muted: !state.canSubmit(cubit.today),
        isLoading: submitting,
        onPressed: () => unawaited(cubit.submit()),
      ),
      _ => AppButton(
        label: step == RegistrationStep.child
            ? l10n.brSaveContinue
            : l10n.brNext,
        muted: !state.isStepComplete(cubit.today),
        onPressed: cubit.next,
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (submitting) ...[
            LinearProgressIndicator(
              value: state.progress,
              semanticsLabel: l10n.brSubmitting,
            ),
            const SizedBox(height: Spacing.sm),
          ],
          if (step == RegistrationStep.child)
            primary
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.inkStrong,
                    ),
                    onPressed: submitting ? null : cubit.previous,
                    child: Text(l10n.brPrevious),
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(child: primary),
              ],
            ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppPalette.inkStrong),
            onPressed: onExit,
            child: Text(l10n.brExitApplication),
          ),
        ],
      ),
    );
  }
}
