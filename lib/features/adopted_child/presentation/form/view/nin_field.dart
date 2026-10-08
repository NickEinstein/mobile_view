part of 'adoption_form_page.dart';

/// The NIN with "Validate" ("Verified" once validated).
class _NinField extends StatelessWidget {
  const _NinField({
    required this.fieldKey,
    required this.nin,
    required this.verified,
    required this.checking,
    required this.onValidate,
    required this.errorText,
    required this.onChanged,
  });

  /// Whose NIN, so each person's input keeps its own text.
  final Object fieldKey;
  final String? nin;
  final bool verified;

  /// The identity service is being asked.
  final bool checking;
  final Future<void> Function() onValidate;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final canValidate =
        !verified && nin != null && nin!.length == 11 && !checking;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            key: ValueKey((fieldKey, 'nin')),
            label: l10n.srNinLabel,
            hintText: l10n.brNinHint,
            initialValue: nin,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            errorText: errorText,
            onChanged: (value) => onChanged(value.trim()),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Padding(
          padding: const EdgeInsets.only(top: 26),
          child: verified
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.srVerified,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppPalette.brand),
                      ),
                      const SizedBox(width: Spacing.xs),
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppPalette.brand,
                      ),
                    ],
                  ),
                )
              : FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.logoGreenDark,
                    minimumSize: const Size(88, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: canValidate ? () => unawaited(onValidate()) : null,
                  child: checking
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l10n.brValidate),
                ),
        ),
      ],
    );
  }
}

/// The NIN's error: a failed validation first, then the field's own rule.
String? _ninErrorText(
  AppLocalizations l10n, {
  required Failure? failure,
  required AdoptionFieldError? fieldError,
  required bool showRequired,
}) => switch (failure) {
  NotFoundFailure() => l10n.baNinNotFound,
  final failure? => failure.localize(l10n),
  null => _errorText(l10n, fieldError, showRequired: showRequired),
};
