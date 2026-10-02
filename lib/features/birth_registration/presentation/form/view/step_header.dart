part of 'registration_form_page.dart';

/// Title, start date, six-segment progress bar, "Step n of 6 · Step name".
class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.startedOn});

  final RegistrationStep step;
  final DateTime startedOn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.brFormTitle,
            style: textTheme.titleLarge?.copyWith(
              color: AppPalette.inkStrong,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            DateFormat.yMMMMd(locale).format(startedOn),
            style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
          ),
          const SizedBox(height: Spacing.md),
          Semantics(
            label: l10n.brStepOf(step.number, RegistrationStep.count),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  for (final s in RegistrationStep.values) ...[
                    if (s.index > 0) const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 4,
                        decoration: BoxDecoration(
                          color: s.index <= step.index
                              ? AppPalette.brand
                              : AppPalette.cardBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Text(
                l10n.brStepOf(step.number, RegistrationStep.count),
                style: textTheme.labelSmall?.copyWith(
                  color: AppPalette.inkStrong,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  step.title(l10n),
                  textAlign: TextAlign.end,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppPalette.brand,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension on RegistrationStep {
  String title(AppLocalizations l10n) => switch (this) {
    RegistrationStep.child => l10n.brStepChild,
    RegistrationStep.mother => l10n.brStepMother,
    RegistrationStep.father => l10n.brStepFather,
    RegistrationStep.informant => l10n.brStepInformant,
    RegistrationStep.documents => l10n.brStepDocuments,
    RegistrationStep.review => l10n.brStepReview,
  };
}
