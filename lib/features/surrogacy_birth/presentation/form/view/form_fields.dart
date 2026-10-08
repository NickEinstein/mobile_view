part of 'surrogacy_form_page.dart';

/// Builds a step's labelled inputs. Each input is keyed by its field, so
/// when fields appear or disappear none inherits another's typed text.
class _Fields<F extends Enum> {
  const _Fields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
    this.isLocked = _unlocked,
    this.generation,
  });

  static bool _unlocked(Object? field) => false;

  final AppLocalizations l10n;
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  /// Filled from the NIN, so not editable.
  final bool Function(F field) isLocked;

  /// Changes when values are filled in from outside (a validated NIN), so
  /// the inputs show them.
  final Object? generation;

  static final digits = [FilteringTextInputFormatter.digitsOnly];

  /// Letters, spaces, apostrophes and hyphens, as names allow.
  static final name = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s'-]")),
    LengthLimitingTextInputFormatter(50),
  ];

  /// No special characters, for places and references.
  static final plain = [
    FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s,.'/-]")),
    LengthLimitingTextInputFormatter(100),
  ];

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    List<TextInputFormatter>? inputFormatters,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) => AppTextField(
    key: ValueKey((field, generation)),
    label: label,
    optionalLabel: note,
    hintText: hint,
    initialValue: valueOf(field),
    enabled: !isLocked(field),
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
        onChanged: options.isEmpty || isLocked(field)
            ? null
            : (value) => onChanged(field, value),
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
          onPressed: context.read<SurrogacyFormCubit>().retryLgas,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// [select] for the LGAs of [stateId], with [_LgasUnavailable] under it
/// when they failed to load.
Widget _lgaField(SurrogacyFormState state, String? stateId, Widget select) =>
    state.lgasUnavailable.contains(stateId)
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [select, const _LgasUnavailable()],
      )
    : select;

String? _errorText(
  AppLocalizations l10n,
  SurrogacyFieldError? error, {
  required bool showRequired,
  int minAge = SurrogateMotherParticulars.minAge,
}) => switch (error) {
  null => null,
  SurrogacyFieldError.required when !showRequired => null,
  SurrogacyFieldError.required => l10n.brRequired,
  SurrogacyFieldError.futureDate => l10n.brFutureDate,
  SurrogacyFieldError.invalidNin => l10n.brNinInvalid,
  SurrogacyFieldError.ninNotVerified => l10n.srNinNotVerified,
  SurrogacyFieldError.invalidAge => l10n.srInvalidAge(
    minAge,
    SurrogateMotherParticulars.maxAge,
  ),
  SurrogacyFieldError.invalidPhone => l10n.brInvalidPhone,
};

/// "Legally Required Fields" / "Additional Fields".
class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppPalette.inkStrong,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
