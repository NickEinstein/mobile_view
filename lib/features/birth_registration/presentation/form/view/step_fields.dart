part of 'registration_form_page.dart';

/// Builds a step's inputs, keyed by field so none inherits another's text.
class _Fields<F extends Enum> {
  const _Fields({
    required this.l10n,
    required this.valueOf,
    required this.errorOf,
    required this.onChanged,
    this.isLocked,
    this.keySuffix,
  });

  final AppLocalizations l10n;

  /// Fields shown but not editable (e.g. a parent informant's name).
  final bool Function(F field)? isLocked;

  /// Changing it rebuilds the text fields with their current values, for
  /// values set other than by typing (e.g. copied from a parent).
  final Object? keySuffix;

  bool _locked(F field) => isLocked?.call(field) ?? false;
  Key _key(F field) => ValueKey((field, keySuffix));
  final String? Function(F field) valueOf;

  /// Localized error to show now, if any.
  final String? Function(F field) errorOf;
  final void Function(F field, String? value) onChanged;

  Widget text(
    F field,
    String label,
    String hint, {
    String? note,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.words,
  }) => AppTextField(
    key: _key(field),
    enabled: !_locked(field),
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

  /// As the user asked: letters, apostrophes and hyphens, no spaces.
  Widget name(F field, String label, String hint, {String? note}) =>
      text(field, label, hint, note: note, inputFormatters: nameFormatters);

  Widget digits(
    F field,
    String label,
    String hint, {
    required int maxLength,
    String? note,
  }) => text(
    field,
    label,
    hint,
    note: note,
    keyboardType: TextInputType.number,
    textCapitalization: TextCapitalization.none,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(maxLength),
    ],
  );

  Widget phone(F field, {String? note}) => text(
    field,
    l10n.brPhoneNumber,
    l10n.brPhoneHint,
    note: note,
    keyboardType: TextInputType.phone,
    textCapitalization: TextCapitalization.none,
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp('[0-9+]')),
      LengthLimitingTextInputFormatter(14),
    ],
  );

  Widget select(F field, String label, List<Option> options, {String? note}) =>
      AppSelectField<String>(
        key: _key(field),
        label: label,
        optionalLabel: note,
        hint: l10n.brSelectOption,
        items: {for (final o in options) o.id: o.label},
        value: valueOf(field),
        errorText: errorOf(field),
        // Nothing to choose yet (e.g. no state picked for an LGA).
        onChanged: options.isEmpty || _locked(field)
            ? null
            : (value) => onChanged(field, value),
      );

  /// "Is it the same as mother's? ○ Yes ○ No".
  Widget yesNo(F field, String label) => AppRadioGroup<String>(
    key: _key(field),
    label: label,
    inline: true,
    options: {answerYes: l10n.yes, answerNo: l10n.no},
    value: valueOf(field),
    errorText: errorOf(field),
    onChanged: _locked(field) ? null : (value) => onChanged(field, value),
  );
}

/// Name fields take letters, apostrophes and hyphens; no spaces.
final nameFormatters = [
  FilteringTextInputFormatter.allow(RegExp("[a-zA-Z'-]")),
];

/// Under an LGA field whose state's LGAs failed to load: says so, and
/// offers to try again.
class _LgasUnavailable extends StatelessWidget {
  const _LgasUnavailable();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.brLgasUnavailable,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
        TextButton(
          onPressed: context.read<RegistrationFormCubit>().retryLgas,
          child: Text(l10n.tryAgain),
        ),
      ],
    );
  }
}

/// [select] for the LGAs of [stateId], with [_LgasUnavailable] under it
/// when they failed to load.
Widget _lgaField(RegistrationFormState state, String? stateId, Widget select) =>
    state.lgasUnavailable.contains(stateId)
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [select, const _LgasUnavailable()],
      )
    : select;

/// Localized [error], or null. "Required"-type errors wait until the user
/// tries to continue; invalid values show straight away.
String? _personError(
  AppLocalizations l10n,
  PersonFieldError? error, {
  required bool showRequired,
}) => switch (error) {
  null => null,
  PersonFieldError.required ||
  PersonFieldError.informantNinRequired when !showRequired => null,
  PersonFieldError.required => l10n.brRequired,
  PersonFieldError.informantNinRequired => l10n.brInformantNinRequired,
  PersonFieldError.invalidTrackingId => l10n.brTrackingIdInvalid,
  PersonFieldError.invalidNin => l10n.brNinInvalid,
  PersonFieldError.invalidPhone => l10n.brInvalidPhone,
  PersonFieldError.invalidAge => l10n.brInvalidAge(minParentAge, maxParentAge),
};

/// A step's title and the line under it.
class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title, required this.hint});

  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            color: AppPalette.inkStrong,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          hint,
          style: textTheme.labelSmall?.copyWith(color: AppPalette.muted),
        ),
      ],
    );
  }
}

/// A heading inside a step, e.g. "Place of Residence".
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

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

/// Stacks a step's inputs with even spacing.
class _FieldColumn extends StatelessWidget {
  const _FieldColumn({required this.header, required this.fields});

  final Widget header;
  final List<Widget> fields;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      header,
      const SizedBox(height: Spacing.lg),
      for (final field in fields) ...[
        field,
        const SizedBox(height: Spacing.md),
      ],
    ],
  );
}
