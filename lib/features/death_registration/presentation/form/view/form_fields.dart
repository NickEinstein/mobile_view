part of 'death_form_page.dart';

/// Builds a step's inputs, keyed by field so none inherits another's text.
class _Fields<F extends Enum> {
  const _Fields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
    this.isLocked,
  });

  final AppLocalizations l10n;
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  /// Read-only fields, e.g. names from a NIN.
  final bool Function(F field)? isLocked;

  bool _locked(F field) => isLocked?.call(field) ?? false;

  /// Letters, spaces, apostrophes and hyphens, as names allow.
  static final name = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
    LengthLimitingTextInputFormatter(30),
  ];

  /// No special characters, for addresses and places.
  static final plain = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.'-]")),
    LengthLimitingTextInputFormatter(200),
  ];

  static List<TextInputFormatter> digits(int max) => [
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(max),
  ];

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
    Key? key,
  }) => AppTextField(
    // The value can change underneath (a verified NIN's names, a copied
    // address); keying by it shows the new one.
    key: key ?? ValueKey((field, _locked(field) ? valueOf(field) : null)),
    label: label,
    optionalLabel: _locked(field) ? l10n.drFromNin : note,
    hintText: hint,
    initialValue: valueOf(field),
    enabled: !_locked(field),
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textInputAction: TextInputAction.next,
    errorText: errorOf(field),
    onChanged: (value) => onChanged(field, value.trim()),
  );

  Widget select(F field, String label, List<Option> options, {String? note}) =>
      AppSelectField<String>(
        key: ValueKey(field),
        label: label,
        optionalLabel: note,
        hint: l10n.brSelectOption,
        items: {for (final o in options) o.id: o.label},
        value: valueOf(field),
        errorText: errorOf(field),
        // Nothing to choose yet (e.g. no state picked for an LGA), or
        // locked.
        onChanged: options.isEmpty || (isLocked?.call(field) ?? false)
            ? null
            : (value) => onChanged(field, value),
      );
}

/// Under an LGA field whose state's LGAs failed to load: says so, and
/// offers to try again.
class _LgasUnavailable extends StatelessWidget {
  const _LgasUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.brLgasUnavailable,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
        TextButton(
          onPressed: context.read<DeathFormCubit>().retryLgas,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// [select] for the LGAs of [stateId], with [_LgasUnavailable] under it
/// when they failed to load.
Widget _lgaField(DeathFormState state, String? stateId, Widget select) =>
    state.lgasUnavailable.contains(stateId)
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [select, const _LgasUnavailable()],
      )
    : select;

/// Localized [error], or null. "Required" waits until the user tries to
/// continue; invalid values show straight away.
String? _errorText(
  AppLocalizations l10n,
  DeathFieldError? error, {
  required bool showRequired,
}) => switch (error) {
  null => null,
  DeathFieldError.required ||
  DeathFieldError.ninNotVerified when !showRequired => null,
  DeathFieldError.required => l10n.brRequired,
  DeathFieldError.ninNotVerified => l10n.drNinNotVerified,
  DeathFieldError.futureDate => l10n.brFutureDate,
  DeathFieldError.tooEarly => l10n.drDateTooEarly,
  DeathFieldError.invalidAge => l10n.drInvalidAgeAtDeath(
    DeceasedParticulars.maxAge,
  ),
  DeathFieldError.invalidNin => l10n.brNinInvalid,
  DeathFieldError.invalidPhone => l10n.drInvalidPhone,
};

/// A NIN field with "Verify" beside it. Once verified, the names it gave
/// fill the form.
class _NinField extends StatelessWidget {
  const _NinField({
    required this.owner,
    required this.value,
    required this.verified,
    required this.errorText,
    required this.onChanged,
    this.note,
  });

  final NinOwner owner;
  final String? value;
  final bool verified;
  final String? errorText;
  final ValueChanged<String?> onChanged;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<DeathFormCubit>();
    final state = context.watch<DeathFormCubit>().state;
    final verifying = state.verifying.contains(owner);
    final failure = state.ninFailures[owner];
    final value = this.value;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AppTextField(
            key: ValueKey(owner),
            label: l10n.brNin,
            optionalLabel: verified ? l10n.drVerified : note,
            hintText: l10n.brNinHint,
            initialValue: value,
            enabled: !verifying,
            keyboardType: TextInputType.number,
            inputFormatters: _Fields.digits(11),
            textInputAction: TextInputAction.next,
            errorText: switch (failure) {
              null => errorText,
              NotFoundFailure() => l10n.baNinNotFound,
              _ => failure.localize(l10n),
            },
            onChanged: (text) => onChanged(text.trim()),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        Padding(
          // Lines the button up with the field, under its label.
          padding: const EdgeInsets.only(top: 28),
          child: SizedBox(
            height: 48,
            child: verified
                ? const Icon(
                    Icons.check_circle,
                    color: AppPalette.brand,
                    size: 32,
                  )
                : FilledButton(
                    onPressed: verifying || value == null || value.length != 11
                        ? null
                        : () => unawaited(cubit.verifyNin(owner)),
                    child: verifying
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.drVerify),
                  ),
          ),
        ),
      ],
    );
  }
}

/// "Place of Usual Residence (Deceased)", in green as the designs draw it.
class _GreenTitle extends StatelessWidget {
  const _GreenTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.brand,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
