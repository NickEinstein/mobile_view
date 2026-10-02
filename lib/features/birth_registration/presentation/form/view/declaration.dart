part of 'registration_form_page.dart';

/// "I hereby certify…".
class _Declaration extends StatelessWidget {
  const _Declaration({
    required this.declared,
    required this.showError,
    required this.onChanged,
  });

  final bool declared;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppPalette.warningContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: showError
                  ? theme.colorScheme.error
                  : AppPalette.accentYellow,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(!declared),
            child: MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: declared,
                      visualDensity: VisualDensity.compact,
                      onChanged: (value) => onChanged(value ?? false),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: Spacing.sm),
                        child: Text(
                          l10n.brDeclaration,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppPalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: Spacing.xs),
            child: Text(
              l10n.brDeclarationRequired,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
      ],
    );
  }
}
