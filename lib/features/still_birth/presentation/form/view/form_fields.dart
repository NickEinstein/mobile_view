part of 'still_birth_form_page.dart';

/// Builds a step's inputs, keyed by field so none inherits another's text.
class _Fields<F extends Enum> {
  const _Fields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
  });

  final AppLocalizations l10n;
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  /// Letters, spaces, apostrophes and hyphens, as names allow.
  static final name = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
  ];

  /// No special characters, for addresses and places.
  static final plain = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.'-]")),
  ];

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) => AppTextField(
    key: ValueKey(field),
    label: label,
    optionalLabel: note,
    hintText: hint,
    initialValue: valueOf(field),
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    textCapitalization: textCapitalization,
    textInputAction: TextInputAction.next,
    errorText: errorOf(field),
    onChanged: (value) => onChanged(field, value.trim()),
  );

  Widget select(F field, String label, List<Option> options) =>
      AppSelectField<String>(
        key: ValueKey(field),
        label: label,
        hint: l10n.brSelectOption,
        items: {for (final o in options) o.id: o.label},
        value: valueOf(field),
        errorText: errorOf(field),
        // Nothing to choose yet (e.g. no state picked for an LGA).
        onChanged: options.isEmpty ? null : (value) => onChanged(field, value),
      );
}

/// Under an LGA field whose LGAs failed to load, with "Try again".
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
          onPressed: context.read<StillBirthFormCubit>().retryLgas,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// [select] for the LGAs of [stateId], with [_LgasUnavailable] under it
/// when they failed to load.
Widget _lgaField(StillBirthFormState state, String? stateId, Widget select) =>
    state.lgasUnavailable.contains(stateId)
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [select, const _LgasUnavailable()],
      )
    : select;

String? _errorText(
  AppLocalizations l10n,
  StillBirthFieldError? error, {
  required bool showRequired,
}) => switch (error) {
  null => null,
  StillBirthFieldError.required when !showRequired => null,
  StillBirthFieldError.required => l10n.brRequired,
  StillBirthFieldError.futureDate => l10n.brFutureDate,
  StillBirthFieldError.tooEarly => l10n.sbDeliveryTooEarly,
  StillBirthFieldError.invalidAge => l10n.brInvalidAge(
    MotherParticulars.minAge,
    MotherParticulars.maxAge,
  ),
};
