part of 'attestation_form_page.dart';

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

  /// Read-only fields, e.g. names from the NIN record.
  final bool Function(F field)? isLocked;

  bool _locked(F field) => isLocked?.call(field) ?? false;

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
    optionalLabel: _locked(field) ? l10n.baFromNin : note,
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
        optionalLabel: _locked(field) ? l10n.baFromNin : note,
        hint: l10n.brSelectOption,
        items: {for (final o in options) o.id: o.label},
        value: valueOf(field),
        errorText: errorOf(field),
        // Nothing to choose yet (e.g. no state picked for an LGA), or
        // taken from the NIN record.
        onChanged: options.isEmpty || _locked(field)
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
          onPressed: context.read<AttestationFormCubit>().retryLgas,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// [select] for the LGAs of [stateId], with [_LgasUnavailable] under it
/// when they failed to load.
Widget _lgaField(AttestationFormState state, String? stateId, Widget select) =>
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
  AttestationFieldError? error, {
  required bool showRequired,
}) => switch (error) {
  null => null,
  AttestationFieldError.required when !showRequired => null,
  AttestationFieldError.required => l10n.brRequired,
  AttestationFieldError.invalidEmail => l10n.baInvalidEmail,
  AttestationFieldError.invalidPhone => l10n.baInvalidPhone,
  AttestationFieldError.futureDate => l10n.brFutureDate,
  AttestationFieldError.underAge => l10n.baUnderAge,
  AttestationFieldError.farFromNinDate => l10n.baFarFromNinDate,
};
