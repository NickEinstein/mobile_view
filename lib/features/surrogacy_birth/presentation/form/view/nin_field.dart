part of 'surrogacy_form_page.dart';

/// The NIN with "Validate" ("Verified" once validated).
class _NinField extends StatelessWidget {
  const _NinField({
    required this.person,
    required this.nin,
    required this.verified,
    required this.errorText,
    required this.onChanged,
  });

  final SurrogacyPerson person;
  final String? nin;
  final bool verified;
  final String? errorText;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SurrogacyFormCubit>();
    final checking = context.select(
      (SurrogacyFormCubit cubit) => cubit.state.ninChecking == person,
    );
    final canValidate =
        !verified && nin != null && nin!.length == 11 && !checking;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            key: ValueKey((person, 'nin')),
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
          // Level with the input, below its label.
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
                  onPressed: canValidate
                      ? () => unawaited(cubit.validateNin(person))
                      : null,
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
  AppLocalizations l10n,
  SurrogacyFormState state,
  SurrogacyPerson person,
  SurrogacyFieldError? fieldError,
) {
  if (state.ninFailure case (final who, final failure) when who == person) {
    return failure is NotFoundFailure
        ? l10n.baNinNotFound
        : failure.localize(l10n);
  }
  return _errorText(l10n, fieldError, showRequired: state.showErrors);
}
